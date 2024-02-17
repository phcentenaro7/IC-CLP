using JuMP
using Gurobi
using Plotly
using PlotlyJS

mutable struct CLPItem
    length::Float64
    width::Float64
    height::Float64
    color::String
end

Container = CLPItem

function add_clp_items(item::CLPItem, item_list::Vector{CLPItem}, quantity::Int)
    append!(item_list, repeat([item], quantity))
end

add_clp_items(item::Vector, item_list::Vector{CLPItem}, quantity::Int) = add_clp_items(CLPItem(item...), item_list, quantity)

add_containers(container::Container, container_list::Vector{Container}, quantity::Int) = add_clp_items(container, container_list, quantity)

add_containers(container::Vector{Float64}, container_list::Vector{Container}, quantity::Int) = add_clp_items(Container(container..., "rgb(0,0,0)"), container_list, quantity)

get_container_volume(container::Container) = container.width * container.height * container.length

function create_clp_model(container_list::Vector{Container}, item_list::Vector{CLPItem})
    N = length(item_list)
    m = length(container_list)
    M = max(map(get_container_volume, container_list)...)
    p = [item.length for item in item_list]
    q = [item.width for item in item_list]
    r = [item.height for item in item_list]
    L = [container.length for container in container_list]
    W = [container.width for container in container_list]
    H = [container.height for container in container_list]
    model = Model()
    @variables(model, begin
        s[1:N,1:m], Bin
        n[1:m], Bin
        x[1:N] ≥ 0
        y[1:N] ≥ 0
        z[1:N] ≥ 0
        lx[1:N], Bin
        ly[1:N], Bin
        lz[1:N], Bin
        wx[1:N], Bin
        wy[1:N], Bin
        wz[1:N], Bin
        hx[1:N], Bin
        hy[1:N], Bin
        hz[1:N], Bin
        a[1:N,1:N], Bin
        b[1:N,1:N], Bin
        c[1:N,1:N], Bin
        d[1:N,1:N], Bin
        e[1:N,1:N], Bin
        f[1:N,1:N], Bin
    end)
    @objective(model, Min, sum(L[j] * W[j] * H[j] * n[j] for j ∈ 1:m) - sum(p[i] * q[i] * r[i] for i ∈ 1:N))
    @constraints(model, begin
        #=(1')=# left[i=1:N,k=1:N;i<k], x[i] + p[i] * lx[i] + q[i] * (lz[i] - wy[i] + hz[i]) + r[i] * (1 - lx[i] - lz[i] + wy[i] - hz[i]) ≤ x[k] + (1 - a[i,k]) * M
        #=(2')=# right[i=1:N,k=1:N;i<k], x[k] + p[k] * lx[k] + q[k] * (lz[k] - wy[k] + hz[k]) + r[k] * (1 - lx[k] - lz[k] + wy[k] - hz[k]) ≤ x[i] + (1 - b[i,k]) * M
        #=(3')=# behind[i=1:N,k=1:N;i<k], y[i] + q[i] * wy[i] + p[i] * (1 - lx[i] - lz[i]) + r[i] * (lx[i] + lz[i] - wy[i]) ≤ y[k] + (1 - c[i,k]) * M
        #=(4')=# front[i=1:N,k=1:N;i<k], y[k] + q[k] * wy[k] + p[k] * (1 - lx[k] - lz[k]) + r[k] * (lx[k] + lz[k] - wy[k]) ≤ y[i] + (1 - d[i,k]) * M
        #=(5')=# below[i=1:N,k=1:N;i<k], z[i] + r[i] * hz[i] + q[i] * (1 - lz[i] - hz[i]) + p[i] * lz[i] ≤ z[k] + (1 - e[i,k]) * M
        #=(6')=# above[i=1:N,k=1:N;i<k], z[k] + r[k] * hz[k] + q[k] * (1 - lz[k] - hz[k]) + p[k] * lz[k] ≤ z[i] + (1 - f[i,k]) * M
        #=binary=# [i=1:N], lx[i] + ly[i] + lz[i] == 1
        #=binary=# [i=1:N], wx[i] + wy[i] + wz[i] == 1
        #=binary=# [i=1:N], hx[i] + hy[i] + hz[i] == 1
        #=binary=# [i=1:N], lx[i] + wx[i] + hx[i] == 1
        #=binary=# [i=1:N], ly[i] + wy[i] + hy[i] == 1
        #=binary=# [i=1:N], lz[i] + wz[i] + hz[i] == 1
        #=(7)=# [i=1:N,k = 1:N,j=1:m;i < k], a[i,k] + b[i,k] + c[i,k] + d[i,k] + e[i,k] + f[i,k] ≥ s[i,j] + s[k,j] - 1
        #=(8)=# [i=1:N], sum(s[i,j] for j ∈ 1:m) == 1
        #=(9)=# [i=1:N,j=1:m], sum(s[i,j] for i ∈ 1:N) ≤ M * n[j]
        #=(10')=# [i=1:N,j=1:m], x[i] + p[i] * lx[i] + q[i] * (lz[i] - wy[i] + hz[i]) + r[i] * (1 - lx[i] - lz[i] + wy[i] - hz[i]) ≤ L[j] + (1 - s[i,j]) * M
        #=(11')=# [i=1:N,j=1:m], y[i] + q[i] * wy[i] + p[i] * (1 - lx[i] - lz[i]) + r[i] * (lx[i] + lz[i] - wy[i]) ≤ W[j] + (1 - s[i,j]) * M
        #=(12')=# [i=1:N,j=1:m], z[i] + r[i] * hz[i] + q[i] * (1 - lz[i] - hz[i]) + p[i] * lz[i] ≤ H[j] + (1 - s[i,j]) * M
        #=(A)=# [j=1:m], sum(p[i] * q[i] * r[i] * s[i,j] for i ∈ 1:N) ≤ W[j] * H[j] * L[j]
    end)
    return model
