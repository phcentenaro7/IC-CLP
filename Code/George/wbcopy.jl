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

new_id(table) = size(table, 1) + 1

function new_container_table()
    container_table = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], remaining_depth=Real[])
    return container_table
end

function new_layer_table()
    layer_table = DataFrame(id=Int[], container=Int[], item=Int[], z=Real[], depth=Real[])
    return layer_table
end

function new_space_table()
    space_table = DataFrame(id=Int[], layer=Int[], width=Real[], height=Real[], depth=Real[], x=Real[], y=Real[], z=Real[], type=Symbol[], status=Symbol[], partner=Int[], sibling=Int[], flexible_width=Real[])
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
    id = new_id(db.containers)
    push!(db.containers, [id, dims..., dims[3]])
    return db.containers[id,:]
end

function add_layer!(db::Database, container, item, z, depth)
    id = new_id(db.layers)
    push!(db.layers, [id, container, item, z, depth])
    return db.layers[id,:]
end

function add_space!(db::Database, layer, dims, coords, type)
    id = new_id(db.spaces)
    push!(db.spaces, [id, layer, dims..., coords..., type, :new, 0, 0, 0])
    return db.spaces[id,:]
end

function create_new_layer(db::Database)
    item_id = select_primary_item(db)
    layer_depth = db.items[item_id, [:dim1,:dim2,:dim3]] |> maximum
    container_candidates = filter(:remaining_depth => >=(layer_depth), db.containers)
    if !isempty(container_candidates)
        container = first(container_candidates)
        z = container[:depth] - container[:remaining_depth]
        layer = add_layer!(db, container[:id], item_id, z, layer_depth)
        add_space!(db, layer[:id], [container[:width], container[:height], layer_depth], [0, 0, z], :primary)
        db.containers[container[:id], :remaining_depth] -= layer_depth
        return layer
    end
    return 0
end

function add_item!(db::Database, dims::Vector{<:Real}, quantity::Int)
    id = new_id(db.items)
    push!(db.items, [id, dims..., quantity, 0, false])
    return db.items[id,:]
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
    R = unopen_ranking_one(db)
    unopen_ranking_two!(R)
    unopen_ranking_three!(db, R)
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
    return any_items_open(db) ? open_ranking(db) : unopen_ranking(db) |> only
end

function add_placement!(db::Database, item_id, space_id, dims, coords)
    push!(db.placements, [space_id, item_id, dims..., coords...])
    return db.placements[size(db.placements, 1),:]
end

function find_fitting_items(db::Database, space_id)
    fitting_items = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], quantity=Int[], placed=Int[], open=Bool[])
    space = db.spaces[space_id,:]
    space_dims = space[[:width,:height,:depth]] |> collect |> sort
    candidates = filter(row -> row[:quantity] > 0, db.items)
    for candidate = eachrow(candidates)
        for perm in permutations(candidate[[:dim1,:dim2,:dim3]])
            perm = collect(perm)
            if all(space_dims .>= perm)
                candidate[[:dim1,:dim2,:dim3]] = perm
                push!(fitting_items, candidate |> collect)
            end
        end
    end
    return fitting_items
end

function select_fitting_item(db::Database, space_id, fitting_items)
    local selected_item
    space = db.spaces[space_id, :]
    multicolumn_candidates = DataFrame()
    for row = eachrow(fitting_items)
        if row[:width] <= 0.5 * space[:width]
            push!(multicolumn_candidates, row)
        end
    end
    if !isempty(multicolumn_candidates)
        selected_item = filter(:depth => ==(maximum(multicolumn_candidates[:,:depth])), multicolumn_candidates) |> first
    else
        best_area = 0
        for group in groupby(fitting_items, :id)
            single_candidates = filter(:depth => ==(maximum(group[:,:depth])), group)
            filter!(:width => ==(maximum(single_candidates[:,:width])), single_candidates)
            candidate = first(single_candidates)
            area = candidate[:width] * candidate[:depth]
            if area > best_area
                selected_item = candidate
                best_area = area
            end
        end
    end
    return selected_item
end

function select_item_cross_sectional_rotation!(db::Database, item, space_id)
    space = db.spaces[space_id,:]
    if item[:width] <= space[:height] && item[:height] <= space[:width]
        if can_complete_column(db, item[:height], space_id) || can_complete_column(db, item[:width], space_id)
            if column_height(db, item[:width], space_id) > column_height(db, item[:height], space_id)
                item[:width], item[:height] = item[:height], item[:width]
            end
        else
            if item[:height] > item[:width]
                item[:width], item[:height] = item[:height], item[:width]
            end
        end
    end
end

function can_complete_column(db::Database, item_height, space_id)
    space = db.spaces[space_id,:]
    return item[:quantity] >= floor(space[:height] / item_height)
end

function column_height(db::Database, item_height, space_id)
    space = db.spaces[space_id,:]
    return floor(space[:height] / item_height) * item_height
end

function find_amalgamation_partner(db::Database, space_id)
    space = db.spaces[space_id,:]
    candidate = filter(row -> row[:layer] == space[:layer] - 1 &&
                        row[:status] == :rejected &&
                        row[:type] == :depthwise &&
                        row[:y] <= space[:y] &&
                        row[:z] + row[:depth] == space[:z], db.spaces)
    if !isempty(candidate)
        return first(candidate)
    end
