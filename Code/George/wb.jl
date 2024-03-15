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

"""
Creates a new table of containers. Each container is defined by:

* Width, height and depth;
* A variable indicating the depth that remains unused by any layers.
"""
function new_container_table()
    container_table = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], remaining_depth=Real[])
    return container_table
end

"""
Creates a new table of layers. Each layer is defined by:

* The container to which it belongs;
* The item that was used to determine the layer's depth;
* The ``z`` coordinate of the layer within the container;
* The depth of the layer.
"""
function new_layer_table()
    layer_table = DataFrame(id=Int[], container=Int[], item=Int[], z=Real[], depth=Real[])
    return layer_table
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
    space_table = DataFrame(id=Int[], layer=Int[], width=Real[], height=Real[], depth=Real[], x=Real[], y=Real[], z=Real[], type=Symbol[], status=Symbol[], partner=Int[], sibling=Int[], flexible_width=Real[], from_amalgam=Bool[])
    return space_table
end

"""
Creates a new table of items. Each item is defined by:

* The dimensions of the item;
* The quantity initially in stock;
* Whether the item is open or not (that is, whether any item of this type has already been placed or not).
"""
function new_item_table()
    item_table = DataFrame(id=Int[], dim1=Real[], dim2=Real[], dim3=Real[], quantity=Int[], open=Bool[])
    return item_table
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
    placement_table = DataFrame(space=Int[], item=Int[], quantity=Real[], width=Real[], height=Real[], depth=Real[], x=[], y=[], z=[])
    return placement_table
end

"""
Adds a container to the database.
"""
function add_container!(db::Database, dims::Vector{<:Real})
    id = new_id(db.containers)
    push!(db.containers, [id, dims..., dims[3]])
    return db.containers[id,:]
end

"""
Adds a layer to the database.
"""
function add_layer!(db::Database, container, item, z, depth)
    id = new_id(db.layers)
    push!(db.layers, [id, container, item, z, depth])
    return db.layers[id,:]
end

"""
Adds a space to the database.
"""
function add_space!(db::Database, layer, dims, coords, type)
    id = new_id(db.spaces)
    push!(db.spaces, [id, layer, dims..., coords..., type, :new, 0, 0, 0, false])
    return db.spaces[id,:]
end

function create_new_layer!(db::Database, container_id)
    item_id = select_primary_item(db)
    layer_depth = db.items[item_id, [:dim1,:dim2,:dim3]] |> maximum
    container_candidates = filter(:remaining_depth => >=(layer_depth), db.containers)
    if !isempty(container_candidates)
        container = filter(row -> row[:remaining_depth] >= layer_depth, container_candidates) |> first
        z = container[:depth] - container[:remaining_depth]
        layer = add_layer!(db, container[:id], item_id, z, layer_depth)
        add_space!(db, layer[:id], [container[:width], container[:height], layer_depth], [0, 0, z], :primary)
        db.containers[container[:id], :remaining_depth] -= layer_depth
        return layer
    end
    return 0
end

"""
Adds an item to the database.
"""
function add_item!(db::Database, dims::Vector{<:Real}, quantity::Int)
    id = new_id(db.items)
    push!(db.items, [id, dims..., quantity, false])
    return db.items[id,:]
end

"""
Filters all the items that have remaining quantities greater than zero in the database.
"""
function filter_remaining_items(R)
    return filter(row -> row[:quantity] > 0, R)
end

"""
Filters all the items that are marked as open in the database.
"""
function filter_open_items(R)
    return filter(row -> row[:open] == true, R)
end

"""
Filters all the items that have at least one dimension smaller than container depth `k`.
"""
function filter_fitting_depths(R, k)
    dims = [minimum(row_dims) for row_dims in eachrow(db.items[:,[:dim1, :dim2, :dim3]])]
    I = findall(<=(k), dims)
    return R[I,:]
end

"""
Filters items whose smallest dimension is the greatest among all items.
"""
function filter_max_least_dim(R)
    dims = [minimum(row_dims) for row_dims in eachrow(db.items[:,[:dim1, :dim2, :dim3]])]
    I = findall(==(maximum(dims)), dims)
    return R[I,:]
end

