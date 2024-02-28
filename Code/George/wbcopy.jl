using DataFrames
using Combinatorics

mutable struct Database
    containers::DataFrame
    layers::DataFrame
    spaces::DataFrame
    items::DataFrame
    placements::DataFrame
    Database() = new(new_container_table(), new_layer_table(), new_space_table(), new_item_table(), new_placement_table())
end

#TABLE CREATION

function new_container_table()
    container_table = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], remaining_depth=Real[])
    return container_table
end

function new_layer_table()
    layer_table = DataFrame(id=Int[], container=Int[], item=Int[], z=Real[], depth=Real[])
    return layer_table
end

function new_space_table()
    space_table = DataFrame(layer=Int[], width=Real[], height=Real[], depth=Real[], x=Real[], y=Real[], z=Real[])
    return space_table
end

function new_item_table()
    item_table = DataFrame(id=Int[], dim1=Real[], dim2=Real[], dim3=Real[], quantity=Int[], placed=Int[], open=Bool[])
    return item_table
end

function new_placement_table()
    placement_table = DataFrame(space=Int[], item=Int[], width=Real[], height=Real[], depth=Real[], x=[], y=[], z=[])
    return placement_table
end

function add_container!(db::Database, dims::Vector{<:Real})
    id = size(db.containers, 1) + 1
    push!(db.containers, [id, dims..., dims[3]])
    return id
end

function add_layer!(db::Database, container, item, z, depth)
    id = size(db.layers, 1) + 1
    push!(db.layers, [id, container, item, z, depth])
    return id
end

function add_space!(db::Database, layer, dims, coords)
    push!(db.spaces, [layer, dims..., coords...])
end

function create_new_layer(db::Database)
    item_id = select_primary_item(db.items)
    layer_depth = db.items[item_id, [:dim1,:dim2,:dim3]] |> maximum
    container_candidates = filter(:remaining_depth => >=(layer_depth), db.containers)
    if !isempty(container_candidates)
        container = first(container_candidates)
        z = container[:depth] - container[:remaining_depth]
        layer_id = add_layer!(db.layers, container[:id], item_id, z, layer_depth)
        add_space!(db.spaces, layer_id, [container[:width], container[:height], layer_depth], [0, 0, 0])
        db.containers[container[:id], :remaining_depth] -= layer_depth
        return last(db.layers)[:id]
    end
    return 0
end

function add_item!(db::Database, dims::Vector{<:Real}, quantity::Int)
    push!(db.items, [size(db.items, 1) + 1, dims..., quantity, 0, false])
end

function unopen_ranking_one(db::Database)
    R = filter(:quantity => q -> q > 0, db.items[:,[:id, :quantity]])
    R[:, :min_dim] = [minimum(row_dims) for row_dims in eachrow(db.items[:,[:dim1, :dim2, :dim3]])]
    filter!(:min_dim => ==(maximum(R[:,:min_dim])), R)
    return R
end

function unopen_ranking_two!(R)
    filter!(:quantity => ==(maximum(R[:,:quantity])), R)
end

function unopen_ranking_three!(db::Database, R)
    candidates = innerjoin(db.items, R[:,Not(:quantity)], on=:id)
    R[:, :max_dim] = [maximum(row_dims) for row_dims in eachrow(candidates[:,[:dim1,:dim2,:dim3]])]
end

function unopen_ranking(db::Database)
    R = unopen_ranking_one(db.items)
    unopen_ranking_two!(R)
    unopen_ranking_three!(db.items, R)
    return R[:,:id]
end

function open_ranking(db::Database)
    R = filter(:open => ==(true), db.items)
    filter!(:quantity => ==(maximum(R[:,:quantity])), R)
    return R[1,:id]
end

function any_items_open(db::Database)
    return any(==(true), db.items[:,:open])
end

function select_primary_item(db::Database)
    return any_items_open(db.items) ? open_ranking(db.items) : unopen_ranking(db.items) |> only
end

function add_placement!(db::Database, item_id, space_id, dims, coords)
    push!(db.placements, [space_id, item_id, dims..., coords...])
end

function find_fitting_items(db::Database, space_id)
    fitting_items = []
    space = db.spaces[space_id,:]
    candidates = filter(row -> row[:quantity] > 0, db.items)
    for candidate = eachrow(candidates)
        candidate_dims = candidate[[:dim1,:dim2,:dim3]] |> collect |> sort
        space_dims = space[[:width,:height,:depth]] |> collect |> sort
        if all(space_dims .>= candidate_dims)
            push!(fitting_items, candidate)
        end
    end
    return fitting_items
end

function select_fitting_item(db::Database, space_id, fitting_items)
    space = db.spaces[space_id, :]
    multicolumn_candidates = DataFrame(id=[], width=[], height=[], depth=[])
    for row = eachrow(fitting_items)
        for perm in permutations(row[[:dim1,:dim2,:dim3]])
            if perm[1] <= 0.5 * space[:width] && perm[2] <= space[:height] && perm[3] <= space[:depth]
                push!(multicolumn_candidates, [row[:id], perm...])
            end
        end
    end
    return multicolumn_candidates
end

##
#TESTS
db = Database()
add_item!(db, [.4, .4, .5], 122)
add_item!(db, [.27, .43, .32], 124)
add_item!(db, [.5, .6, .4], 1383)
add_container!(db, [2.2, 3.5, 7.2])
create_new_layer(db)