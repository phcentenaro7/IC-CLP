using DataFrames

mutable struct Database
    containers::DataFrame
    items::DataFrame
    Database() = new(new_container_table(), new_item_table())
end

"""
Creates a new table of containers. Each container is defined by its width, height and depth.
"""
function new_container_table()
    return DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], cost=Float64[], volume=Float64[])
end

"""
Creates a new table of item types. Each item type is defined by three dimensions and an initial quantity in stock.
"""
function new_item_table()
    return DataFrame(id=Int[], dim1=Real[], dim2=Real[], dim3=Real[], quantity=Int[], volume=Float64[])
end

"""
Adds a container to the database.
"""
function add_container!(db::Database, dims::Vector{<:Real}, cost::Union{Float64, Int})
    id = new_id(db.containers)
        push!(db.containers, [id, dims..., cost, prod(dims)])
    return db.containers[id,:]
end

function get_container_volume_vector(db::Database)
    return [prod(dims) for dims in eachrow(db.containers[:,[:width,:height,:depth]])]
end

function sort_containers_by_decreasing_volume!(db::Database)
    @info "sorting containers in database..."
    sort!(db.containers, :volume, rev=true)
    for i in 1:nrow(db.containers)
        db.containers[i,:id] = i
    end
end

"""
Adds an item to the database.
"""
function add_item!(db::Database, dims::Vector{<:Real}, quantity::Int)
    id = new_id(db.items)
    push!(db.items, [id, dims..., quantity, prod(dims)])
    return db.items[id,:]
end

function sort_items_by_decreasing_volume!(db::Database)
    @info "sorting items in database..."
    sort!(db.items, :volume, rev=true)
    for i in 1:nrow(db.items)
        db.items[i,:id] = i
    end
end

"""
Returns the sum volume of all items registered in the database.
"""
function get_total_item_volume(db::Database)
    return sum(prod(dims) for dims in eachrow(db.items[:,[:dim1,:dim2,:dim3,:quantity]]))
end

mutable struct ContainerNode
    previous::Union{ContainerNode, Nothing}
    next::Union{ContainerNode, Nothing}
    container_id::Int
    stock::Vector{Int}
    open::Vector{Bool}
    remaining_depth::Float64
    filled_volume::Float64
    layers::DataFrame
    spaces::DataFrame
    placements::DataFrame
    ContainerNode(db::Database) = new(nothing, nothing, 0, copy(db.items[:,:quantity]), repeat([false], nrow(db.items)), 0, 0, new_layer_table(), new_space_table(), new_placement_table())
    function ContainerNode(parent::Union{ContainerNode,Nothing}, container_id::Int, db::Database)
        node = new(parent, nothing, container_id, copy(parent.stock), repeat([false], length(parent.stock)), db.containers[container_id,:depth], 0, new_layer_table(), new_space_table(), new_placement_table())
        parent.next = node
        return node
    end
end

function Base.show(io::IO, x::ContainerNode)
    println(io, "$(get_node_index(x))-index container node")
    println(io, "Container type: $(x.container_id)")
    println(io, "Filled volume: $(x.filled_volume)")
    println(io, "Stock: $(x.stock)")
end

"""
Sets the ID of a new item in a table.
"""
new_id(table) = size(table, 1) + 1

"""
Creates a new table of layers. Each layer is defined by:

* The container to which it belongs;
* The item that was used to determine the layer's depth;
* The ``z`` coordinate of the layer within the container;
* The depth of the layer.
"""
function new_layer_table()
    return DataFrame(id=Int[], item=Int[], z=Real[], depth=Real[])
end

