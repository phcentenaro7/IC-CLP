using JuMP
using Gurobi

function jump_knapsack(p::Vector{Int}, v::Vector{Int}, c::Int; optimizer=Gurobi.Optimizer)
    n = length(p)
    model = Model(optimizer)
    @variable(model, x[1:n], Bin)
    @objective(model, Max, sum(x .* v))
    @constraint(model, sum(x .* p) ≤ c)
    optimize!(model)
    return value.(model[:x])
end

##
p = [4,2,1,3]
v = [500,400,300,450]
jump_knapsack(p, v, 5)