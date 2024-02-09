using JuMP
using Gurobi
using Plots

struct ItemInfoCovering2D
    width::Int
    height::Int
    available::Int
    value::Float32
end

#rotation constants for each item
const not_rotated = 1
const rotated = 2
const rotations = 2

"""
    Returns the following ranges based on the arguments:

        `k₀`: Range of numbered items;
        `r₀`: Range of possible rotations (defined by constant `rotations`);
        `i₀`: Range of cells per row;
        `j₀`: Range of cells per column.
"""
function get_2dknapsack_ranges(container_dims::Vector{Int}, items::Vector{ItemInfoCovering2D})
    k₀ = range(1, length(items))
    r₀ = range(1, rotations)
    i₀ = range(1, container_dims[1])
    j₀ = range(1, container_dims[2])
    return k₀, r₀, i₀, j₀
end

"""
    Creates arrays OK and COVER, both containing exclusively binary entries.
    
    OK indicates on which cells (i, j) the upper left corner of an item of type k and rotation r can be placed.
    
    COVER indicates which cells (i′, j′) are filled by an item of type k and rotation r whose upper left corner is placed on cell (i, j).
"""
function create_load_info_sets(container_dims::Vector{Int}, items::Vector{ItemInfoCovering2D})
    k₀, r₀, i₀, j₀ = get_2dknapsack_ranges(container_dims, items)
    OK = zeros(Int, k₀[end], r₀[end], i₀[end], j₀[end])
    COVER = zeros(Int, k₀[end], r₀[end], i₀[end], j₀[end], i₀[end], j₀[end])
    for k ∈ k₀, r ∈ r₀
        imax, jmax, dims = 0, 0, [items[k].width, items[k].height]
        width, height = r == rotated ? reverse(dims) : dims
        for i ∈ reverse(i₀)
            if i + width - 1 ≤ container_dims[1]
                imax = i
                break
            end
        end
        for j ∈ reverse(j₀)
            if j + height - 1 ≤ container_dims[2]
                jmax = j
                break
            end
        end
        for i ∈ 1:imax, j ∈ 1:jmax
            OK[k, r, i, j] = 1
            COVER[k, r, i, j, i:i+width-1, j:j+height-1] .= 1
        end
    end
    return OK, COVER
end

"""Solves the 2D knapsack problem using the covering model."""
function jump_2dknapsack_covering(container_dims::Vector{Int}, items::Vector{ItemInfoCovering2D}; optimizer=Gurobi.Optimizer, max_solve_time::Int=90)
    k₀, r₀, i₀, j₀ = get_2dknapsack_ranges(container_dims, items)
    v = [item.value for item in items]
    q = [item.available for item in items]
    OK, COVER = create_load_info_sets(container_dims, items)
    model = Model(optimizer)
    @variable(model, x[k₀, r₀, i₀, j₀], Bin)
    @objective(model, Max, sum(v[k] * x[k, r, i, j] for k ∈ k₀, r ∈ r₀, i ∈ i₀, j ∈ j₀ if OK[k, r, i, j] == 1))
    @constraint(model, [i′ ∈ i₀, j′ ∈ j₀], sum(x[k, r, i, j] for k ∈ k₀, r ∈ r₀, i ∈ i₀, j ∈ j₀ if COVER[k, r, i, j, i′, j′] == 1) ≤ 1)
    @constraint(model, [k ∈ k₀], sum(x[k, r, i, j] for r ∈ r₀, i ∈ i₀, j ∈ j₀ if OK[k, r, i, j] == 1) ≤ q[k])
    set_time_limit_sec(model, max_solve_time)
    optimize!(model)
    return model[:x]
end

"""Draws a covering model solution to the 2D knapsack problem."""
function draw_covering_model_solution(container_dims::Vector{Int}, items::Vector{ItemInfoCovering2D}, x)
    p = plot(xlims=[1, container_dims[1] + 1], xticks=0:container_dims[1],
            ylims=[1, container_dims[2] + 1], yticks=0:container_dims[2])
    indices = sort(findall(isone, x), by=x->x[1])
    rectangle(w, h, x, y) = Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])
    prev_k = 0
    for index in indices
        k, r, i, j = Tuple(index)
        prim = prev_k == k ? false : true
        if r == not_rotated
            plot!(p, rectangle(items[k].width, items[k].height, i, j), label="item $k", primary=prim)
        else
            plot!(p, rectangle(items[k].height, items[k].width, i, j), label="item $k", primary=prim)
        end
        prev_k = k
    end
    return p
end

##
container_dims = [30, 20]
items = [ItemInfoCovering2D(20, 4, 2, 338.984),
         ItemInfoCovering2D(12, 17, 6, 849.246),
         ItemInfoCovering2D(20, 12, 2, 524.022),
         ItemInfoCovering2D(16, 7, 9, 263.303),
         ItemInfoCovering2D(3, 6  , 3, 113.436),
         ItemInfoCovering2D(13, 5, 3, 551.076),
         ItemInfoCovering2D(4, 7, 6, 86.166),
         ItemInfoCovering2D(6, 18, 8, 755.094),
         ItemInfoCovering2D(14, 2, 7, 223.516),
         ItemInfoCovering2D(9, 11, 5, 369.560)]
x = jump_2dknapsack_covering(container_dims, items, max_solve_time=60);
x = Array(Int.(value.(x)))
draw_covering_model_solution(container_dims, items, x)