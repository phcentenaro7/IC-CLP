const CubeFaceVertices = Dict{Symbol, Vector{Int}}(
    :i => [0b000, 0b110, 0b001, 0b111, 0b000, 0b101, 0b010, 0b111, 0b000, 0b011, 0b100, 0b111],
    :j => [0b100, 0b100, 0b101, 0b101, 0b001, 0b001, 0b011, 0b011, 0b010, 0b010, 0b110, 0b110],
    :k => [0b010, 0b010, 0b011, 0b011, 0b100, 0b100, 0b110, 0b110, 0b001, 0b001, 0b101, 0b101]
)

function create_box_mesh(origins::Tuple, dimensions::Tuple, color)::GenericTrace{Dict{Symbol, Any}}
    x, y, z = origins
    w, h, d = dimensions
    return Plotly.mesh3d(x = repeat([x, x + w], inner=4),
                  y = repeat([y, y + h], inner=2, outer=2),
                  z = repeat([z, z + d], 4),
                  i = CubeFaceVertices[:i],
                  j = CubeFaceVertices[:j],
                  k = CubeFaceVertices[:k],
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

function draw_2d_knapsack_solution(kv::KnapsackVectors)
    s = kv.in_container
    n = length(s)
    x, y, _ = kv_pos(kv)
    W, H, _ = kv_cdims(kv)
    w, h, _ = kv_dims(kv)
    p = Plots.plot(xlims=[1, W + 1], xticks=0:W/10:W,
            ylims=[1, H + 1], yticks=0:H/10:H)
    rectangle(w, h, x, y) = Plots.Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])
    prim = true
    for i in 1:n
        if i > 1 && kv.type[i] != kv.type[i-1]
            prim = true
        end
        s[i] == 0 && continue
        Plots.plot!(p, rectangle(w[i], h[i], x[i], y[i]), label="item $j", primary=prim, fc=item.color)
        annotate!(x[i] + w[i]/2, y[i] + h[i]/2, text("$i", :black, :center, 8))
        prim = false
    end
    return p
end

function draw_3d_knapsack_solution(kv::KnapsackVectors)
    s = kv.in_container
    n = length(s)
    x, y, z = kv_pos(kv)
    w, h, d = kv_dims(kv)
    W, H, D = kv_cdims(kv)
    drawables = meshes = outlines = Vector{GenericTrace}()
    for i in 1:n
        !kv.in_container[i] && continue
        m = create_box_mesh((x[i], z[i], y[i]), (w[i], d[i], h[i]), kv.colors[i])
        m.name = "$i"
        push!(meshes, m)
        append!(outlines, create_box_outline_vector((x[i], z[i], y[i]), (w[i], d[i], h[i]), "rgb(0,0,0)"))
    end
    append!(drawables, meshes)
    append!(drawables, outlines)
    return Plotly.plot(drawables, Layout(scene=attr(
        aspectmode="data",
        xaxis=attr(title="width", #=range=[0,W + 1],=# autorange="reversed"),
        yaxis=attr(title="depth"#=, range=[0,D + 1]=#),
        zaxis=attr(title="height"#=, range=[0,H + 1]=#))))
end

function draw_knapsack_solution(kv::KnapsackVectors)
    return @match problem.container_dims[3] begin
        0 => draw_2d_knapsack_solution(kv)
        _ => draw_3d_knapsack_solution(kv)
    end
end