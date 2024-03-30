"""
Produces a tikz representation of a layer within the specified container.
"""
function layer_as_tikz(db::Database, node::ContainerNode, layer_id, filename, item_colors; grid="major", view=:front)
    layer = node.layers[layer_id,:]
    spaces = filter(row -> row[:layer] == layer_id, node.spaces)
    container = db.containers[node.container_id,:]
    out = open(filename, "w")
    write(out, "\\begin{tikzpicture}")
    write(out, "\n\t")
    if view == :front
        write(out, "\\begin{axis}[axis equal image, xmin=0, xmax=$(container[:width]), ymin=0, ymax=$(container[:height]), grid=$grid]")
    elseif view == :top
        write(out, "\\begin{axis}[axis equal image, xmin=0, xmax=$(container[:width]), ymin=0, ymax=$(layer[:depth]), grid=$grid]")
    end
    write(out, "\n")
    for space in eachrow(spaces)
        placements = filter(row -> row[:space] == space[:id], node.placements)
        for placement in eachrow(placements)
            pattern = ""
            if node.spaces[placement[:space],:type] == :amalgam || node.spaces[placement[:space],:from_amalgam]
                pattern = "crosshatch"
            end
            for n in 0:placement[:quantity]-1
                item = db.items[placement[:item],:]
                write(out, "\t\t")
                if view == :front
                    write(out, "\\filldraw[draw=black,fill=$(item_colors[item[:id]]),pattern=$pattern,pattern color=$(item_colors[item[:id]])] (axis cs:$(placement[:x]),$(placement[:y] + n * placement[:height])) rectangle (axis cs:$(placement[:x] + placement[:width]),$(placement[:y] + (n + 1) * placement[:height]));")
                elseif view == :top
                    write(out, "\\filldraw[draw=black,fill=$(item_colors[item[:id]]),pattern=$pattern,pattern color=$(item_colors[item[:id]])](axis cs:$(placement[:x]),$(placement[:z] - layer[:z])) rectangle (axis cs:$(placement[:x] + placement[:width]),$(placement[:z] + placement[:depth] - layer[:z]));")
                    break
                end
                write(out, "\n")
            end
        end
    end
    write(out, "\t")
    write(out, "\\end{axis}")
    write(out, "\n")
    write(out, "\\end{tikzpicture}")
    close(out)
end

"""
Produces a tikz representation of a layer within the specified container.
"""
function container_as_tikz(db::Database, node::ContainerNode, path, item_colors; grid="major", view=:front)
    if !isdir(path)
        mkpath(path)
    end
    for layer in eachrow(node.layers)
        full_path = joinpath(path, "l$(layer[:id]).tex")
        layer_as_tikz(db, node, layer[:id], full_path, item_colors, grid=grid, view=view)
    end
end

"""
Produces a tikz representation of all the containers in container sequence.
"""
function solution_as_tikz(db::Database, root_node, container_sequence, path, item_colors; grid="major", view=:front)
    i = 1
    while i <= length(container_sequence)
        node = get_node(root_node, first(container_sequence, i))
        container_path = joinpath(path, "c$i")
        container_as_tikz(db, node, container_path, item_colors, grid=grid, view=view)
        i += 1
    end
end