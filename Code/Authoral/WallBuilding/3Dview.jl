using Plots
using Plotly
using Colors
using ColorSchemes

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

function rgb_as_string(rgb)
    return "rgb($(round(255*rgb.r)),$(round(255*rgb.g)),$(round(255*rgb.b)))"
end

function as_3Dview(db::Database, node::ContainerNode; colors=cgrad(:rainbow, nrow(db.items), categorical=true))
    drawables, meshes, outlines = Vector{GenericTrace}(), Vector{GenericTrace}(), Vector{GenericTrace}()
    for placement in eachrow(node.placements)
        x, y, z = placement[[:x, :y, :z]]
        w, d, h = collect(placement[[:width, :height, :depth]]) .* [1,placement[:quantity],1] 
        m = create_box_mesh((x, z, y), (w, h, d), colors[placement[:item]] |> rgb_as_string)
        m.name = "($(placement[:item]), $(Int(placement[:quantity])))"
        push!(meshes, m)
        append!(outlines, create_box_outline_vector((0, 0, 0), Tuple(collect(db.containers[node.container_id, [:width,:depth,:height]])), "rgb(0,0,0)"))
        # append!(outlines, create_box_outline_vector((x, z, y), (w, h, d), "rgb(0,0,0)"))
    end
    append!(drawables, meshes)
    append!(drawables, outlines)
    return Plotly.plot(drawables, Layout(scene=attr(
        #=aspectmode="data",=#
        xaxis=attr(title="x", #=range=[0,W + 1],=# autorange="reversed"),
        yaxis=attr(title="z"#=, range=[0,D + 1]=#),
        zaxis=attr(title="y"#=, range=[0,H + 1]=#))))
end