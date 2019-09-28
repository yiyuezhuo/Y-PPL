module YPPL

using Distributions

export @model

function replace_symbol_into_dict(symbol_set::Set, dict_symbol::Symbol, expr)
    if typeof(expr) == Symbol
        if in(expr, symbol_set)
            nest_expr = QuoteNode(expr)
            return [:($dict_symbol[$nest_expr])]
        end
        return [expr]
    end
    
    if typeof(expr) != Expr
        return [expr]
    end
    
    new_expr = Expr(expr.head)
    for arg in expr.args
        append!(new_expr.args, replace_symbol_into_dict(symbol_set, dict_symbol, arg))
    end
    return [new_expr]
end

function sub4(symbol_set::Set, expr)
    if typeof(expr) != Expr
        return [expr]
    end
    if (expr.head == :call) && (expr.args[1] == :~)
        sym = expr.args[2]
        dist = expr.args[3]
        
        logp_expr = :(logp += logpdf($dist, $sym))
        logp_proposed_expr = :(logp_proposed += logpdf($dist, $sym))
        return [
            replace_symbol_into_dict(symbol_set, :symbol_map, logp_expr)[1],
            replace_symbol_into_dict(symbol_set, :proposed_map, logp_proposed_expr)[1]
        ]
    end
    new_expr = Expr(expr.head)
    for arg in expr.args
        append!(new_expr.args, sub4(symbol_set, arg))
    end
    return [new_expr]
end

function expand_data(expr)
    # @data x y z -> x = data[:x]; ... @data x,y,z is not valid in current implementation
    @assert expr.head == :macrocall
    
    data_dict_symbol = Symbol(string(expr.args[1])[2:end]) # Symbol("@data") -> Symbol("data") or :data
    
    arr = Vector()
    symbol_arr = Vector()
    for arg in expr.args[2:end]
        if typeof(arg) == Symbol
            nest_arg = QuoteNode(arg)
            push!(arr, :($arg = $data_dict_symbol[$nest_arg]))
            push!(symbol_arr, arg)
        end
    end
    return arr, symbol_arr
end


# search for @data and @parameter in top level, convert them to statement block and Lreturn them
function parse_data_parameter(expr)
    @assert expr.head == :block
    
    line_vec = Vector()
    data_vec = Vector()
    latent_vec = Vector()
    
    for line in expr.args
        if (typeof(line) == Expr) && (line.head == :macrocall)
            macro_symbol = line.args[1]
            
            if in(macro_symbol, [Symbol("@data"), Symbol("@latent")])
                arr, symbol_arr = expand_data(line)
                
                if macro_symbol == Symbol("@data")
                    append!(data_vec, symbol_arr)
                    #append!(line_vec, arr) # remove two lines, new lines should be created by top function
                elseif macro_symbol == Symbol("@latent") 
                    append!(latent_vec, symbol_arr)
                    #append!(line_vec, arr) 
                end
                
                continue
            end
        end
        push!(line_vec, line)
    end
        
    return Expr(expr.head, line_vec...), data_vec, latent_vec
end

function build_model_part(expr)
    
    expr, data_vec, latent_vec = parse_data_parameter(expr)
    symbol_set = Set(latent_vec)
    
    data_part = Expr(:block)
    for d_symbol in data_vec
        rest_node = QuoteNode(d_symbol)
        push!(data_part.args, :($d_symbol = data[$rest_node]))
    end
    
    propose_part = quote
        # propose and logq_x_given_y

        logq_old_given_proposed = 0.0
        logq_proposed_given_old = 0.0

        for (sym, proposal) in propose_map

            dist_given_old = proposal(symbol_map[sym])
            proposed_map[sym] = rand(dist_given_old)
            dist_given_proposed = proposal(proposed_map[sym])

            logq_old_given_proposed += logpdf(dist_given_proposed, symbol_map[sym])
            logq_proposed_given_old += logpdf(dist_given_old, proposed_map[sym])
        end
    end
    
    model_part = sub4(symbol_set, expr)[1]
    
    accept_part = quote
        # accept
        log_accept = logp_proposed - logp + logq_old_given_proposed - logq_proposed_given_old
        accept = exp(log_accept)

        accepted = rand() < accept
        if accepted
            symbol_map = proposed_map
        end

        for (sym, value) in symbol_map
            trace_map[sym][n] = symbol_map[sym]
        end
        trace_map[:_accept][n] = accept
        trace_map[:_accepted][n] = accepted
    end
    
    return quote function(data, symbol_map, propose_map)
            
            $data_part
            
            trace_map = Dict{Symbol, Any}()
            for (sym, value) in symbol_map
                trace_map[sym] = Array{typeof(value)}(undef, N)
            end
            trace_map[:_accept] = Array{Float64}(undef, N)
            trace_map[:_accepted] = Array{Float64}(undef, N)

            for n in 1:N
                proposed_map = Dict{Symbol, Real}()

                $propose_part

                # logp and logp_proposed
                logp = 0.0
                logp_proposed = 0.0

                $model_part
                $accept_part

            end

            return trace_map
        end
    end
end

macro model(expr)
    return build_model_part(expr)
end

end