"""
Filters items whose remaining quantity is the greatest among all items.
"""
function filter_greatest_quantity(R)
    return filter(row -> row[:quantity] == maximum(R[:,:quantity]), R)
end

"""
Filters items whose greatest dimension is the greatest among all items.
"""
function filter_max_greatest_dim(R)
    dims = [maximum(row_dims) for row_dims in eachrow(R[:,[:dim1, :dim2, :dim3]])]
    I = findall(==(maximum(dims)), dims)
    return R[I,:]
end

function all_item_filters(R; open_only=false)
    R = filter_remaining_items(R)
    if open_only
        R = filter_open_items(R)
    end
    return R |> filter_max_least_dim |> filter_greatest_quantity |> filter_max_greatest_dim
end

"""
Checks if there are any items marked as open in the database.
"""
function any_items_open(db::Database)
    return any(==(true), db.items[:,:open])
end

"""
Checks if there are any items with remaining quantity greater than zero in the database.
"""
function any_items_left(db::Database)
    return any(>(0), db.items[:,:quantity])
end

"""
Selects a layer's primary item.
"""
function select_primary_item(db::Database; separate_rankings=true)
    println("a")
    R = db.items
    if any_items_open(db)
        if separate_rankings
            return R |> filter_open_items |> filter_greatest_quantity |> first
        end
        all_item_filters(R, open_only=true)
    end 
    println("b")
    R = all_item_filters(R)
    println(R)
    println(R |> first) 
    return R |> first
end

function add_placement!(db::Database, item_id, space_id, quantity, dims, coords)
    push!(db.placements, [space_id, item_id, quantity, dims..., coords...])
    return db.placements[size(db.placements, 1),:]
end

function find_fitting_items(db::Database, space_id)
    fitting_items = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], quantity=Int[], open=Bool[])
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
    selected_item = DataFrame()
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
        if can_complete_column(db, item[:quantity], item[:height], space_id) || can_complete_column(db, item[:quantity], item[:width], space_id)
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

function select_item_for_space(db::Database, space_id)
    selected_item = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], quantity=Int[], open=Bool[])
    if db.spaces[space_id,:type] == :primary
        primary_item = db.items[db.layers[db.spaces[space_id,:layer],:item],:]
        push!(selected_item, primary_item |> collect)
        selected_item = only(selected_item)
        selected_item[[:width,:height,:depth]] = collect(selected_item[[:width,:height,:depth]]) |> sort
    else
        fitting_items = find_fitting_items(db, space_id)
        if isempty(fitting_items)
            return
        end
        selected_item = select_fitting_item(db, space_id, fitting_items)
    end
    select_item_cross_sectional_rotation!(db, selected_item, space_id)
    return selected_item
end

function can_complete_column(db::Database, item_quantity, item_height, space_id)
    space = db.spaces[space_id,:]
    return item_quantity >= floor(space[:height] / item_height)
end

function items_per_column(db::Database, item_height, space_id)
    space = db.spaces[space_id,:]
    return floor(space[:height] / item_height)
end

function column_height(db::Database, item_height, space_id)
    space = db.spaces[space_id,:]
    return floor(space[:height] / item_height) * item_height
end

function find_amalgamation_partner(db::Database, space_id)
    space = db.spaces[space_id,:]
    if space[:layer] == 1
        return
    end
    partners = filter(row -> row[:layer] == space[:layer] - 1 &&
                        row[:status] == :rejected &&
                        row[:type] == :depthwise &&
                        row[:x] + row[:width] > space[:x] &&
                        row[:x] < space[:x] + space[:width] &&
                        row[:y] <= space[:y] &&
                        row[:z] + row[:depth] == space[:z], db.spaces)
    if isempty(partners)
        return
    end
    partner = filter(row -> row[:depth] == minimum(partners[:,:depth]), partners) |> first
    return partner
end

