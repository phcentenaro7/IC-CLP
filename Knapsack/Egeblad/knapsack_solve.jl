function evaluate_sequence_tuple(s::Vector, kv::KnapsackVectors)
    w, h, d = kv_dims(kv)
    W, H, D = kv_cdims(kv)
    n = length(w)
    x, y, z = sequence_tuple_to_packing(s, [w, h, d])
    in_container(i) = begin
        x[i] ≥ 0        && y[i] ≥ 0        && z[i] ≥ 0 &&
        x[i] + w[i] ≤ W && y[i] + h[i] ≤ H && z[i] + d[i] ≤ D
    end
    value_sum = 0
    for i in 1:n
        if in_container(i)
            value_sum += kv.values[i]
        end
    end
    return value_sum
end

function random_swap(X)
    i, j = sample(1:length(X), 2, replace=false)
    X[i], X[j] = X[j], X[i]
end

function choose_swap(s::Vector)
    A, B, C = s
    options = [[rand(s)], [A, B], [A, C], [B, C], [A, B, C]]
    choice = rand(options)
    map(random_swap, choice)
end

function solve_by_3d_simulated_annealing(kv::KnapsackVectors; t₀=:default, tₛ=:default, max_iter=Inf, max_solve_time=60, optimizer=GLPK.Optimizer)
    n = length(kv.w)
    s = [collect(1:n) for k ∈ 1:3]
    map(shuffle!, s)
    a = 0
    print_time = 5
    s_value = evaluate_sequence_tuple(s, kv)
    best_value = 0
    solve_time = 0
    iter = 1
    if t₀ == :default || tₛ == :default
        model1d = convert_to_1d_knapsack_model(problem)
        set_optimizer(model1d, optimizer)
        optimize!(model1d)
        n₁ = sum(value.(model1d[:x]))
        t₀ = t₀ == :default ? n₁^2 : t₀
        tₛ = tₛ == :default ? (n₁^2)/(10^7) : tₛ
    end
    while iter ≤ max_iter && solve_time ≤ max_solve_time
        iter_start_time = time()
        accept = false
        s′ = copy(s)
        choose_swap(s′)
        s′_value = evaluate_sequence_tuple(s′, kv)
        if s′_value ≥ s_value
            accept = true
            s_value = s′_value
            best_value = s_value
        else
            p = rand()
            T = inv(t₀ + a * tₛ)
            Δ = (abs(s′_value - s_value))/s_value
            if p < exp(-Δ/T)
                accept = true
            end
        end
        if accept
            s = s′
            a += 1
        end
        iter += 1
        solve_time += time() - iter_start_time
        if solve_time > print_time
            print_time += 5
            println("elapsed:\t$(round(solve_time, digits=1)) s")
            println("current:\t$s_value")
            println("best:\t\t$best_value")
            println("accepted:\t$a")
            println("----------------------------")
        end
    end
    return s
end

function solve_by_simulated_annealing(problem::KnapsackProblem)
    
end

function solve_knapsack(problem::KnapsackProblem; method=:IP, optimizer=GLPK.Optimizer, time_limit=90)
    return @match method begin
        :IP => begin
            model = create_knapsack_model(problem)
            set_optimizer(model, optimizer)
            set_time_limit_sec(model, time_limit)
            optimize!(model)
            kv = KnapsackVectors(problem)
            kv.in_container = value.(model[:s])
            kv.x, kv.y, kv.z = [value.(model[k]) for k in [:x, :y, :z]]
            return model
        end
        :SA => return solve_by_simulated_annealing(problem)
    end
end