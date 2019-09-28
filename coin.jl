include("yppl.jl")
using .YPPL

using Distributions
using Plots

f = @model begin
    
    @data x N alpha beta
    @latent p
    
    p ~ Beta(alpha, beta)
    for i in eachindex(x)
        x[i] ~ Bernoulli(p)
    end
end

x = ones(20)
append!(x, zeros(10))

walk_std = 0.1
data = Dict(:N => 1000, :x => x, :alpha => 1, :beta => 1)
symbol_map = Dict(:p => 0.5)
propose_map = Dict(:p => (p) -> TruncatedNormal(p, walk_std, 0, 1))

trace_map = f(data, symbol_map, propose_map)

plot(trace_map[:p])

println("p(samping) mean:",mean(trace_map[:p]), " std:", std(trace_map[:p]))
# (0.6441539350616866, 0.08736421033447403)

exact = Beta(1+20,1+10)
println("p(exact) mean:", mean(exact), " std:", std(exact))