end

function amalgamate(db::Database, space_id, partner_id, flexible_ratio)
    space = db.spaces[space_id,:]
    space[:sibling] = new_id(db.spaces)
    partner = db.spaces[partner_id,:]
    partner[:partner] = new_id(db.spaces)
    x, y, z = max(space.x, partner.x), space.y, partner.z
    width, height, depth =  space.width - x, space.height, space.depth + partner.depth
    amalgam = add_space!(db, partner[:layer], [width, height, depth], [x, y, z], :amalgam)
    flexible_width = amalgam[:width] * flexible_ratio
    amalgam[:flexible_width] = flexible_width
    space[:width] = amalgam[:x] - space[:x]
    space[:flexible_width] = flexible_width
end

function fill_column(db::Database, item, space_id, x)
    space = db.spaces[space_id,:]
    item_type = db.items[item[:id],:]
    y, z = space[[:y,:z]]
    while y + item[:height] <= space[:y] + space[:height] && item_type.quantity > 0
        item_type.quantity -= 1
        add_placement!(db, item[:id], space[:id], item[[:width, :height, :depth]], [x, y, z])
        y += item[:height]
    end
    return y
end

function fill_space(db::Database, item, space_id)
    space = db.spaces[space_id,:]
    sibling = space[:type] != :amalgam && !iszero(space[:sibling]) ? space[:sibling] : nothing
    item_type = db.items[item[:id],:]
    x = space[:x]
    max_col_height, last_col_height = column_height(db, item[:height], space_id), 0
    used_flexible_width = 0
    columns = 0
    while item_type.quantity > 0 && used_flexible_width <= 0
        used_flexible_width = (x + item[:width]) - (space[:x] + space[:width])
        if space[:flexible_width] >= used_flexible_width > 0 && !isnothing(sibling)
            sibling[:x] += used_flexible_width
            sibling[:width] -= used_flexible_width
        elseif used_flexible_width > space[:flexible_width]
            break
        end
        last_col_height = fill_column(db, item, space_id, x)
        columns += 1
        x += item[:width]
    end
    create_new_spaces(db, space_id, columns, item[:width], item[:depth], max_col_height, last_col_height)
    space[:status] = :filled
end

function create_new_spaces(db::Database, space_id, columns, item_width, item_depth, max_col_height, last_col_height)
    space = db.spaces[space_id,:]
    items = filter(:quantity => >(0), db.items)
    min_dim = [minimum(items[:,:dim1]), minimum(items[:,:dim2]), minimum(items[:,:dim3])] |> minimum
    if columns > 1
        if space[:height] - max_col_height >= min_dim
            width, height, depth = columns * item_width, space[:height] - max_col_height, space[:depth]
            x, y, z = space[:x], space[:y] + max_col_height, space[:z]
            if last_col_height != max_col_height
                add_space!(db, space[:layer], [width - item_width, height, depth], [x, y, z], :heightwise)
                last_width, last_height, last_depth = item_width, space[:height] - last_col_height, depth
                last_x, last_y, last_z = x + width - item_width, space[:y] + last_col_height, space[:z]
                add_space!(db, space[:layer], [last_width, last_height, last_depth], [last_x, last_y, last_z], :heightwise)
            else
                add_space!(db, space[:layer], [width, height, depth], [x, y, z], :heightwise)
            end
        end
    else
        if space[:height] - last_col_height >= min_dim
            width, height, depth = columns * item_width, space[:height] - last_col_height, space[:depth]
            x, y, z = space[:x], space[:y] + last_col_height, space[:z]
            add_space!(db, space[:layer], [width, height, depth], [x, y, z], :heightwise)
        end
    end
    if space[:width] - columns * item[:width] >= min_dim
        width, height, depth = space[:width] - columns * item[:width], space[:height], space[:depth]
        x, y, z = space[:x] + columns * item[:width], space[:y], space[:z]
        add_space!(db, space[:layer], [width, height, depth], [x, y, z], :widthwise)
    end
    if space[:depth] - item_depth > 0
        width, height, depth = space[:width], space[:height], space[:depth] - item_depth
        x, y, z = space[:x], space[:y], space[:z] + item_depth
        add_space!(db, space[:layer], [width, height, depth], [x, y, z], :depthwise)
    end
end

##
#TESTS
db = Database()
add_item!(db, [40, 40, 50], 122)
add_item!(db, [17, 43, 32], 124)
add_item!(db, [50, 60, 40], 1383)
add_container!(db, [220, 350, 720])
create_new_layer(db)

fitting_items = find_fitting_items(db, 1)
item = select_fitting_item(db, 1, fitting_items)
select_item_cross_sectional_rotation!(db, item, 1)
fill_space(db, item, 1)

fitting_items = find_fitting_items(db, 2)
item = select_fitting_item(db, 2, fitting_items)
select_item_cross_sectional_rotation!(db, item, 2)
fill_space(db, item, 2)

n = 6

fitting_items = find_fitting_items(db, n)
item = select_fitting_item(db, n, fitting_items)
select_item_cross_sectional_rotation!(db, item, n)
fill_space(db, item, n)