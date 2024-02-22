function get_knapsack_problem_item_dims(problem::KnapsackProblem)
    n = sum(item.available for item in problem.items)
    W, H, D = problem.container_dims
    w, h, d, v = [], [], [], []
    for item in problem.items
        append!(w, repeat([item.width], item.available))
        append!(h, repeat([item.height], item.available))
        append!(d, repeat([item.depth], item.available))
        append!(v, repeat([item.value], item.available))
    end
    return n, W, H, D, w, h, d, v
end

function convert_to_1d_knapsack_model(problem::KnapsackProblem)
    n, W, H, D, w, h, d, v = get_knapsack_problem_item_dims(problem)
    model = Model()
    @variable(model, x[1:n], Bin)
    @objective(model, Max, sum(v[i] * x[i] for i in 1:n))
    if problem.container_dims[3] == 0
        @constraint(model, sum(w[i]*h[i]*x[i] for i in 1:n) ≤ W*H)
    else
        @constraint(model, sum(w[i]*h[i]*d[i]*x[i] for i in 1:n) ≤ W*H*D)
    end
    return model
end

function create_2d_knapsack_model(problem::KnapsackProblem)
    n, W, H, _, w, h, _, v = get_knapsack_problem_item_dims(problem)
    model = Model()
    @variable(model, dims == 2)
    @variable(model, s[1:n], Bin)
    @variable(model, 0 ≤ x[i=1:n] ≤ W - w[i])
    @variable(model, 0 ≤ y[i=1:n] ≤ H - h[i])
    @variable(model, l[1:n, 1:n], Bin)
    @variable(model, r[1:n, 1:n], Bin)
    @variable(model, u[1:n, 1:n], Bin)
    @variable(model, o[1:n, 1:n], Bin)
    @objective(model, Max, sum(v[i] .* s[i] for i in 1:n))
    @constraint(model, [i ∈ 1:n, j ∈ 1:n; i < j], l[i,j] + r[i,j] + u[i,j] + o[i,j] == s[i] * s[j])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], x[i] - x[j] + W*l[i,j] ≤ W - w[i])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], x[j] - x[i] + W*r[i,j] ≤ W - w[j])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], y[i] - y[j] + H*u[i,j] ≤ H - h[i])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], y[j] - y[i] + H*o[i,j] ≤ H - h[j])
    return model
end

function create_3d_knapsack_model(problem::KnapsackProblem)
    n, W, H, D, w, h, d, v = get_knapsack_problem_item_dims(problem)
    model = Model()
    @variable(model, dims == 3)
    @variable(model, s[1:n], Bin)
    @variable(model, 0 ≤ x[i=1:n] ≤ W - w[i])
    @variable(model, 0 ≤ y[i=1:n] ≤ H - h[i])
    @variable(model, 0 ≤ z[i=1:n] ≤ D - d[i])
    @variable(model, l[1:n, 1:n], Bin)
    @variable(model, r[1:n, 1:n], Bin)
    @variable(model, u[1:n, 1:n], Bin)
    @variable(model, o[1:n, 1:n], Bin)
    @variable(model, b[1:n, 1:n], Bin)
    @variable(model, f[1:n, 1:n], Bin)
    @objective(model, Max, sum(v[i] .* s[i] for i in 1:n))
    @constraint(model, [i ∈ 1:n, j ∈ 1:n; i < j], l[i,j] + r[i,j] + u[i,j] + o[i,j] + b[i,j] + f[i,j] == s[i] * s[j])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], x[i] - x[j] + W*l[i,j] ≤ W - w[i])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], x[j] - x[i] + W*r[i,j] ≤ W - w[j])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], y[i] - y[j] + H*u[i,j] ≤ H - h[i])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], y[j] - y[i] + H*o[i,j] ≤ H - h[j])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], z[i] - z[j] + D*b[i,j] ≤ D - d[i])
    @constraint(model, [i ∈ 1:n, j ∈ 1:n], z[j] - z[i] + D*f[i,j] ≤ D - d[j])
    return model
end

function create_knapsack_model(problem::KnapsackProblem)
    return @match problem.container_dims[3] begin
        0 => create_2d_knapsack_model(problem)
        _ => create_3d_knapsack_model(problem)
    end
end