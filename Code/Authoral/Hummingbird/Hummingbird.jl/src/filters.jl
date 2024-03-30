"""
Filters all the items that have remaining quantities greater than zero.
"""
function filter_remaining_items(table, node::ContainerNode)
    if typeof(table) <: DataFrameRow
        if node.stock[table[:id]] > 0
            return table
        else
            return
        end
    end
    I = findall(>(0), node.stock)
    return filter(row -> row[:id] in I, table)
end

"""
Filters all the items that are marked as open.
"""
function filter_open_items(table, node::ContainerNode)
    if typeof(table) <: DataFrameRow
        if node.open[table[:id]]
            return table
        else
            return
        end
    end
    I = findall(node.open)
    return filter(row -> row[:id] in I, table)
end

"""
Filters all the items that have at least one dimension smaller than the remaining container depth.
"""
function filter_fitting_depths(table, node::ContainerNode)
    if typeof(table) <: DataFrameRow
        if any(table[[:dim1,:dim2,:dim3]]) <= node.remaining_depth
            return table
        else
            return
        end
    end
    dims = [minimum(row[[:dim1,:dim2,:dim3]]) for row in eachrow(table)]
    I = findall(<=(node.remaining_depth), dims)
    return filter(row -> row[:id] in I, table)
end

"""
Filters items whose smallest dimension is the greatest among all items.
"""
function filter_max_least_dim(table)
    if typeof(table) <: DataFrameRow
        return table
    end
    ids = table[:,:id]
    dims = [minimum(row[[:dim1,:dim2,:dim3]]) for row in eachrow(table)]
    accepted = findall(==(maximum(dims)), dims)
    I = ids[accepted]
    return filter(row -> row[:id] in I, table)
end

"""
Filters items whose remaining quantity is the greatest among all items.
"""
function filter_greatest_quantity(table, node::ContainerNode)
    if typeof(table) <: DataFrameRow
        return table
    end
    ids = table[:,:id]
    accepted = findall(==(maximum(node.stock[table[:,:id]])), node.stock[table[:,:id]])
    I = ids[accepted]
    return filter(row -> row[:id] in I, table)
end

"""
Filters items whose greatest dimension is the greatest among all items.
"""
function filter_max_greatest_dim(table)
    if typeof(table) <: DataFrameRow
        return table
    end
    ids = table[:,:id]
    dims = [maximum(row[[:dim1,:dim2,:dim3]]) for row in eachrow(table)]
    accepted = findall(==(maximum(dims)), dims)
    I = ids[accepted]
    return filter(row -> row[:id] in I, table)
end

"""
Checks if there are any items marked as open in the database.
"""
function any_items_open(node::ContainerNode)
    return any(==(true), node.open)
end

"""
Checks if there are any items with remaining quantity greater than zero in the database.
"""
function any_items_left(node::ContainerNode)
    return any(>(0), node.stock)
end

"""
Applies all primary item selection filters to the database's list of items.
"""
function all_item_filters(table, node::ContainerNode)
    table = filter_remaining_items(table, node) |> filter_max_least_dim
    return filter_greatest_quantity(table, node) |> filter_max_greatest_dim
end