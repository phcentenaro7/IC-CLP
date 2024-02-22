using ReusePatterns
using Match

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
area(s::Space, plane::Symbol) = begin
    return @match plane begin
        :wh || :hw => width(s) * height(s)
        :wd || :dw => width(s) * depth(s)
        :hd || :dh => height(s) * depth(s)
    end
end
volume(s::Space) = width(s) * height(s) * depth(s)

mutable struct BoxType
    space::Space
    stock::Int
    open::Bool
    BoxType(space::Space, stock::Int) = new(space, stock, false)
end

BoxType(space::Vector{Float64}, stock::Int) = BoxType(Space(space...), stock)
stock(bt::BoxType) = bt.stock
is_open(bt::BoxType) = bt.open
set_open(bt::BoxType, val::Bool) = bt.open = val

@forward((BoxType, :space), Space)

BoxList = Vector{BoxType}
function as_matrix(bl::BoxList)
    B = Matrix{Float64}(undef, 0, 4)
    for b in bl
        B = vcat(B, [width(b) height(b) depth(b) stock(b)])
    end
    return B
end

"""
Determines the depth of a new layer in the wall-building procedure. If at least one of the available box types has been placed already, the placed box type with the largest remaining stock quantity is selected. Otherwise, this method chooses a box type according to the following order of ranking criteria:

1. Largest smallest dimension;
2. Largest stock quantity;
3. Largest largest dimension.

Once a box type has been selected, it is rotated so that its depth is the longest dimension smaller or equal to parameter K (which is infinite by default). Thus, the layer's depth is the selected box type's depth.
"""
function determine_new_layer_depth(bl::BoxList; k=Inf)
    isempty(bl) && error("box list is empty")
    n = Bs = j = nothing
    ##### Ranking procedure
    O = findall(is_open, bl)
    if !isempty(O)
        B = as_matrix(bl[O])
        n = findmax(B[:,4])
    else
        B = as_matrix(bl)
        Min = mapslices(minimum, B[:,1:3], dims=2) |> vec
        Max = mapslices(maximum, B[:,1:3], dims=2) |> vec
        #first ranking: indices of item types with the maximum smallest dimension
        Imaxd = findall(Min[i] == maximum(Min) for i in eachindex(Min))
        #second ranking: indices of item types with the maximum stock quantity
        Imaxq = findall(B[i,4] == maximum(B[Imaxd,4]) for i in eachindex(B[:,1]))
        #third ranking: maximum biggest dimension among tied items
        n = findfirst(Max[i] == maximum(Max[Imaxq]) for i in eachindex(Max))
    end
    ##### Depth selection
    Bs = sort(B[n,1:3], rev=true)
    j = findfirst(≤(k), Bs)
    return Bs[j]
end
