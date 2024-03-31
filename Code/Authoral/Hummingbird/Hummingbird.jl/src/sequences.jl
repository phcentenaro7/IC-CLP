using JuMP
using Logging
using GLPK

function get_minimal_container_sequence(db::Database, stock, optimizer, correction_factor; time_limit_sec=30, solver_parameters)
    V = get_stock_volume(db, stock)
    v = get_container_volume_vector(db)
    c = db.containers[:,:cost] |> collect
    Cf = correction_factor
    n = length(v)
    model = Model(optimizer)
    @variable(model, x[1:n] >= 0, Int)
    @objective(model, Min, sum(c[i]*x[i] for i in 1:n))
    @constraint(model, Cf * sum(v[i]*x[i] for i in 1:n) >= V)
    for (key, value) in solver_parameters
        set_optimizer_attribute(model, key, value)
    end
    set_time_limit_sec(model, time_limit_sec)
    optimize!(model)
    container_sequence = Int[]
    xvals = Int.(value.(model[:x]))
    for i in 1:n
        append!(container_sequence, repeat([i], xvals[i]))
    end
    @info "minimal container sequence determined." xvals'
    return container_sequence
end

"""
Filters previous container fillings that can be repeated in the current empty container. Three filters are applied:

* Empty container must be of the same type as the one listed;
* There must be enough stock left for the empty container to replicate the listed container exactly;
* The container to be replicated must be in the same position as the empty container, or earlier, in its filling sequence. This last point assures that the listed container won't be too empty.
"""
function find_repeatable_container_filling(reference_table, node::ContainerNode)
    candidates = filter(row -> row[:container] == node.container_id && 
                        all(row[:placed] .<= node.stock), reference_table)
    return filter(row -> row[:filled_volume] == maximum(candidates[:,:filled_volume]), candidates) |> noerror_first
end

"""
Points all the relevant placement information from one node (`src`) to another (`dst`). This includes:

* Source's layers;
* Source's spaces;
* Source's remaining depth;
* Source's placements;
* Source's filled volume.

Note that this function does *not* point the source's stock to the destination, since that would break the container tree's logic.
"""
function copy_node_placements!(src, dst)
    dst.layers = src.layers
    dst.spaces = src.spaces
    dst.remaining_depth = src.remaining_depth
    dst.placements = src.placements
    dst.filled_volume = src.filled_volume
end

function new_reference_table()
    @info "creating reference table..."
    return DataFrame(container=Int[], index=Int[], placed=Vector{Int}[], filled_volume=Float64[])
end

"""
Creates a new node in the containter tree to which `parent` belongs. This involves applying the wall-building heuristic to the node, or the best solution that has already been calculated for this node.
"""
function create_new_node!(parent, container_id, db, reference_table; flexible_ratio=.0, separate_rankings=true, solution::Union{CLPSolution,Nothing}=nothing)
    node = ContainerNode(parent, container_id, db)
    rf = find_repeatable_container_filling(reference_table, node)
    if isnothing(rf)
        fill_container!(db, node, flexible_ratio=flexible_ratio, separate_rankings=separate_rankings)
        push!(reference_table, [node.container_id, get_node_index(node), node.previous.stock .- node.stock, node.filled_volume])
    else
        source = get_node(get_root_node(node), rf[:index])
        node.stock .-= rf[:placed]
        copy_node_placements!(source, node)
    end
    if solution |> !isnothing
        add_node_summary!(solution, container_id, node.stock, get_filled_volume(db, node, mode=:percent), db.containers[container_id,:cost])
    end
    return node
end

function get_average_container_filling(db::Database, node::ContainerNode)
    node = get_first_node(node)
    sum = 0
    N = 0
    while !isnothing(node)
        sum += get_filled_volume(db, node, mode=:percent)
        N += 1
        node = node.next
    end
    return sum / N
end

function solve_CLP(db::Database, optimizer; verbose=false, flexible_ratio=.0, separate_rankings=true, time_limit_sec=30, solver_parameters=Dict())
    default_logger = global_logger()
    tmp_logger = ConsoleLogger(stdout, verbose ? Logging.Info : Logging.Warn, meta_formatter=(level, _module, group, id, file, line) -> (:light_cyan, "Hummingbird: ", ""), show_limited=false)
    global_logger(tmp_logger)
    @info "beginning solution process with specified settings" flexible_ratio, separate_rankings
    sort_containers_by_decreasing_volume!(db)
    sort_items_by_decreasing_volume!(db)
    solution = CLPSolution(db)
    root_node = node = solution.sequence
    tries = 0
    local cids
    while any_items_left(node)
        root_node.next = nothing
        empty!(solution.summary)
        rt = new_reference_table()
        @info "invoking solver to determine minimal container sequence..."
        if tries == 0
            @info "attempt number 1 with correction factor 1..."
            cids = get_minimal_container_sequence(db, root_node.stock, optimizer, 1, time_limit_sec=time_limit_sec, solver_parameters=solver_parameters)
        else
            Cf = get_average_container_filling(db, node)
            Cf = 0.01*Cf - (0.05 * (tries - 1))
            @info "attempt number $(tries+1) with correction factor $Cf..."
            cids = get_minimal_container_sequence(db, root_node.stock, optimizer, Cf, time_limit_sec=time_limit_sec, solver_parameters=solver_parameters)
        end
        node = root_node
        tries += 1
        @info "creating nodes..."
        for cid in cids
            node = create_new_node!(node, cid, db, rt, solution=solution)
            if !any_items_left(node)
                break
            end
        end
    end
    @info "solution reached using $(get_sequence_length(node)) containers; total cost is $(get_sequence_cost(db, node))."
    global_logger(default_logger)
    return solution
end