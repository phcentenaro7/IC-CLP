using JuMP
using Gurobi
using Plots
using Combinatorics

const nr = not_rotated = 1
const r = rotated = rotations = 2
const dimx = 1
const dimy = dims = 2

struct ItemInfoContinuous2D
    width::Float32
    height::Float32
    available::Int
    value::Float32
end

function get_decision_matrix_ranges(items::Vector{ItemInfoContinuous2D})
    k = length(items)
    n, _ = findmax([item.available for item in items])
    return 1:k, 1:n
end

function create_item_set(items::Vector{ItemInfoContinuous2D})
    return [(k, n) for k in 1:length(items) for n in 1:items[k].available]
end

function create_width_height_matrix(items::Vector{ItemInfoContinuous2D})
    k₀ = length(items)
    wh = Array{Float32}(undef, k₀, 2, dims)
    for k ∈ 1:k₀
        wh[k, nr, dimx] = wh[k, r, dimy] = items[k].width
        wh[k, nr, dimy] = wh[k, r, dimx] = items[k].height
    end
    return wh
end

function jump_2dknapsack_continuous(container_dims::Vector{T}, items::Vector{ItemInfoContinuous2D}; optimizer=Gurobi.Optimizer, max_solve_time::Int=90) where {T <: Real}
    k₀, n₀ = get_decision_matrix_ranges(items)
    kn = create_item_set(items)
    C = collect(combinations(kn, 2))
    wh = create_width_height_matrix(items)
    v = [item.value for item in items]
    q = [item.available for item in items]
    M = prod(container_dims)
    model = Model(optimizer)
    @variable(model, x[k₀, n₀], Bin)
    @variable(model, rot[k₀, n₀], Bin)
    @variable(model, p₀[k₀, n₀, 1:dims] ≥ 0)
    @variable(model, p₁[k₀, n₀, 1:dims] ≥ 0)
    @variable(model, δ[k₀, n₀, k₀, n₀, 1:dims, 1:2], Bin)
    @objective(model, Max, sum(v[k] * x[k, n] for k ∈ k₀, n ∈ n₀ if (k, n) ∈ kn))
    @constraint(model, [k ∈ k₀, n ∈ n₀, xy ∈ 1:2], p₁[k, n, xy] <= container_dims[xy])
    @constraint(model, [(k, n) ∈ kn, xy ∈ 1:2], p₁[k, n, xy] == p₀[k, n, xy] + wh[k, r, xy] * rot[k, n] + wh[k, nr, xy] * (1 - rot[k, n]))
    @constraint(model, [k ∈ k₀, n ∈ n₀, k′ ∈ k₀, n′ ∈ n₀; [(k, n), (k′, n′)] ∈ C], sum(δ[k, n, k′, n′, xy, 1] + δ[k, n, k′, n′, xy, 2] for xy ∈ 1:2) ≥ 1)
    @constraint(model, [xy ∈ 1:2, c ∈ C, k = c[1][1], n = c[1][2], k′ = c[2][1], n′ = c[2][2]], p₀[k, n, xy] ≥ p₁[k′, n′, xy] - M * (3 - δ[k, n, k′, n′, xy, 1] - x[k, n] - x[k′, n′]))
    @constraint(model, [xy ∈ 1:2, c ∈ C, k = c[1][1], n = c[1][2], k′ = c[2][1], n′ = c[2][2]], p₀[k′, n′, xy] ≥ p₁[k, n, xy] - M * (3 - δ[k, n, k′, n′, xy, 2] - x[k, n] - x[k′, n′]))
    set_time_limit_sec(model, max_solve_time) 
    optimize!(model)
    return model
end

function draw_continuous_model_solution(container_dims::Vector{T}, items::Vector{ItemInfoContinuous2D}, model) where {T <: Real}
    x = Array(round.(value.(model[:x])))
    p₀ = Array(round.(value.(model[:p₀]))) 
    rot = Array(round.(value.(model[:rot]))) 
    p = plot(xlims=[1, container_dims[1] + 1], xticks=0:container_dims[1]/10:container_dims[1],
            ylims=[1, container_dims[2] + 1], yticks=0:container_dims[2]/10:container_dims[2])
    indices = sort(findall(isone, x), by=x->x[1])
    rectangle(w, h, x, y) = Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])
    prev_k = 0
    for index in indices
        k, n = Tuple(index)
        prim = prev_k == k ? false : true
        if rot[k, n] == 0
            plot!(p, rectangle(items[k].width, items[k].height, p₀[k, n, 1], p₀[k, n, 2]), label="item $k", primary=prim)
        else
            plot!(p, rectangle(items[k].height, items[k].width, p₀[k, n, 1], p₀[k, n, 2]), label="item $k", primary=prim)
        end
        prev_k = k
    end
    return p
end

##

container_dims = [30, 20]
items = [ItemInfoContinuous2D(8.4, 5.3, 4, 5),
         ItemInfoContinuous2D(6.2, 6.8, 3, 6),
         ItemInfoContinuous2D(4.9, 10, 4, 5.5),
         ItemInfoContinuous2D(13.7, 16.3, 2, 12),
         ItemInfoContinuous2D(5.1, 4.9, 6, 3)]
model = jump_2dknapsack_continuous(container_dims, items, max_solve_time=36000)
draw_continuous_model_solution(container_dims, items, model)