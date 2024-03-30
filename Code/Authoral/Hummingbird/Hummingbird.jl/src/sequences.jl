using JuMP
using Logging

function get_minimal_container_sequence(db::Database, optimizer, verbose)
    V = get_total_item_volume(db)
    v = get_container_volume_vector(db)
    c = db.containers[:,:cost] |> collect
    n = length(v)
    @info "invoking solver to determine minimal container sequence..."
    model = Model(optimizer)
    if !verbose
        set_silent(model)
    end
    @variable(model, x[1:n] >= 0, Int)
    @objective(model, Min, sum(c[i]*x[i] for i in 1:n))
    @constraint(model, sum(v[i]*x[i] for i in 1:n) >= V)
    optimize!(model)
    container_sequence = Int[]
    xvals = Int.(value.(model[:x]))
    for i in 1:n
        append!(container_sequence, repeat([i], xvals[i]))
    end
    @info "minimal container sequence determined."
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
    @info "creating node..."
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

function solve_CLP(db::Database, optimizer; verbose=false)
    default_logger = global_logger()
    tmp_logger = SimpleLogger(stdout, verbose ? Logging.Info : Logging.Warn)
    global_logger(tmp_logger)
    sort_containers_by_decreasing_volume!(db)
    sort_items_by_decreasing_volume!(db)
    rt = new_reference_table()
    cids = get_minimal_container_sequence(db, optimizer, verbose)
    solution = CLPSolution(db)
    node = solution.sequence
    for cid in cids
        node = create_new_node!(node, cid, db, rt, solution=solution)
    end
    while any_items_left(node)
        push!(cids, db.containers[:,:id] |> last)
        cid = last(cids)
        node = create_new_node!(node, cid, db, rt, solution=solution)
    end
    @info "solution reached using $(get_first_node(node) |> get_sequence_length) containers; total cost is $(get_sequence_cost(db, node))."
    global_logger(default_logger)
    return solution
end