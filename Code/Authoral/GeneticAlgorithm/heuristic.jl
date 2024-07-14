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

function solve_CLP(db::Database, population_size)
    population = generate_population(db, population_size)
    item_vector = get_database_item_vector(db)
    pop_fitness = []
    for chromosome in population
        item_order = reorder_item_vector(item_vector, chromosome)
        layer_order = get_chromosome_layer_vector(db, item_vector, chromosome)
        root_node = ContainerNode(db)
        node = ContainerNode(root_node, 1, db)
        for i in eachindex(item_order)
            if node.stock[item_order[i]] == 0
                continue
            end
            S = bbl_procedure(db, node, item_order[i], layer_order[i][1])
            if S == 0
                continue
            end
            place_item!(db, node, item_order[i], layer_order[i][1], layer_order[i][2])
            filled_space_id = node.spaces[end, :id]
            for space in eachrow(filter(row -> row[:status] == :new, node.spaces))
                subtract_space!(node, space[:id], filled_space_id)
            end
        end
        push!(pop_fitness, 100*sum(prod(space[[:width,:height,:depth]]) for space in eachrow(filter(row -> row[:status] == :filled, node.spaces)))/prod(node.spaces[1, [:width,:height,:depth]]))
        return node
    end
    return pop_fitness
end