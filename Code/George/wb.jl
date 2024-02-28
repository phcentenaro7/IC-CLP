using ReusePatterns
using Match
using Combinatorics
import Base: push!, append!

"""
A union between Float64 and Int. Useful to allow both types as inputs to functions that require floats.
"""
FloatInt = Union{Float64, Int}

mutable struct Space
    w::Float64
    h::Float64
    d::Float64
    Space(w, h, d) = begin
        if w < 0 || h < 0 || d < 0 
            error("cannot create space with negative dimensions")
        else
            new(w, h, d)
        end
    end
end
width(s::Space) = s.w
height(s::Space) = s.h
depth(s::Space) = s.d
width(s::Space, w::FloatInt) = s.w = w
height(s::Space, h::FloatInt) = s.h = h
depth(s::Space, d::FloatInt) = s.d = d
area(s::Space, plane::Symbol) = begin
    return @match plane begin
        :wh || :hw => width(s) * height(s)
        :wd || :dw => width(s) * depth(s)
        :hd || :dh => height(s) * depth(s)
    end
end
volume(s::Space) = width(s) * height(s) * depth(s)
as_space_vector(s::Space) = [width(s), height(s), depth(s)]

mutable struct RelativeSpace
    space::Space
    offsetx::Float64
    offsety::Float64
    offsetz::Float64
end
@forward((RelativeSpace, :space), Space)
RelativeSpace(space::Vector{Float64}, x::FloatInt, y::FloatInt, z::FloatInt) = RelativeSpace(Space(space...), x, y, z)
RelativeSpace(w::FloatInt, h::FloatInt, d::FloatInt, x::FloatInt, y::FloatInt, z::FloatInt) = RelativeSpace(Space(w,h,d), x, y, z)
xoff(rs::RelativeSpace) = rs.offsetx
yoff(rs::RelativeSpace) = rs.offsety
zoff(rs::RelativeSpace) = rs.offsetz
xoff(rs::RelativeSpace, x::Float64) = rs.offsetx = x
yoff(rs::RelativeSpace, y::Float64) = rs.offsety = y
zoff(rs::RelativeSpace, z::Float64) = rs.offsetz = z

mutable struct BoxType
    space::Space
    stock::Int
    color::String
    open::Bool
    BoxType(space::Space, stock::Int, color::String) = new(space, stock, color, false)
end
BoxType(space::Vector{FloatInt}, stock::Int, color::String) = BoxType(Space(space...), stock, color)
BoxType(w::FloatInt, h::FloatInt, d::FloatInt, stock::Int, color::String) = BoxType(Space(w,h,d), stock, color)
@forward((BoxType, :space), Space)
stock(bt::BoxType) = bt.stock
stock(bt::BoxType, s::Int) = bt.stock = s
decrease_stock(bt::BoxType) = bt.stock -= 1
decrease_stock(bt::BoxType, q::Int) = bt.stock -= q
is_open(bt::BoxType) = bt.open
set_open(bt::BoxType, val::Bool) = bt.open = val
"""
Returns a tuple of rotated dimensions where the depth is the greatest dimension smaller than `k` (set to infinity by default). The width and height are the greatest and smallest of the remaining dimensions, respectively.
"""
rotated_primary_box_dims(bt::BoxType; k=Inf) = begin
    odims = as_space_vector(bt)
    d, i = map(x -> x > k ? 0 : x, as_space_vector(bt)) |> findmax
    println(map(x -> x > k ? 0 : x, as_space_vector(bt)))
    popat!(odims, i)
    w, i = findmax(odims)
    popat!(odims, i)
    h = odims[1]
    return (w,h,d)
end

BoxTypeList = Vector{BoxType}
function as_matrix(btl::BoxTypeList)
    B = Matrix{Float64}(undef, 0, 4)
    for b in btl
        B = vcat(B, [width(b) height(b) depth(b) stock(b)])
    end
    return B
end

mutable struct Box
    space::Space
    x::Float64
    y::Float64
    z::Float64
    color::String
end
Box(space::Vector{Float64}, x::FloatInt, y::FloatInt, z::FloatInt, color::String) = Box(Space(space...), x, y, z, color)
Box(w::FloatInt, h::FloatInt, d::FloatInt, x::FloatInt, y::FloatInt, z::FloatInt, color::String) = Box(Space(w, h, d), x, y, z, color)
@forward((Box, :space), Space)
xpos(b::Box) = b.x
ypos(b::Box) = b.y
zpos(b::Box) = b.z
xpos(b::Box, x::FloatInt) = b.x = x
ypos(b::Box, y::FloatInt) = b.y = y
zpos(b::Box, z::FloatInt) = b.z = z

