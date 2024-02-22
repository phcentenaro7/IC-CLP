mutable struct ItemInfo
    width::Float64
    height::Float64
    depth::Float64
    available::Int
    value::Float64
    color::String
    ItemInfo(width, height, depth, available, value, color) = begin
        new(width, height, depth, available, value, color)
    end
    ItemInfo(width, height, available, value, color) = begin
        new(width, height, 0, available, value, color)
    end
    ItemInfo(width, height, available, value; depth=0, color="rgb(128,128,128)") = begin
        new(width, height, depth, available, value, color)
    end
end