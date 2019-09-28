include("yppl.jl")
using .YPPL

using Distributions
using Plots

f2 = @model begin
    
    @data N x y
    @latent alpha beta
    
    alpha ~ Normal(0, 10)
    beta ~ Normal(0, 10)
    for i in eachindex(x)
        y[i] ~ Normal(alpha + beta * x[i], 0.1)
    end
end

walk_std = 0.05

x = range(0,1,length=100)
y = 1.5 .-0.5 .* x .+ 0.1 .* randn(100)

data = Dict(:N => 1000, :x => x, :y => y)
symbol_map = Dict(:alpha => 0.0, :beta => 0.0)
propose_map = Dict(:alpha => (p) -> Normal(p, walk_std),
                    :beta => (p) -> Normal(p, walk_std))

trace_map = f2(data, symbol_map, propose_map)

plot(trace_map[:alpha])
plot(trace_map[:beta])

println("alpha mean:", mean(trace_map[:alpha][200:end]), " std:", std(trace_map[:alpha][200:end]))
#(1.4429917400736434, 0.02038420097401971)
println("beta mean:", mean(trace_map[:beta][200:end]), " std:", std(trace_map[:beta][200:end]))
#(-0.40056187112594976, 0.03505674676079989)
