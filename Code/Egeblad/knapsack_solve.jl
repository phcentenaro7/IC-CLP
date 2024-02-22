function solve_knapsack(problem::KnapsackProblem; optimizer=GLPK.Optimizer, time_limit=90)
    model = create_knapsack_model(problem)
    set_optimizer(model, optimizer)
    set_time_limit_sec(model, time_limit)
    optimize!(model)
    kv = KnapsackVectors(problem)
    kv.in_container = value.(model[:s])
    kv.x, kv.y, kv.z = [value.(model[k]) for k in [:x, :y, :z]]
    return model
end