# Yet another toy PPL written in Julia

## Examples

Coin-flip example(see `coin.jl`):

```julia
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
# (0.65625, 0.08267972847076846)
```

Bayesian simple linear regression(see `bayesian_regression.jl`):

```julia
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

mean(trace_map[:alpha][200:end]), std(trace_map[:alpha][200:end])
#(1.4429917400736434, 0.02038420097401971)
mean(trace_map[:beta][200:end]), std(trace_map[:beta][200:end])
#(-0.40056187112594976, 0.03505674676079989)
```