"""
Creates a new table of spaces. Each space is defined by:

* The layer to which it belongs;
* Width, height and depth;
* Coordinates defining its position within the layer;

There is also a number of other characteristics needed to describe a space. The first is its `type`. If the space was created at the same time as the layer, then it's a `primary` space. Otherwise, it's either a `widthwise`, `heightwise` or `depthwise` space.

A space is also described by its `status`. Initially, all spaces are marked as `new`. If the heuristic is able to fill a space (partially or completely), the space is marked as `filled`. Otherwise, the space is `rejected`. A space that was `rejected` may later turn into an `amalgamated` space, if it is used to create an amalgamation with a space in the next layer.

If a space is amalgamated with another, the other space's ID is stored as a `partner`. Furthermore, when a space in the *current layer* is amalgamated, the space it originated from is marked as a `sibling`, and vice versa. The flexible width between these spaces is also stored in this table. Finally, if a `widthwise`, `heightwise` or `depthwise` originates from an amalgam, this is also registered in the table.
"""
function new_space_table()
    return DataFrame(id=Int[], layer=Int[], width=Real[], height=Real[], depth=Real[], x=Real[], y=Real[], z=Real[], type=Symbol[], status=Symbol[], partner=Int[], sibling=Int[], flexible_width=Real[], from_amalgam=Bool[])
end

"""
Creates a new table of placements. Each placement is defined by:

* The space its positions are relative to;
* The item type of the placement;
* The quantity of items stacked in this placement column;
* The width, height and depth of each unit of this item type;
* The x, y and z coordinates of the placement, relative to its space.
"""
function new_placement_table()
    return DataFrame(space=Int[], item=Int[], quantity=Real[], width=Real[], height=Real[], depth=Real[], x=[], y=[], z=[])
end

"""
Adds a layer to the container node.
"""
function add_layer!(node::ContainerNode, item, z, depth)
    id = new_id(node.layers)
    push!(node.layers, [id, item, z, depth])
    return node.layers[id,:]
end

"""
Adds a space to the container node.
"""
function add_space!(node::ContainerNode, layer, dims, coords, type)
    id = new_id(node.spaces)
    push!(node.spaces, [id, layer, dims..., coords..., type, :new, 0, 0, 0, false])
    return node.spaces[id,:]
end

function add_placement!(node::ContainerNode, item_id, space_id, quantity, dims, coords)
    push!(node.placements, [space_id, item_id, quantity, dims..., coords...])
    return node.placements[size(node.placements, 1),:]
end

function get_container_volume(db::Database, node::ContainerNode)
    container = db.containers[node.container_id,:]
    return prod(container[[:width,:height,:depth]])
end

"""
When optional argument `mode` is equal to `:volume` (which it is by default), returns the container's filled volume. When equal to `:percent`, returns the percentage of filled volume.
"""
function get_filled_volume(db::Database, node::ContainerNode; mode=:volume)
    filled_volume = 0
    for placement in eachrow(node.placements)
        filled_volume += prod(placement[[:quantity,:width,:height,:depth]])
    end
    if mode == :volume
        return filled_volume
    elseif mode == :percent
        return 100 * filled_volume / get_container_volume(db, node)
    end
end

"""
Returns a specific node in the container tree given by `path`.
"""
function get_node(root_node, index)
    node = root_node
    for i in 1:index
        node = node.next
    end
    return node
end

function get_root_node(node)
    while node.previous |> !isnothing
        node = node.previous
    end
    return node
end

function get_first_node(node)
    if node.previous |> isnothing
        return node.next
    end
    while node.previous.previous |> !isnothing
        node = node.previous
    end
    return node
end

function get_node_index(node)
    i = 0
    while true
        previous = node.previous
        if isnothing(previous)
            return i
        end
        i += 1
        node = previous
    end
end

function get_sequence_length(root_node)
    i = 0
    node = root_node
    while true
        next = node.next
        if isnothing(next)
            return i
        end
        i += 1
        node = next
    end
end

function get_sequence_cost(db::Database, node)
    sum_cost = 0
    node = get_first_node(node)
    while true
        if isnothing(node)
            return sum_cost
        end
        sum_cost += db.containers[node.container_id,:cost]
        node = node.next
    end
end

struct CLPSolution
    sequence::ContainerNode
    summary::DataFrame
    CLPSolution(db::Database) = new(ContainerNode(db), DataFrame(container_id=Int[], stock=Vector{Int}[], percent_filled=Float64[], cost=Float64[]))
end

function Base.show(io::IO, x::CLPSolution)
    println(io, x.summary)
end

function add_node_summary!(CLP::CLPSolution, container_id::Int, stock::Vector{Int}, percent_filled::Float64, cost::Float64)
    push!(CLP.summary, [container_id, stock, percent_filled, cost])
end