BoxList = Vector{Box}

mutable struct Layer
    space::Space
    boxes::BoxList
    unfilled_secondary_spaces::Vector{RelativeSpace}
end
Layer(space::Vector{FloatInt}) = Layer(Space(space...), BoxList(), [])
Layer(w::FloatInt, h::FloatInt, d::FloatInt) = Layer(Space(w,h,d), BoxList(), [])
@forward((Layer, :space), Space)
used_volume(l::Layer) = isempty(boxes) ? 0 : sum(volume.(l.boxes))
unused_volume(l::Layer) = volume(l) - used_volume(l)
unfilled_spaces(l::Layer) = l.unfilled_secondary_spaces
push!(l::Layer, box::Box) = Base.push!(l.boxes, box)
push!(l::Layer, rs::RelativeSpace) = Base.push!(l.unfilled_secondary_spaces, rs)
push!(l::Layer, rs::Vector{RelativeSpace}) = Base.append!(l.unfilled_secondary_spaces, rs)

"""
Returns the box type and depth of a new layer in the wall-building procedure. If at least one of the available box types has been placed already, the placed box type with the largest remaining stock quantity is selected. Otherwise, this method chooses a box type according to the following order of ranking criteria:

1. Largest smallest dimension;
2. Largest stock quantity;
3. Largest largest dimension.

Once a box type has been selected, it is rotated so that its depth is the longest dimension smaller or equal to parameter K (which is infinite by default). Thus, the layer's depth is the selected box type's depth.
"""
function determine_new_layer_box_type(btl::BoxTypeList)
    isempty(btl) && error("box list is empty")
    local n
    ##### Ranking procedure
    O = findall(is_open, btl)
    if !isempty(O)
        B = as_matrix(btl[O])
        n = findmax(B[:,4])
    else
        B = as_matrix(btl)
        Min = mapslices(minimum, B[:,1:3], dims=2) |> vec
        Max = mapslices(maximum, B[:,1:3], dims=2) |> vec
        #first ranking: indices of item types with the maximum smallest dimension
        Imaxd = findall(Min[i] == maximum(Min) for i in eachindex(Min))
        #second ranking: indices of item types with the maximum stock quantity
        Imaxq = findall(i in Imaxd && B[i,4] == maximum(B[Imaxd,4]) for i in eachindex(B[:,1]))
        #third ranking: maximum biggest dimension among tied items
        n = findfirst(i in Imaxq && Max[i] == maximum(Max[Imaxq]) for i in eachindex(Max))
    end
    return n
end

"""
Creates a new layer, fills it with its primary item and returns it.
"""
function create_new_layer(w::FloatInt, h::FloatInt, btl::BoxTypeList; k=Inf)
    i = determine_new_layer_box_type(btl)
    isnothing(i) && return nothing
    boxw, boxh, boxd = rotated_primary_box_dims(btl[i], k=k)
    l = Layer(w, h, boxd)
    x, y = 0., 0.
    bt = btl[i]
    while y + boxh ≤ height(l)
        if x + boxw ≤ width(l)
            stock(bt) > 0 ? decrease_stock(bt) : break
            box = Box(boxw, boxh, boxd, x, y, 0, bt.color)
            push!(l, box)
            x += boxw
        else
            x = 0.
            y += boxh
        end
    end
    push!(l, get_secondary_spaces(l))
    return l
end

"""
Returns the width, height and depth of the stack of boxes used to fill a layer for the first time.
"""
function get_first_fill_dims(l::Layer)
    isempty(l.boxes) && error("layer has no boxes")
    box = first(l.boxes)
    nhor, nver = floor.([width(l)/width(box), height(l)/height(box)])
    return nhor * width(box), nver * height(box), depth(box);
end

"""
Returns the spaces in a layer that are not filled by any boxes. The first space is the one to the right of the primary filling, the second is the one on top.
"""
function get_secondary_spaces(l::Layer)::Vector{RelativeSpace}
    usedw, usedh, usedd = get_first_fill_dims(l)
    w, h = width(l) - usedw, height(l) - usedh
    return [RelativeSpace(w, height(l) - h, usedd, usedw, 0, 0),
            RelativeSpace(width(l), h, usedd, 0, usedh, 0)]
end