function amalgamate!(db::Database, space_id, partner_id, flexible_ratio)
    space = db.spaces[space_id,:]
    space[:sibling] = new_id(db.spaces)
    space[:partner] = partner_id
    partner = db.spaces[partner_id,:]
    partner[:partner] = space[:id]
    partner[:status] = :amalgamated
    x, y, z = max(space.x, partner.x), space.y, partner.z
    width, height, depth =  space.width - x, space.height, space.depth + partner.depth
    amalgam = add_space!(db, space[:layer], [width, height, depth], [x, y, z], :amalgam)
    flexible_width = amalgam[:width] * flexible_ratio
    amalgam[:flexible_width] = flexible_width
    amalgam[:sibling] = space[:id]
    space[:width] = amalgam[:x] - space[:x]
    space[:flexible_width] = flexible_width
end

function fill_column(db::Database, item, space_id, x)
    space = db.spaces[space_id,:]
    item_type = db.items[item[:id],:]
    item_type[:open] = true
    y, z = space[[:y,:z]]
    max_items = items_per_column(db, item[:height], space_id)
    quantity = item_type[:quantity] < max_items ? item_type[:quantity] : max_items
    item_type.quantity -= quantity
    add_placement!(db, item[:id], space[:id], quantity, item[[:width, :height, :depth]], [x, y, z])
    return item[:height] * quantity
end

function create_heightwise_space!!(db::Database, space_id, columns, item_width, col_height; last_column=false)
    space = db.spaces[space_id,:]
    width = item_width * (last_column ? 1 : columns) 
    height, depth = space[:height] - col_height, space[:depth]
    x, y, z = space[:x], space[:y] + col_height, space[:z]
    if last_column
        x += (columns - 1) * item_width
    end
    new_space = add_space!(db, space[:layer], [width, height, depth], [x, y, z], :heightwise)
    if space[:type] == :amalgam || space[:from_amalgam]
        new_space[:from_amalgam] = true
    end
end

function create_widthwise_space!(db::Database, space_id, item_width, columns)

    space = db.spaces[space_id,:]
    width, height, depth = space[:width] - columns * item_width, space[:height], space[:depth]
    x, y, z = space[:x] + columns * item_width, space[:y], space[:z]
    new_space = add_space!(db, space[:layer], [width, height, depth], [x, y, z], :widthwise)
    if space[:type] == :amalgam || space[:from_amalgam]
        new_space[:from_amalgam] = true
    end
end

function create_depthwise_space!(db::Database, space_id, item_depth)
    space = db.spaces[space_id,:]
    width, height, depth = space[:width], space[:height], space[:depth] - item_depth
    x, y, z = space[:x], space[:y], space[:z] + item_depth
    new_space = add_space!(db, space[:layer], [width, height, depth], [x, y, z], :depthwise)
    if space[:type] == :amalgam || space[:from_amalgam]
        new_space[:from_amalgam] = true
    end
end

function create_new_spaces!(db::Database, space_id, columns, item_width, item_depth, max_col_height, last_col_height)
    space = db.spaces[space_id,:]
    items = filter(:quantity => >(0), db.items)
    if isempty(items)
        return
    end
    min_dim = [minimum(items[:,:dim1]), minimum(items[:,:dim2]), minimum(items[:,:dim3])] |> minimum
    if columns > 1 && last_col_height < max_col_height
        if space[:height] - max_col_height >= min_dim
            create_heightwise_space!!(db, space_id, columns - 1, item_width, max_col_height)
        end
        if space[:height] - last_col_height >= min_dim
            create_heightwise_space!!(db, space_id, columns, item_width, last_col_height, last_column=true)
        end
    elseif space[:height] - last_col_height >= min_dim
        create_heightwise_space!!(db, space_id, columns, item_width, last_col_height)
    end
    if space[:width] - item_width * columns >= min_dim
        create_widthwise_space!(db, space_id, item_width, columns)
    end
    if space[:depth] - item_depth > 0
        create_depthwise_space!(db, space_id, item_depth)
    end
end

function fill_space!(db::Database, item, space_id)
    space = db.spaces[space_id,:]
    sibling = nothing
    if space[:type] != :amalgam && !iszero(space[:sibling])
        sibling = db.spaces[space[:sibling],:]
    end
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
    create_new_spaces!(db, space_id, columns, item[:width], item[:depth], max_col_height, last_col_height)
    space[:status] = :filled
end

