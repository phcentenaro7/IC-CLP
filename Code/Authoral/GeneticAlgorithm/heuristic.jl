import Statistics: mean
using ProgressBars

"""
Generates a population of chromosomes. Given a CLP with `n` items, each chromosome has `2n` genes. All genes are in the `[0, 1)` interval, with the first `n` genes representing the order in which items are packed (from lower to highest value) and the last `n` genes representing layer types.
"""
function generate_population(db::Database, population_size)
    nitems = get_total_database_item_quantities(db)
    population = []
    for i in 1:population_size
        push!(population, rand(nitems * 2))
    end
    return population
end

"""
Returns the vector of items that is permutated by the first half of a chromosome.
"""
function get_database_item_vector(db::Database)
    v = []
    for item in eachrow(db.items)
        append!(v, repeat([item[:id]], item[:quantity]))
    end
    return v
end

"""
Reorders the database item vector according to the first half of a chromosome.
"""
function reorder_item_vector(item_vector, chromosome)
    p = sortperm(chromosome[1:Int(length(chromosome)/2)])
    return item_vector[p]
end

"""
Performs a uniform crossover operation that goes over all the genes in both provided parents. The `elite_parent` is supposed to be selected from the population's best, while the `second_parent` may be any chromosome in the population. Parameter `chance_elite` defaults to `0.7` and determines the odds that the gene selected for the offspring comes from the elite parent.
"""
function crossover(elite_parent, second_parent, chance_elite=0.7)
    offspring = []
    for i in eachindex(elite_parent)
        p = rand()
        if p < chance_elite
            push!(offspring, elite_parent[i])
        else
            push!(offspring, second_parent[i])
        end
    end
    return offspring
end

function get_chromosome_layer_vector(db::Database, item_vector, chromosome)
    rotations = [:xyz, :zyx, :xzy, :yxz, :zxy, :yzx]
    planes = [:xy, :xz, :yx, :yz, :zx, :zy]
    unconstrained_layers = Iterators.product(rotations, planes) |> collect |> vec
    constrained_layers = Iterators.product(rotations[1:2], planes) |> collect |> vec
    rotation_genes = chromosome[Int(length(chromosome)/2+1):end]
    layers = []
    for i in eachindex(rotation_genes)
        if db.items[item_vector[i], :fixed_height] == true
            push!(layers, constrained_layers[rotation_genes[i] * length(constrained_layers) |> ceil |> Int])
        else
            push!(layers, unconstrained_layers[rotation_genes[i] * length(unconstrained_layers) |> ceil |> Int])
        end
    end
    return layers
end

function evaluate_chromosome(db::Database, stock, cseq, chromosome, item_vector)
    root_node = container_sequence_to_nodes(db, cseq)
    item_order = reorder_item_vector(item_vector, chromosome)
    layer_order = get_chromosome_layer_vector(db, item_vector, chromosome)
    fill_ratios = []
    for i in eachindex(item_order)
        if stock[item_order[i]] == 0
            if all(==(0), stock)
                break
            end
            continue
        end
        node = root_node.next
        while !isnothing(node)
            S = bbl_procedure(db, node, item_order[i], layer_order[i][1])
            if S == 0
                node = node.next
                continue
            end
            place_item!(db, node, stock, item_order[i], layer_order[i][1], layer_order[i][2])
            filled_space_id = node.spaces[end, :id]
            for space in eachrow(filter(row -> row[:status] == :new || row[:status] == :merge, node.spaces))
                subtract_space!(node, space[:id], filled_space_id)
            end
            break
        end
    end
    node = root_node.next
    while !isnothing(node)
        push!(fill_ratios, sum(prod(space[[:width,:height,:depth]]) for space in eachrow(filter(row -> row[:status] == :filled, node.spaces)))/prod(node.spaces[1, [:width,:height,:depth]]))
        node = node.next
    end
    last_node = get_last_node(root_node)
    stock_left = sum(stock)
    fitness = 100 * mean(fill_ratios)
    fitness /= stock_left > 0 ? 10*stock_left : 1
    return fitness, stock_left
end

function order_population(pop, pop_fitness)
    ranking = sortperm(pop_fitness, rev=true)
    return pop[ranking]
end

function get_population_elite(pop, top_ratio)
    elite_size = round(Int, top_ratio * length(pop))
    if elite_size == 0
        elite_size = 1
    end
    return pop[1:elite_size]
end

function uniform_crossover(elite, pop, crossover_prob)
    P1 = rand(elite)
    P2 = rand(pop)
    C = []
    for i in eachindex(P1)
        p = rand()
        push!(C, p <= crossover_prob ? P1[i] : P2[i])
    end
    return C
end

function update_population(db::Database, population, pop_fitness, top_ratio, bottom_ratio, crossover_prob)
    old_pop = order_population(population, pop_fitness)
    elite = get_population_elite(old_pop, top_ratio)
    new_pop = copy(elite)
    bottom_size = round(Int, bottom_ratio * length(population))
    append!(new_pop, generate_population(db, bottom_size))
    while length(new_pop) < length(old_pop)
        push!(new_pop, uniform_crossover(elite, old_pop, crossover_prob))
    end
    return new_pop
end

function genetic_algorithm(db::Database, container_sequence, generations; top_ratio=0.15, bottom_ratio=0.15, crossover_prob=0.7, pop_ratio=20, plot_data=false)
    population = generate_population(db, pop_ratio * nrow(db.items))
    item_vector = get_database_item_vector(db)
    pop_fitness, pop_stock, best, avg, worst = [], [], [], [], []
    for i in 1:generations
        pop_fitness = []
        pop_stock = []
        progress_bar = ProgressBar(total=length(population))
        for chromosome in population
            fitness, stock_left = evaluate_chromosome(db, get_stock_vector(db), container_sequence, chromosome, item_vector)
            push!(pop_fitness, fitness)
            push!(pop_stock, stock_left)
            ProgressBars.update(progress_bar)
        end
        push!(best, maximum(pop_fitness))
        push!(avg, mean(pop_fitness))
        push!(worst, minimum(pop_fitness))
        logger("", generation=i, best=best[end], mean=avg[end], worst=worst[end], best_stock=minimum(pop_stock))
        elite = population[argmax(pop_fitness)]
        if i < generations
            population = update_population(db, population, pop_fitness, top_ratio, bottom_ratio, crossover_prob)
        end
    end
    fitness_plot = plot_data ? Plotly.plot(repeat(collect(1:generations), 1, 3), hcat(best, avg, worst)) : nothing;
    return population, pop_fitness, fitness_plot, pop_stock
end
