using JuMP

function get_minimal_container_sequence(db::Database, node, optimizer, Vc; time_limit_sec=30, solver_parameters)
    Vs = get_stock_volume(db, get_last_node(node))
    println(Vs)
    root_node = get_root_node(node)
    root_node.next = nothing
    v = get_container_volume_vector(db)
    println(v)
    n = length(v)
    c = db.containers[:,:cost] |> collect
    model = Model(optimizer)
    @variable(model, x[1:n] >= 0, Int)
    @objective(model, Min, sum(c[i]*x[i] for i in 1:n))
    @constraint(model, sum(v[i]*x[i] for i in 1:n) >= Vc + Vs)
    for (key, value) in solver_parameters
        set_optimizer_attribute(model, key, value)
    end
    set_time_limit_sec(model, time_limit_sec)
    optimize!(model)
    print(model)
    container_sequence = Int[]
    xvals = Int.(value.(model[:x]))
    for i in 1:n
        append!(container_sequence, repeat([i], xvals[i]))
    end
    logger("minimal container sequence determined:", container_nums = xvals')
    return container_sequence
end

function container_sequence_to_nodes(db::Database, cseq)
    parent = ContainerNode(db)
    node = parent
    for container in cseq
        node = ContainerNode(node, container, db)
    end
    return parent
end

function solve_CLP(db::Database, generations, optimizer; verbose=true, top_ratio=0.15, bottom_ratio=0.15, crossover_prob=0.7, pop_ratio=20, plot_data=false, time_limit_sec=30, solver_parameters=Dict())
    verbose ? logging_on() : nothing
    logger("beginning solution process with specified settings", generations=generations, top_ratio=top_ratio, bottom_ratio=bottom_ratio, crossover_prob=crossover_prob, pop_ratio=20)
    sort_containers_by_decreasing_volume!(db)
    sort_items_by_decreasing_volume!(db)
    root_node = ContainerNode(db)
    tries = 0
    local population, pop_fitness, fitness_plot
    cids, pop_stock = [], nothing
    while isnothing(pop_stock) || !any(==(0), pop_stock)
        print(container_sequence_to_nodes(db, cids))
        Vc = get_container_volume_sum(db, container_sequence_to_nodes(db, cids))
        logger("invoking solver to determine minimal container sequence...")
        tries += 1
        logger("attempt number $(tries)...")
        cids = get_minimal_container_sequence(db, root_node, optimizer, Vc, time_limit_sec=time_limit_sec, solver_parameters=solver_parameters)
        population, pop_fitness, fitness_plot, pop_stock = genetic_algorithm(db, cids, generations, top_ratio=top_ratio, bottom_ratio=bottom_ratio, crossover_prob=crossover_prob, pop_ratio=pop_ratio, plot_data=plot_data)
    end
    logger("solution reached.")
    logging_off()
    return population, pop_fitness, fitness_plot, pop_stock
end