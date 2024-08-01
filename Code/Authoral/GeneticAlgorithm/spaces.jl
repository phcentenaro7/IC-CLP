"""
Creates a new table of spaces. Each space is defined by:

* Width, height and depth;
* Coordinates defining its position within the container.
"""
function new_space_table()
    return DataFrame(id=Int[], width=Real[], height=Real[], depth=Real[], x=Real[], y=Real[], z=Real[], item=[], status=[])
end

"""
Adds a space to the container node.
"""
function add_space!(node::ContainerNode, dims, coords; item=0, type=:new)
    id = new_id(node.spaces)
    push!(node.spaces, [id, dims..., coords..., item, type])
    return node.spaces[id,:]
end

"""
Returns the vertices `(x1, y1, z1)` and `(x2, y2, z2)` that describe the cuboid space with ID `S`.
"""
function get_space_vertices(node::ContainerNode, S)
    x1, y1, z1 = node.spaces[S, [:x, :y, :z]]
    x2, y2, z2 = [x1, y1, z1] + (node.spaces[S, [:width, :height, :depth]] |> collect)
    return [(x1, y1, z1), (x2, y2, z2)]
end

"""
Returns a boolean value indicating whether intervals `I1` and `I2` overlap.
"""
function do_intervals_overlap(I1, I2; strict_inequality=true)
    if strict_inequality == true
        return (I1[1] > I2[1] || I1[2] > I2[1]) && (I1[1] < I2[2] || I1[2] < I2[2])
    end
    return (I1[1] >= I2[1] || I1[2] >= I2[1]) && (I1[1] <= I2[2] || I1[2] <= I2[2])
end

"""
Returns a boolean value indicating whether the spaces with IDs `S1` and `S2` overlap.
"""
function do_spaces_overlap(node::ContainerNode, S1, S2;  strict_inequality=true)
    (x11, y11, z11), (x12, y12, z12) = get_space_vertices(node, S1)
    (x21, y21, z21), (x22, y22, z22) = get_space_vertices(node, S2)
    return do_intervals_overlap([x11, x12], [x21, x22], strict_inequality=strict_inequality) && do_intervals_overlap([y11, y12], [y21, y22], strict_inequality=strict_inequality) && do_intervals_overlap([z11, z12], [z21, z22], strict_inequality=strict_inequality)
end


function are_spaces_adjacent(node::ContainerNode, S1, S2)
    return do_spaces_overlap(node, S1, S2, strict_inequality=false) && get_space_intersection(node, S1, S2) |> isnothing
end

"""
Receives a space vertex list and removes any spaces contained within other spaces.
"""
function reduce_space_vertex_list!(list)
    i = 1
    while i <= length(list)
        if any(k -> (all(list[i][1] .>= k[1]) && all(list[i][2] .<= k[2])), [list[1:i-1];list[i+1:end]])
            deleteat!(list, i)
            i = 1
            continue
        end
        i += 1
    end
end

"""
Returns two tuples, `(x1, y1, z1)` and `(x2, y2, z2)`, describing the vertices of the cuboid space corresponding to the intersection between spaces with IDs `S1` and `S2`. If the intersection is empty, returns `nothing` instead.
"""
function get_space_intersection(node::ContainerNode, S1, S2)
    if do_spaces_overlap(node, S1, S2) == false
        return
    end
    (x11, y11, z11), (x12, y12, z12) = get_space_vertices(node, S1)
    (x21, y21, z21), (x22, y22, z22) = get_space_vertices(node, S2)
    x1 = max(x11, x21)
    x2 = min(x12, x22)
    y1 = max(y11, y21)
    y2 = min(y12, y22)
    z1 = max(z11, z21)
    z2 = min(z12, z22)
    return [(x1, y1, z1), (x2, y2, z2)]
end