end

function create_box_mesh(origins::Tuple, dimensions::Tuple, color)::GenericTrace{Dict{Symbol, Any}}
    x, y, z = origins
    w, h, d = dimensions
    vertex_i = [0b000, 0b110, 0b001, 0b111, 0b000, 0b101, 0b010, 0b111, 0b000, 0b011, 0b100, 0b111]
    vertex_j = [0b100, 0b100, 0b101, 0b101, 0b001, 0b001, 0b011, 0b011, 0b010, 0b010, 0b110, 0b110]
    vertex_k = [0b010, 0b010, 0b011, 0b011, 0b100, 0b100, 0b110, 0b110, 0b001, 0b001, 0b101, 0b101]
    return Plotly.mesh3d(x = repeat([x, x + w], inner=4),
                  y = repeat([y, y + h], inner=2, outer=2),
                  z = repeat([z, z + d], 4),
                  i = vertex_i,
                  j = vertex_j,
                  k = vertex_k,
                  facecolor = repeat([color], 12),
                  hoverlabel = (bgcolor="black", fontsize=16),
                  hoverinfo = "name",
                  opacity = 1)
end

function create_box_outline_vector(origins::Tuple, dimensions::Tuple, color)::Vector{GenericTrace{Dict{Symbol, Any}}}
    x, y, z = origins
    w, h, d = dimensions
    outlines::Vector{GenericTrace} = []
    push!(outlines, Plotly.scatter3d(x=[x, x], y=[y, y], z=[z, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x, x], y=[y, y + h], z=[z, z], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x, x + w], y=[y, y], z=[z, z], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x + w, x + w], y=[y + h, y + h], z=[z, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x + w, x + w], y=[y, y + h], z=[z + d, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x, x + w], y=[y + h, y + h], z=[z + d, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x + w, x + w], y=[y, y], z=[z, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x, x], y=[y + h, y + h], z=[z, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x + w, x + w], y=[y, y + h], z=[z, z], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x, x], y=[y, y + h], z=[z + d, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x, x + w], y=[y, y], z=[z + d, z + d], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    push!(outlines, Plotly.scatter3d(x=[x, x + w], y=[y + h, y + h], z=[z, z], hoverinfo="none", mode="lines", name="", showlegend=false, line=(color=color, width=5)))
    return outlines
end

function visualize_container(container_number::Int, container_list::Vector{Container}, item_list::Vector{CLPItem}, solution::GenericModel)
    if value(solution[:n][container_number]) == 0
        return nothing
    end
    drawables = meshes = outlines = Vector{GenericTrace}()
    for (i, s) in enumerate(value.(solution[:s][:,container_number]))
        if s == 1
            x, y, z = [value(solution[k][i]) for k in [:x, :y, :z]]
            item = item_list[i]
            lx, lz, wy, hz = [value(solution[k][i]) for k in [:lx, :lz, :wy, :hz]]
            orientation = []
            if lx == 1
                if wy == 1
                    orientation = [item.length, item.width, item.height]
                else
                    orientation = [item.length, item.height, item.width]
                end
            elseif lz == 1
                if wy == 1
                    orientation = [item.height, item.width, item.length]
                else
                    orientation = [item.width, item.height, item.length]
                end
            else
                if hz == 1
                    orientation = [item.width, item.length, item.height]
                else
                    orientation = [item.height, item.length, item.width]
                end
            end
            push!(meshes, create_box_mesh((x, y, z), Tuple(orientation), item.color))
            append!(outlines, create_box_outline_vector((x, y, z), Tuple(orientation), "rgb(0,0,0)"))
        end
    end
    append!(drawables, meshes)
    append!(drawables, outlines)
    return Plotly.plot(drawables, Layout(scene=attr(
        xaxis=attr(title="length", #=range=[0,W + 1],=#),
        yaxis=attr(title="width"#=, range=[0,D + 1]=#),
        zaxis=attr(title="height"#=, range=[0,H + 1]=#))))
end

# item_list = Vector{CLPItem}()
# add_clp_items([2., 4, 5, "rgb(255,0,0)"], item_list, 6)
# add_clp_items([6., 8, 4, "rgb(0,255,0)"], item_list, 2)
# add_clp_items([5., 10, 7, "rgb(0,0,255)"], item_list, 2)
# add_clp_items([2., 2, 2, "rgb(128,128,128)"], item_list, 4)
# add_clp_items([8., 9, 10, "rgb(255,255,0)"], item_list, 6)
# add_clp_items([12., 12, 12, "rgb(255,0,255)"], item_list, 1)
# add_clp_items([3., 7, 10, "rgb(0,255,255)"], item_list, 2)
# add_clp_items([4., 8, 6, "rgb(255,255,255)"], item_list, 3)
# container_list = Vector{Container}()
# add_containers([20., 20, 20], container_list, 2)
# model = create_clp_model(container_list, item_list)
# set_optimizer(model, Gurobi.Optimizer)
# optimize!(model)

# item_list = Vector{CLPItem}()
# add_clp_items([.43, .32, .27, "rgb(255,0,0)"], item_list, 124)
# add_clp_items([.40, .50, .40, "rgb(0,255,0)"], item_list, 122)
# add_clp_items([.60, .40, .50, "rgb(0,0,255)"], item_list, 1383)
# container_list = Vector{Container}()
# add_containers([14, 2.6, 4.4], container_list, 20)
# model = create_clp_model(container_list, item_list)
# set_optimizer(model, Gurobi.Optimizer)
# optimize!(model)