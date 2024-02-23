using ReusePatterns
using Match
using Combinatorics

"""
A union between Float64 and Int. Useful to allow both types as inputs to functions that require floats.
"""
FloatInt = Union{Float64, Int}

mutable struct Space
    w::Float64
    h::Float64
    d::Float64
    Space(w, h, d) = begin
        if w ≤ 0 || h ≤ 0 || d ≤ 0 
            error("cannot create space with nonnegative dimensions")
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
rotated_box_dims(bt::BoxType; k=Inf) = begin
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
end
Layer(space::Vector{FloatInt}) = Layer(Space(space...), BoxList())
Layer(w::FloatInt, h::FloatInt, d::FloatInt) = Layer(Space(w,h,d), BoxList())
@forward((Layer, :space), Space)
used_space(l::Layer) = isempty(boxes) ? 0 : sum(volume.(l.boxes))
unused_space(l::Layer) = volume(l) - used_space(l)
append!(l::Layer, box::Box) = Base.append!(l.boxes, [box])

"""
Returns the box type and depth of a new layer in the wall-building procedure. If at least one of the available box types has been placed already, the placed box type with the largest remaining stock quantity is selected. Otherwise, this method chooses a box type according to the following order of ranking criteria:

1. Largest smallest dimension;
2. Largest stock quantity;
3. Largest largest dimension.

Once a box type has been selected, it is rotated so that its depth is the longest dimension smaller or equal to parameter K (which is infinite by default). Thus, the layer's depth is the selected box type's depth.
"""
function determine_new_layer_box_type(btl::BoxTypeList)
    isempty(btl) && error("box list is empty")
    n = nothing
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
Tries to completely fill a layer with the item of index `i` in `btl`.
"""
function first_fill_layer(l::Layer, btl::BoxTypeList, i::Int; k=Inf)
    x, y = 0., 0.
    bt = btl[i]
    w, h, d = rotated_box_dims(bt, k=k)
    depth(l, d)
    while y + h ≤ height(l)
        if x + w ≤ width(l)
            stock(bt) > 0 ? decrease_stock(bt) : return
            box = Box(w, h, d, x, y, 0, bt.color)
            append!(l, box)
            x += w
        else
            x = 0.
            y += h
        end
    end
end

"""
Returns the width, height and depth of the stack of boxes used to fill a layer for the first time.
"""
function get_first_fill_dims(l::Layer)
    isempty(l.boxes) && error("layer has no boxes")
    box = first(l.boxes)
    nhor, nver = floor.([width(l)/width(box), height(l)/height(box)])
    return nhor * width(box), nver * height(box), depth(box) 
end

"""
Returns the spaces in a layer that are not filled by any boxes.
"""
function get_unfilled_spaces(l::Layer)
    spaces = []
    usedw, usedh, usedd = get_first_fill_dims(l)
    w, h = usedw - width(l), usedh - height(l)
    w > 0 && push!(spaces, Space(w, height(l) - h, depth(l)))
    h > 0 && push!(spaces, Space(width(l) - w, h, depth(l)))
    length(spaces) == 2 && push!(spaces, Space(w, h, depth(l)))
    return spaces
end

"""
Finds box rotations with nonzero stock that fit into a space. Returns a vector of tuples containing the permutation and the index of the box type.
"""
function find_fitting_box_rotations(btl::BoxTypeList, space::Space)::Vector{Tuple{Vector{Float64}, Int}}
    fitting_rotations = []
    for (i, bt) in enumerate(btl), p in as_space_vector(bt) |> permutations
        all(p .≤ as_space_vector(space)) && push!(fitting_rotations, (p, i))
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
function select_space_filling_box_rotation(btl::BoxTypeList, space::Space)
    fitting_rotations = find_fitting_box_rotations(btl, space)
    isempty(fitting_rotations) && return nothing
    multicolumn_rotations = filter_multicolumn_box_rotations(fitting_rotations, space)
    if isempty(multicolumn_rotations)
        A = repeat(area(space, :wd), length(fitting_rotations)) .- map(x->x[1]*x[3], fitting_rotations)
        n = findmin(A)
        return fitting_rotations[n]
    else
        
    end
end

function test_wb(cont_dims::Vector{Float64}, btl::BoxTypeList)
    n = determine_new_layer_box_type(btl)
    l = Layer(cont_dims...)
    first_fill_layer(l, btl, n)
    return l
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