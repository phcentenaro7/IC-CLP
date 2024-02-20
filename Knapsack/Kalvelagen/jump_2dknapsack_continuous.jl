using JuMP
using Gurobi
using Plots
using Combinatorics

mutable struct ContinuousItem
    width::Float64
    height::Float64
    value::Float64
    color::String
end

add_items_to_list(item::ContinuousItem, item_list::Vector{ContinuousItem}, quantity::Int) = append!(item_list, repeat([item], quantity))

add_items_to_list(item::Vector, item_list::Vector{ContinuousItem}, quantity::Int) = add_items_to_list(ContinuousItem(item...), item_list, quantity)

function jump_2dknapsack_continuous(container_dims::Vector{T}, item_list::Vector{ContinuousItem}) where {T <: Real}
    n = length(item_list)
    W, H = container_dims
    w = [item.width for item in item_list]
    h = [item.height for item in item_list]
    v = [item.value for item in item_list]
    M = max(W, H)
    model = Model()
    @variables(model, begin
        s[1:n], Bin
        σ[1:n], Bin
        δ[1:n,1:n,1:4], Bin
        0 ≤ x[1:n] ≤ W
        0 ≤ x′[1:n] ≤ W
        0 ≤ y[1:n] ≤ H
        0 ≤ y′[1:n] ≤ H
    end)
    @objective(model, Max, sum(v[i]*s[i] for i ∈ 1:n))
    @constraints(model, begin
        [i ∈ 1:n], x′[i] == x[i] + (1 - σ[i]) * w[i] + σ[i] * h[i]
        [i ∈ 1:n], y′[i] == y[i] + σ[i] * w[i] + (1 - σ[i]) * h[i]
        [i ∈ 1:n, j ∈ 1:n; i < j], x′[i] - M * (3 - δ[i,j,1] - s[i] - s[j]) ≤ x[j]
        [i ∈ 1:n, j ∈ 1:n; i < j], x′[j] - M * (3 - δ[i,j,2] - s[i] - s[j]) ≤ x[i]
        [i ∈ 1:n, j ∈ 1:n; i < j], y′[i] - M * (3 - δ[i,j,3] - s[i] - s[j]) ≤ y[j]
        [i ∈ 1:n, j ∈ 1:n; i < j], y′[j] - M * (3 - δ[i,j,4] - s[i] - s[j]) ≤ y[i]
        [i ∈ 1:n, j ∈ 1:n; i < j], sum(δ[i,j,k] for k ∈ 1:4) ≥ 1
    end)
    return model
end

function draw_continuous_model_solution(container_dims::Vector{T}, items::Vector{ContinuousItem}, model) where {T <: Real}
    W, H = container_dims
    s = value.(model[:s])
    x = value.(model[:x])
    y = value.(model[:y])
    σ = value.(model[:σ]) 
    p = Plots.plot(xlims=[1, W + 1], xticks=0:W/10:W,
            ylims=[1, H + 1], yticks=0:H/10:H)
    indices = sort(findall(isone, s), by=s->s[1])
    rectangle(w, h, x, y) = Plots.Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])
    prim = true
    for (i, sᵢ) in enumerate(s)
        if i > 1 && items[i] == items[i-1]
            prim = false
        else
            prim = true
        end
        if σ == 0
            Plots.plot!(p, rectangle(items[i].width, items[i].height, x[i], y[i]), fillcolor = items[i].color, primary=prim, legend=false)
        else
            Plots.plot!(p, rectangle(items[i].height, items[i].width, y[i], x[i]), fillcolor = items[i].color, primary=prim, legend=false)
        end
    end
    return p
end

##

container_dims = [30, 20]
items = Vector{ContinuousItem}()
add_items_to_list([20., 4, 338.984, "rgb(255,0,0)"], items, 2)
add_items_to_list([12., 17, 849.246, "rgb(0,255,0)"], items, 6)
add_items_to_list([20., 12, 524.022, "rgb(0,0,155)"], items, 2)
add_items_to_list([16., 7, 263.303, "rgb(128,128,128)"], items, 9)
add_items_to_list([3., 6, 113.436, "rgb(255,255,0)"], items, 3)
add_items_to_list([13., 5, 551.072, "rgb(255,0,255)"], items, 3)
add_items_to_list([4., 7, 86.166, "rgb(0,255,255)"], items, 6)
add_items_to_list([6., 18, 755.094, "rgb(128,0,128)"], items, 8)
add_items_to_list([14., 2, 223.516, "rgb(128,128,0)"], items, 7)
add_items_to_list([9., 11, 369.56, "rgb(0,128,128)"], items, 5)
model = jump_2dknapsack_continuous(container_dims, items)
set_optimizer(model, Gurobi.Optimizer)
set_time_limit_sec(model, 90.)
optimize!(model)
draw_continuous_model_solution(container_dims, items, model)