mutable struct KnapsackProblem
    container_dims::Vector{Float64}
    items::Vector{ItemInfo}
    KnapsackProblem(container_dims, items) = begin
        ndims = length(container_dims)
        append!(container_dims, zeros(3 - ndims))
        new(container_dims, items)
    end
end

mutable struct KnapsackVectors
    W::Float64
    H::Float64
    D::Float64
    x::Vector{Float64}
    y::Vector{Float64}
    z::Vector{Float64}
    w::Vector{Float64}
    h::Vector{Float64}
    d::Vector{Float64}
    values::Vector{Float64}
    colors::Vector
    in_container::Vector{Bool}
    type::Vector{Float64}
    KnapsackVectors(W, H, D, w, h, d, values, colors) = begin
        n = length(W)
        new(W, H, D, zeros(n), zeros(n), zeros(n), w, h, d, values, colors, repeat([false], n), collect(1:n))
    end
    KnapsackVectors(knapsack::KnapsackProblem) = begin
        w, h, d, v, c, t = [], [], [], [], [], []
        for (i, item) in enumerate(knapsack.items)
            append!(w, repeat([item.width], item.available))
            append!(h, repeat([item.height], item.available))
            append!(d, repeat([item.depth], item.available))
            append!(v, repeat([item.value], item.available))
            append!(c, repeat([item.color], item.available))
            append!(t, repeat([i], item.available))
        end
        n = length(w)
        new(knapsack.container_dims..., zeros(n), zeros(n), zeros(n), w, h, d, v, c, repeat([false], n), t)
    end
    KnapsackVectors(knapsack::KnapsackProblem, model::GenericModel) = begin
        w, h, d, v, c, t = [], [], [], [], [], []
        x, y, z = [value.(model[k]) for k in [:x, :y, :z]]
        s = value.(model[:s])
        for (i, item) in enumerate(knapsack.items)
            append!(w, repeat([item.width], item.available))
            append!(h, repeat([item.height], item.available))
            append!(d, repeat([item.depth], item.available))
            append!(v, repeat([item.value], item.available))
            append!(c, repeat([item.color], item.available))
            append!(t, repeat([i], item.available))
        end
        new(knapsack.container_dims..., x, y, z, w, h, d, v, c, s, t)
    end
end

kv_cdims(kv::KnapsackVectors) = (kv.W, kv.H, kv.D)
kv_pos(kv::KnapsackVectors) = (kv.x, kv.y, kv.z)
kv_dims(kv::KnapsackVectors) = (kv.w, kv.h, kv.d)