"""
Finds box rotations with nonzero stock that fit into a space. Returns a vector of tuples containing the permutation and the index of the box type.
"""
function find_secondary_box_rotations(btl::BoxTypeList, space::Space)::Vector{Tuple{Vector{Float64}, Int}}
    local fitting_rotations
    for (i, bt) in enumerate(btl), p in as_space_vector(bt) |> permutations
        stock(bt) > 0 && all(p .≤ as_space_vector(space)) && push!(fitting_rotations, (p, i))
    end
    return fitting_rotations
end

"""
From a list of fitting box rotations, filters those that may be horizontally placed as multiple columns.
"""
function filter_multicolumn_box_rotations(rotations::Vector{Tuple{Vector{Float64}, Int}}, space::Space)
    return filter(x -> x[1][1] ≤ width(space) / 2, rotations)
end

"""
Selects the box rotation that will best fill a layer's remaining space, returning a vector with the permutated dimensions and the index to the box type. If no box fits the space, returns nothing.
"""
function select_secondary_box_rotation(fitting_rotations::Vector{Tuple{Vector{Float64}, Int}})
    isempty(fitting_rotations) && return nothing
    multicolumn_rotations = filter_multicolumn_box_rotations(fitting_rotations, space)
    local n, rotation
    if isempty(multicolumn_rotations)
        A = repeat(area(space, :wd), length(fitting_rotations)) .- map(x->x[1]*x[3], fitting_rotations)
        n = findmin(A)
    else
        _, n = findmax([rotation[1][3] for rotation in fitting_rotations])
    end
    return select_secondary_box_cross_sectional_rotation(btl, space, fitting_rotations[n]...)
end

"""
Determines whether or not a box is rotated width-height-wise depending on spatial conditions and stock quantities. The idea is to either prioritize filling as much horizontal or vertical space as possible.
"""
function select_secondary_box_cross_sectional_rotation(btl::BoxTypeList, space::Space, dims::Vector{Float64}, i::Int)
    w, h = 1, 2
    #verifies if the box can be rotated width-height-wise; if not, select the current rotation
    if dims[h] ≤ width(space) && dims[w] ≤ height(space)
        #max boxes to fill a column under a certain rotation
        max_col_boxes_original = height(space) % dims[h]
        max_col_boxes_rotated = height(space) % dims[w]
        col_height_original = max_col_boxes_original * dims[h]
        col_height_rotated = max_col_boxes_rotated * dims[w]
        #if there isn't enough stock to complete a column with either rotation, fill as much widthwise space as possible; otherwise, fill as much heightwise space as possible
        if stock(btl[i]) ≤ max_col_boxes_original && stock(btl[i]) ≤ max_col_boxes_rotated
            if dims[h] > dims[w]
                dims[w], dims[h] = dims[h], dims[w]
            end
        else
            if col_height_rotated > col_height_original
                dims[w], dims[h] = dims[h], dims[w]
            end
        end
    end
    return dims, i
end

"""
Selects a secondary box to fill a layer. Returns a box object and the box type index.
"""
function select_secondary_box(btl::BoxTypeList, space::RelativeSpace)
    fitting_rotations = find_secondary_box_rotations(btl, space)
    dims, i = select_secondary_box_rotation(fitting_rotations)
    return Box(dims..., 0, 0, zoff(space), btl[i].color), i
end

"""
Returns the amalgamated space and the flexible width between a space and any unused space in the previous layer.
"""
function amalgamate(space::RelativeSpace, prev_spaces::Vector{RelativeSpace})
    #Filters previous spaces. Only those appropriate heightwise and widthwise are considered.
    prev = filter(rs::RelativeSpace -> yoff(rs) ≤ height(space), prev_spaces)
    filter!(rs::RelativeSpace -> 
            (xoff(rs) ≥ xoff(space) && xoff(rs) < xoff(space) + width(space)) ||
            (xoff(rs) + width(rs) ≤ xoff(space) + width(space) && xoff(rs) + width(rs) > xoff(space)) ||
            (xoff(rs) ≤ xoff(space) && xoff(rs) + width(rs) ≥ xoff(space) + width(space)), prev)
    isempty(prev) && return RelativeSpace(0, 0, 0, 0, 0, 0), Inf
    sort!(prev, by = rs::RelativeSpace -> xoff(rs))
    leftmost_prev_x, leftmost = findmin([xoff(rs) for rs in prev])
    rightmost_prev_x, _ = findmax([xoff(rs) + width(rs) for rs in prev])
    #Finds the first unused space whose depth differs from the ones before.
    j = findfirst(>(0), [depth(prev[i]) - depth(prev[i-1]) for i = range(2, length(prev))]) + 1
    xleft = max(leftmost_prev_x, xoff(space))
    xright = min(rightmost_prev_x, xoff(space) + width(space))
    flexible_width = xoff(prev[j]) - xleft
    return RelativeSpace(xright - xleft, height(space), depth(prev[leftmost]) + depth(space), xleft, yoff(space), depth(prev[leftmost])), flexible_width
