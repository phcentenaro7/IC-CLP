using DataFrames

mutable struct Database
    containers::DataFrame
    spaces::DataFrame
    items::DataFrame
    placements::DataFrame
    Database() = new(new_container_table(), new_layer_table(), new_space_table(), new_item_table(), new_placement_table())
end

new_id(table) = size(table, 1) + 1

function new_container_table()
    container_table = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[])
    return container_table
end

function new_space_table()
    space_table = DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], x=Real[], y=Real[], z=Real[])
    return space_table
end

function new_item_table()
    item_table = DataFrame(id=Int[], dim1=Real[], dim2=Real[], dim3=Real[], quantity=Int[])
    return item_table
end

function new_placement_table()
    placement_table = DataFrame(space=Int[], item=Int[], quantity=Real[], width=Real[], height=Real[], depth=Real[], x=[], y=[], z=[])
    return placement_table
end