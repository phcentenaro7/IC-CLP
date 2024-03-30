using Combinatorics

"""
Selects a layer's primary item. If no item is marked as `open` in the container, then a series of ranking filters is applied to the items in stock, and the first remaining option is selected. The filters are:

1. Maximum smallest dimension;
2. Maximum remaining stock;
3. Maximum largest dimension.

If any item marked as `open` exists with remaining stock, then only `open` items will be considered for selection. By default, optional argument `separate_rankings` is set to `true`, which means that the `open` item with the greatest remaining stock is selected. Otherwise, the same ranking criteria described above is applied to the `open` items.
"""
function select_primary_item(db::Database, node::ContainerNode; separate_rankings=true)
    table = db.items
    if any_items_open(node)
        table = filter_open_items(table, node)
        if separate_rankings
            table = filter_greatest_quantity(table, node)
            return noerror_first(table)
        end
    end
    table = filter_fitting_depths(db.items, node)
    table = all_item_filters(table, node)
    return noerror_first(table)
end

"""
Selects the greatest possible depth for a layer based on its primary item, with the container's remaining depth accounted for.
"""
function select_layer_depth(item, node::ContainerNode)
    dims = item[[:dim1,:dim2,:dim3]] |> collect |> sort
    i = findlast(<=(node.remaining_depth), dims)
    return isnothing(i) ? nothing : dims[i]
end

"""
Creates a new layer within the given container.
"""
function create_new_layer!(db::Database, node::ContainerNode; separate_rankings=true)
    item = select_primary_item(db, node, separate_rankings=separate_rankings)
    if isnothing(item)
        return
    end
    depth = select_layer_depth(item, node)
    if isnothing(depth)
        return
    end
    container = db.containers[node.container_id,:]
    z = container[:depth] - node.remaining_depth
    layer = add_layer!(node, item[:id], z, depth)
    add_space!(node, layer[:id], [container[:width], container[:height], depth], [0, 0, z], :primary)
    node.remaining_depth -= depth
    return layer
end

"""
Finds all item rotations that fit within the specified space.
"""
function find_fitting_items(db::Database, node::ContainerNode, space_id)
    fitting_items = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], quantity=Int[], volume=Float64[])
    space_dims = node.spaces[space_id,[:width,:height,:depth]] |> collect |> sort
    candidates = filter_remaining_items(db.items, node)
    for candidate in eachrow(candidates)
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

"""
Selects one of the item rotations that fit in the specified space. If any rotations can be stacked in multiple columns across the space's width, then the one with the greatest depth is selected. Otherwise, the item rotation with the greatest base area is selected.
"""
function select_fitting_item(node::ContainerNode, space_id, fitting_items)
    space = node.spaces[space_id, :]
    selected_item = DataFrame()
    multicolumn_candidates = DataFrame()
    for row in eachrow(fitting_items)
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

"""
Checks if it's possible to complete a column with the specified item type and space. A column is considered complete if no more units of the item type can be stacked on top of it without violating the space's height.
"""
function can_complete_column(item_quantity, item_height, space_height)
    return item_quantity >= floor(space_height / item_height)
end

"""
Determines how many items of the specified height a complete column contains.
"""
function items_per_column(item_height, space_height)
    return floor(space_height / item_height)
end

"""
Determines the height of a complete column of items.
"""
function column_height(item_height, space_height)
    return items_per_column(item_height, space_height) * item_height
end

"""
Selects a cross-sectional rotation for an item. This function first checks if the item's width and height can be swapped. If so, there are two scenarios where the swap happens:

* If any of the rotations can complete a column, and the swap rotation gives the greater column height;
* If none of the rotations can complete a column, and the swap rotation gives the lesser item height.
"""
function select_item_cross_sectional_rotation!(node::ContainerNode, item, space_id)
    space = node.spaces[space_id,:]
    if item[:width] <= space[:height] && item[:height] <= space[:width]
        if any(can_complete_column(node.stock[item[:id]], item[dim], space[:height]) for dim in [:width,:height])
            if column_height(item[:width], space[:height]) > column_height(item[:height], space[:height])
                item[:width], item[:height] = item[:height], item[:width]
            end
        else
            if item[:height] > item[:width]
                item[:width], item[:height] = item[:height], item[:width]
            end
        end
    end
