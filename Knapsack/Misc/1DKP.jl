using JuMP
using Gurobi

function create_1d_knapsack_model(w, v, C)
    n = length(w)
    model = Model()
    @variable(model, x[1:n], Bin)
    @objective(model, Max, sum(v[i] * x[i] for i in 1:n))
    @constraint(model, sum(w[i] * x[i] for i in 1:n) ≤ C)
    return model
end

##
model = create_1d_knapsack_model([4, 2, 1, 3], [500, 400, 300, 450], 5)
set_optimizer(model, Gurobi.Optimizer)
optimize!(model)
print(value.(model[:x]))