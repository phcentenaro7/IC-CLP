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
    return DataFrame(id=Int[], dim1=Real[], dim2=Real[], dim3=Real[], fixed_height=Bool[], quantity=Int[], volume=Float64[])
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
function add_item!(db::Database, dims::Vector{<:Real}, fixed_height, quantity::Int)
    id = new_id(db.items)
    push!(db.items, [id, dims..., fixed_height, quantity, prod(dims)])
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
Returns the sum of all item types originally registered in the database.
"""
function get_total_database_item_types(db::Database)
    return nrow(db)
end

"""
Returns the sum of all item quantities originally registered in the database.
"""
function get_total_database_item_quantities(db::Database)
    return sum(quantity for quantity in eachrow(db.items[:, :quantity])) |> first
end

"""
Returns the sum volume of all items registered in the database.
"""
function get_stock_volume(db::Database, stock::Vector{Int})
    return sum(prod(item[[:dim1,:dim2,:dim3]]) * stock[item[:id]] for item in eachrow(db.items[:,:]))
end

mutable struct ContainerNode
    previous::Union{ContainerNode, Nothing}
    next::Union{ContainerNode, Nothing}
    container_id::Int
    stock::Vector{Int}
    open::Vector{Bool}
    remaining_depth::Float64
    filled_volume::Float64
    spaces::DataFrame
    ContainerNode(db::Database) = new(nothing, nothing, 0, copy(db.items[:,:quantity]), repeat([false], nrow(db.items)), 0, 0, new_space_table())
    function ContainerNode(parent::Union{ContainerNode,Nothing}, container_id::Int, db::Database)
        node = new(parent, nothing, container_id, copy(parent.stock), repeat([false], length(parent.stock)), db.containers[container_id,:depth], 0, new_space_table())
        parent.next = node
        add_space!(node, db.containers[container_id, [:width,:height,:depth]], [0, 0, 0])
        return node
    end
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

function get_last_node(node)
    while node.next |> !isnothing
        node = node.next
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

function get_sequence_length(node)
    node = get_root_node(node)
    i = 0
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

function get_average_container_filling(db::Database, node::ContainerNode)
    node = get_first_node(node)
    if node |> isnothing
        return 0
    end
    sum = 0
    N = 0
    while !isnothing(node)
        sum += get_filled_volume(db, node, mode=:percent)
        N += 1
        node = node.next
    end
    return sum / N
end

function get_stock_volume(db::Database, node::ContainerNode)
    return sum(prod(item[[:dim1,:dim2,:dim3]]) * node.stock[item[:id]] for item in eachrow(db.items[:,:]))
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