function wall_building!(db::Database; flexible_ratio=.0)
    create_new_layer!(db)
    i = 1
    while i <= nrow(db.spaces)
        space = db.spaces[i,:]
        partner = find_amalgamation_partner(db, space[:id])
        if !isnothing(partner)
            amalgamate!(db, space[:id], partner[:id], flexible_ratio)
        end
        item = select_item_for_space(db, space[:id])
        if isnothing(item)
            space[:status] = :rejected
        else
            fill_space!(db, item, space[:id])
        end
        if i == nrow(db.spaces)
            if !any_items_left(db)
                return
            end
            create_new_layer!(db)
        end
        i += 1
    end
end

function get_unfilled_volume(db::Database, container_id)
    container = db.containers[container_id,:]
    unfilled_volume = prod(container[[:width,:height,:depth]] |> collect)
    layer_ids = filter(row -> row[:container] == container_id, db.layers)[:,:id]
    space_ids = filter(row -> row[:layer] in layer_ids, db.spaces)[:,:id]
    placements = filter(row -> row[:space] in space_ids, db.placements)
    for placement in eachrow(placements)
        unfilled_volume -= prod(placement[[:quantity,:width,:height,:depth]] |> collect)
    end
    return unfilled_volume
end

function as_tikz(db::Database, layer_id, filename, item_colors; grid="major", view=:front)
    layer = db.layers[layer_id,:]
    spaces = filter(row -> row[:layer] == layer_id, db.spaces)
    container = db.containers[db.layers[layer_id,:container],:]
    out = open(filename, "w")
    write(out, "\\begin{tikzpicture}")
    write(out, "\n\t")
    if view == :front
        write(out, "\\begin{axis}[axis equal image, xmin=0, xmax=$(container[:width]), ymin=0, ymax=$(container[:height]), grid=$grid]")
    elseif view == :top
        write(out, "\\begin{axis}[axis equal image, xmin=0, xmax=$(container[:width]), ymin=0, ymax=$(layer[:depth]), grid=$grid]")
    end
    write(out, "\n")
    for space in eachrow(spaces)
        placements = filter(row -> row[:space] == space[:id], db.placements)
        for placement in eachrow(placements)
            pattern = ""
            if db.spaces[placement[:space],:type] == :amalgam || db.spaces[placement[:space],:from_amalgam]
                pattern = "crosshatch"
            end
            for n in 0:placement[:quantity]-1
                item = db.items[placement[:item],:]
                write(out, "\t\t")
                if view == :front
                    write(out, "\\filldraw[draw=black,fill=$(item_colors[item[:id]]),pattern=$pattern,pattern color=$(item_colors[item[:id]])] (axis cs:$(placement[:x]),$(placement[:y] + n * placement[:height])) rectangle (axis cs:$(placement[:x] + placement[:width]),$(placement[:y] + (n + 1) * placement[:height]));")
                elseif view == :top
                    write(out, "\\filldraw[draw=black,fill=$(item_colors[item[:id]]),pattern=$pattern,pattern color=$(item_colors[item[:id]])](axis cs:$(placement[:x]),$(placement[:z] - layer[:z])) rectangle (axis cs:$(placement[:x] + placement[:width]),$(placement[:z] + placement[:depth] - layer[:z]));")
                    break
                end
                write(out, "\n")
            end
        end
    end
    write(out, "\t")
    write(out, "\\end{axis}")
    write(out, "\n")
    write(out, "\\end{tikzpicture}")
    close(out)
end

function all_as_tikz(db::Database, path, colors; view=:front)
    for layer in eachrow(db.layers)
        as_tikz(db, layer[:id], path*"layer$(layer[:id]).tikz", colors, view=view)
    end
end

##
#TESTS
A = [220,350,720]
B = [260,440,1000]
C = [260,440,1400]
db = Database()
add_item!(db, [40, 40, 50], 122)
add_item!(db, [27, 43, 32], 124)
add_item!(db, [50, 60, 40], 1383)
add_container!(db, B)
add_container!(db, A)
add_container!(db, A)
wall_building!(db, flexible_ratio=.1)

# db = Database()
# add_item!(db, [5, 7, 10], 50)
# add_item!(db, [8, 3, 7], 70)
# add_item!(db, [3, 4, 5], 110)
# add_container!(db, [40, 50, 100])
# wall_building!(db, flexible_ratio=0)