end

"""
Fills a single column. Returns the x coordinate at which the column ends.
"""
function fill_column(l::Layer, b::Box, bt::BoxType, x::FloatInt, ystart::FloatInt)
    x + width(b) > width(l) && return x
    y = ystart
    while y + height(b) ≤ height(l) && stock(bt) > 0
        decrease_stock(bt)
        b = copy(box)
        xpos(b, x)
        ypos(b, y)
        push!(l, b)
        y += height(b)
    end
    push!(l, RelativeSpace(width(b), height(b), depth(l) - (zpos(b) + depth(b)), xpos(b), ystart, zpos(b) + depth(b)))
    return x + width(b)
end

"""
Fills as many columns as possible with a given item. Parameter `flexible_boundary` defines the x coordinate of the end of the flexible width. Returns the x coordinate at which the stack of columns ends.
"""
function fill_columns(l::Layer, b::Box, bt::BoxType, xstart::FloatInt, ystart::FloatInt, flexible_boundary::FloatInt)
    x, y = xstart, ystart
    flexible_boundary_reached = false
    while stock(bt) > 0 && !flexible_boundary_reached && x + width(b) < width(l)
        flexible_boundary_reached = x + width(b) > flexible_boundary
        x = fill_column(l, b, bt, x, y)
        y = ystart
    end
    return x
end

"""
Fills the possible remaining spaces in a layer with secondary boxes.
"""
function second_fill_layer(l::Layer, prev_l::Layer, btl::BoxTypeList)
    secondary_spaces = unfilled_spaces(l)
    for space in secondary_spaces
        if volume(space) > 0
            local horizontal_packing_limit
            amalgamation, flexible_width = amalgamate(space, unfilled_spaces(prev_l))
            flexible_boundary = xoff(amalgamation) + flexible_width
            box, i = select_secondary_box(btl, space)
            boxes_per_column = height(space) / height(box) |> floor
            if stock(btl[i]) ≥ boxes_per_column
                horizontal_packing_limit = fill_columns(l, box, btl[i], xoff(space), yoff(space), flexible_boundary)
            else
                horizontal_packing_limit = fill_columns(l, box, btl[i], xoff(space), yoff(space), flexible_boundary)
            end
            if flexible_width != Inf
                if horizontal_packing_limit > xoff(amalgamation)
                    new_width = xoff(amalgamation) + width(amalgamation) - horizontal_packing_limit
                    xoff(amalgamation, horizontal_packing_limit)
                    width(amalgamation, new_width)
                end
                box, i = select_secondary_box(btl, amalgamation)
                fill_columns(prev_l, box, btl[i], xoff(amalgamation), yoff(amalgamation), Inf)
            end
        end
    end
end

function as_tikz(l::Layer, filename::String; grid="major")
    out = open(filename, "w")
    write(out, "\\begin{tikzpicture}")
    write(out, "\n\t")
    write(out, "\\begin{axis}[xmin=0, xmax=$(width(l)), ymin=0, ymax=$(height(l)), grid=$grid]")
    write(out, "\n")
    for box in l.boxes
        write(out, "\t\t")
        write(out, "\\filldraw[draw=black,fill=$(box.color)] (axis cs:$(xpos(box)),$(ypos(box))) rectangle (axis cs:$(xpos(box)+width(box)),$(ypos(box)+height(box)));")
        write(out, "\n")
    end
    write(out, "\t")
    write(out, "\\end{axis}")
    write(out, "\n")
    write(out, "\\end{tikzpicture}")
    close(out)
end

function wall_building(container_dims::Vector{Float64}, box_type_list::BoxTypeList)
    W, H, D = container_dims
    layer_z = 0
    layer_list = Vector{Layer}()
    remaining_depth = D
    while remaining_depth > 0
        layer = create_new_layer(W, H, box_type_list, k=remaining_depth)
        isnothing(layer) && break
        push!(layer_list, layer)
        layer_z += depth(layer)
        remaining_depth = D - layer_z
    end
    return layer_list
end

##

l = Layer(22,22,22)
btl = [BoxType(1,2,3,4,"rgb(0,0,180)"), BoxType(5,6,7,8,"rgb(180,0,0)")]
i = determine_new_layer_box_type(btl)
first_fill_layer(l, btl, i)