end

"""
Selects an item to fill a given space and rotates it according to the wall-building heuristic's rules.
"""
function select_item_for_space(db::Database, node::ContainerNode, space_id)
    space = node.spaces[space_id,:]
    selected_item = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], quantity=Int[], volume=Float64[])
    if space[:type] == :primary
        layer = node.layers[space[:layer],:]
        primary_item = db.items[layer[:item],:]
        push!(selected_item, primary_item |> collect)
        selected_item = only(selected_item)
        dims = selected_item[[:width,:height,:depth]] |> collect
        popat!(dims, findfirst(==(layer.depth), dims))
        selected_item[[:width,:height,:depth]] = dims..., layer.depth
    else
        fitting_items = find_fitting_items(db, node, space_id)
        if isempty(fitting_items)
            return
        end
        selected_item = select_fitting_item(node, space_id, fitting_items)
    end
    select_item_cross_sectional_rotation!(node, selected_item, space_id)
    return selected_item
end

"""
Finds potential amalgamation partners for the current space. Specifically, this function searches the previous layer for rejected spaces that are adjacent to the current space and at the same height or lower.
"""
function find_amalgamation_partner(node::ContainerNode, space_id)
    space = node.spaces[space_id,:]
    if space[:layer] == 1
        return
    end
    partners = filter(row -> row[:layer] == space[:layer] - 1 &&
                        row[:status] == :rejected &&
                        row[:type] == :depthwise &&
                        row[:x] + row[:width] > space[:x] &&
                        row[:x] < space[:x] + space[:width] &&
                        row[:y] <= space[:y] &&
                        row[:z] + row[:depth] == space[:z], node.spaces)
    if isempty(partners)
        return
    end
    partner = filter(row -> row[:depth] == minimum(partners[:,:depth]), partners) |> first
    return partner
end

"""
Amalgamates the current space with a partner. In this process, the original space is kept in the list of spaces, and an amalgam space is created. The original space may eventually overlap with the amalgam within a region defined by a flexible width which spans `flexible_ratio` times the width of the amalgam.
"""
function amalgamate!(node::ContainerNode, space_id, partner_id, flexible_ratio)
    space = node.spaces[space_id,:]
    space[:sibling] = new_id(node.spaces)
    space[:partner] = partner_id
    partner = node.spaces[partner_id,:]
    partner[:partner] = space[:id]
    partner[:status] = :amalgamated
    x, y, z = max(space.x, partner.x), space.y, partner.z
    width, height, depth =  space.width - x, space.height, space.depth + partner.depth
    amalgam = add_space!(node, space[:layer], [width, height, depth], [x, y, z], :amalgam)
    flexible_width = amalgam[:width] * flexible_ratio
    amalgam[:flexible_width] = flexible_width
    amalgam[:sibling] = space[:id]
    space[:width] = amalgam[:x] - space[:x]
    space[:flexible_width] = flexible_width
end

"""
Fills a column with the specified item rotation at horizontal coordinate `x`, at the back of the space.
"""
function fill_column!(node::ContainerNode, item, space_id, x)
    space = node.spaces[space_id,:]
    item_id = item[:id]
    max_items = items_per_column(item[:height], space[:height])
    placed = node.stock[item_id] < max_items ? node.stock[item_id] : max_items
    node.stock[item_id] -= placed
    node.open[item_id] = true
    y, z = space[[:y,:z]]
    add_placement!(node, item[:id], space[:id], placed, item[[:width, :height, :depth]], [x, y, z])
    return item[:height] * placed
end

"""
Creates a heightwise space on top of a stack of boxes. Optional argument `last_column` is `false` by default, in which case this function creates a space over as many columns as specified. If `last_column` is set to `true`, then the function fills only the last of the specified columns.
"""
function create_heightwise_space!(node::ContainerNode, space_id, columns, item_width, col_height; last_column=false)
    space = node.spaces[space_id,:]
    width = item_width * (last_column ? 1 : columns) 
    height, depth = space[:height] - col_height, space[:depth]
    x, y, z = space[:x], space[:y] + col_height, space[:z]
    if last_column
        x += (columns - 1) * item_width
    end
    new_space = add_space!(node, space[:layer], [width, height, depth], [x, y, z], :heightwise)
    if space[:type] == :amalgam || space[:from_amalgam]
        new_space[:from_amalgam] = true
    end