"""
Subtracts the space with ID `S2` from the space with ID `S1`.
"""
function subtract_space!(node::ContainerNode, S1, S2)
    Si = get_space_intersection(node, S1, S2)
    isnothing(Si) && return
    (x11, y11, z11), (x12, y12, z12) = get_space_vertices(node, S1)
    (x21, y21, z21), (x22, y22, z22) = Si
    spaces = [
         [(x11, y11, z11), (x21, y12, z12)],
         [(x22, y11, z11), (x12, y12, z12)],
         [(x11, y11, z11), (x12, y12, z21)],
         [(x11, y11, z22), (x12, y12, z12)],
         [(x21, y22, z21), (x22, y12, z22)]]
    volume(s) = prod(s[2] .- s[1])
    filter!(x -> volume(x) > 0, spaces)
    node.spaces[S1, :status] = :readjusted
    for space in spaces
        add_space!(node, space[2] .- space[1], space[1])
        # new_space = node.spaces[end, :]
        # if new_space[:y] > 0
        #     merge_candidate = filter(row -> row[:y] == new_space[:y] && row[:status] == :new && are_spaces_adjacent(node, new_space[:id], row[:id]), node.spaces) |> noerror_first
        #     if merge_candidate |> isnothing
        #         continue
        #     end
        #     local nx1, nx2, nz1, nz2
        #     ny1, ny2 = new_space[:y], new_space[:y] + new_space[:height]
        #     if new_space[:x] >= merge_candidate[:x] + merge_candidate[:width] || merge_candidate[:x] >= new_space[:x] + new_space[:width]
        #         nx1, nx2 = min(new_space[:x], merge_candidate[:x]), max(new_space[:x] + new_space[:width], merge_candidate[:x] + merge_candidate[:width])
        #         nz1, nz2 = max(new_space[:z], merge_candidate[:z]), min(new_space[:z] + new_space[:depth], merge_candidate[:z] + merge_candidate[:depth])
        #     else
        #         nx1, nx2 = max(new_space[:x], merge_candidate[:x]), min(new_space[:x] + new_space[:width], merge_candidate[:x] + merge_candidate[:width])
        #         nz1, nz2 = min(new_space[:z], merge_candidate[:z]), max(new_space[:z] + new_space[:depth], merge_candidate[:z] + merge_candidate[:depth])
        #     end
        #     add_space!(node, [nx2, ny2, nz2] - [nx1, ny1, nz1], [nx1, ny1, nz1], type=:merge)
        #     new_space[:status] = :merge
        #     merge_candidate[:status] = :merge
        # end
    end
end

"""
Returns a permutation of axes that allows for different interpretations of items' dimensions. For example, `p = :xyz` returns `[1,2,3]`, which means the first dimension is in `x`, the second in `y` and the third in `z`. If `p = :zyx`, then that means the first dimension is actually comparable to a container's third dimension, which specifies its depth. Hence, the value returned is `[3,2,1]`.
"""
function axis_permutation(p)
    return p == :xyz ? [1,2,3] :
           p == :xzy ? [1,3,2] :
           p == :yxz ? [2,1,3] :
           p == :zxy ? [2,3,1] :
           p == :yzx ? [3,1,2] :
           p == :zyx ? [3,2,1] :
           error("not a valid rotation symbol")
end

"""
Returns a vector representing the planes along a container. For example, `p = :xy` returns `[1,2]`, which means the first and second dimensions (`x` and `y`) of the container are taken into account, while the third (`z`) is ignored.
"""
function plane(p)
    return p == :xy ? [1,2] :
           p == :yx ? [2,1] :
           p == :xz ? [1,3] :
           p == :zx ? [3,1] :
           p == :yz ? [2,3] :
           p == :zy ? [3,2] :
           error("not a valid rotation symbol")
end

"""
Bottom-back-left procedure (BBL) to select the best space in the container to fit the item with ID `I`. The `r` (rotation) parameter may be any permutation of axes, as provided by function `axis_permutation`. If no space fits the BBL requirements, the function returns ID `0`.
"""
function bbl_procedure(db::Database, node::ContainerNode, I, r)
    best_x, best_y, best_z = Inf, Inf, Inf
    r = axis_permutation(r)
    spaces = filter(row -> row.status == :new || row.status == :merge, node.spaces)
    space_id = 0
    for space in eachrow(spaces)
        if all(collect(space[[:width,:height,:depth]]) .>= collect(db.items[I, [:dim1,:dim2,:dim3]])[r])
            if space[:x] < best_x || (space[:x] == best_x && space[:z] < best_z) || (space[:x] == best_x && space[:z] == best_z && space[:y] < best_y)
                space_id = space[:id]
                best_x, best_y, best_z = collect(space[[:x,:y,:z]])
            end
        end
    end
    return space_id
end



"""
Places item with ID `I` in the container, with the specified rotation `r`, along the specified plane `p`. The `r` parameter may be any permutation of axes, as provided by function `axis_permutation`. The `plane` parameter may be any permutation of axes, as provided by function `plane`. Importantly, the first axis in `p` is the one that the algorithm attempts to maximize. For instance, if `p = :xy`, then priority is given to filling the `x` axis over the `y` axis.
"""
function place_item!(db::Database, node::ContainerNode, stock, I, r, p)
    S = bbl_procedure(db, node, I, r)
    r = axis_permutation(r)
    p = plane(p)
    if S == 0
        return
    end
    space_dims = collect(node.spaces[S, [:width,:height,:depth]])
    item_dims = collect(db.items[I, [:dim1,:dim2,:dim3]])[r]
    strip_size = floor(space_dims[p[1]] / item_dims[p[1]])
    layer_dims = copy(item_dims)
    if stock[I] >= strip_size
        layer_dims[p[1]] *= strip_size
        stock[I] -= strip_size
        while layer_dims[p[2]] + item_dims[p[2]] <= space_dims[p[2]] && stock[I] >= strip_size
            layer_dims[p[2]] += item_dims[p[2]]
            stock[I] -= strip_size
        end
    else
        layer_dims[p[1]] *= stock[I]
        stock[I] = 0
    end
    add_space!(node, layer_dims, collect(node.spaces[S, [:x,:y,:z]]), item=I, type=:filled)
end