end

"""
Creates a widthwise space to the right of a stack of boxes.
"""
function create_widthwise_space!(node::ContainerNode, space_id, item_width, columns)
    space = node.spaces[space_id,:]
    width, height, depth = space[:width] - columns * item_width, space[:height], space[:depth]
    x, y, z = space[:x] + columns * item_width, space[:y], space[:z]
    new_space = add_space!(node, space[:layer], [width, height, depth], [x, y, z], :widthwise)
    if space[:type] == :amalgam || space[:from_amalgam]
        new_space[:from_amalgam] = true
    end
end

"""
Creates a depthwise space in front of a stack of boxes.
"""
function create_depthwise_space!(node::ContainerNode, space_id, item_depth)
    space = node.spaces[space_id,:]
    width, height, depth = space[:width], space[:height], space[:depth] - item_depth
    x, y, z = space[:x], space[:y], space[:z] + item_depth
    new_space = add_space!(node, space[:layer], [width, height, depth], [x, y, z], :depthwise)
    if space[:type] == :amalgam || space[:from_amalgam]
        new_space[:from_amalgam] = true
    end
end

"""
Creates all possible widthwise, heightwise and depthwise spaces relative to a stack of items.
"""
function create_new_spaces!(db::Database, node::ContainerNode, space_id, columns, item_width, item_depth, max_col_height, last_col_height)
    space = node.spaces[space_id,:]
    I = findall(>(0), node.stock)
    if isempty(I)
        return
    end
    items = db.items[I,:]
    min_dim = [minimum(items[:,:dim1]), minimum(items[:,:dim2]), minimum(items[:,:dim3])] |> minimum
    if columns > 1 && last_col_height < max_col_height
        if space[:height] - max_col_height >= min_dim
            create_heightwise_space!(node, space_id, columns - 1, item_width, max_col_height)
        end
        if space[:height] - last_col_height >= min_dim
            create_heightwise_space!(node, space_id, columns, item_width, last_col_height, last_column=true)
        end
    elseif space[:height] - last_col_height >= min_dim
        create_heightwise_space!(node, space_id, columns, item_width, last_col_height)
    end
    if space[:width] - item_width * columns >= min_dim
        create_widthwise_space!(node, space_id, item_width, columns)
    end
    if space[:depth] - item_depth > 0
        create_depthwise_space!(node, space_id, item_depth)
    end
end

"""
Fills a space with as many items of a certain rotation as possible.
"""
function fill_space!(db::Database, node::ContainerNode, item, space_id)
    space = node.spaces[space_id,:]
    sibling = nothing
    if space[:type] != :amalgam && !iszero(space[:sibling])
        sibling = node.spaces[space[:sibling],:]
    end
    item_type = db.items[item[:id],:]
    x = space[:x]
    max_col_height, last_col_height = column_height(item[:height], space[:height]), 0
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
        last_col_height = fill_column!(node, item, space_id, x)
        columns += 1
        x += item[:width]
    end
    create_new_spaces!(db, node, space_id, columns, item[:width], item[:depth], max_col_height, last_col_height)
    space[:status] = :filled
end

"""
Fills a container with the wall-building heuristic.
"""
function fill_container!(db::Database, node::ContainerNode; flexible_ratio=.0, separate_rankings=true)
    create_new_layer!(db, node, separate_rankings=separate_rankings)
    i = 1
    while i <= nrow(node.spaces)
        space = node.spaces[i,:]
        partner = find_amalgamation_partner(node, space[:id])
        if !isnothing(partner)
            amalgamate!(node, space[:id], partner[:id], flexible_ratio)
        end
        item = select_item_for_space(db, node, space[:id])
        if isnothing(item)
            space[:status] = :rejected
        else
            fill_space!(db, node, item, space[:id])
        end
        if i == nrow(node.spaces)
            if !any_items_left(node)
                break
            end
            create_new_layer!(db, node, separate_rankings=separate_rankings)
        end
        i += 1
    end
    node.filled_volume = get_filled_volume(db, node)
end