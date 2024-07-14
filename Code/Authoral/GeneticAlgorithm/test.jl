import .GeneticAlgorithm as ga

db = ga.Database()  
ga.add_item!(db, [40, 40, 50], true, 122)
ga.add_item!(db, [27, 43, 32], true, 124)
ga.add_item!(db, [50, 60, 40], true, 1383)
ga.add_container!(db, [260,440,1400], 260*440*1400)
fitness = ga.solve_CLP(db, 50)
for item in eachrow(filter(row -> row[:status] == :filled, node.spaces))
    for other in eachrow(filter(row -> row[:id] != item[:id] && row[:status] == :filled, node.spaces))
        if(ga.do_spaces_overlap(node, item[:id], other[:id]))
            println("overlap ($(item[:id]), $(other[:id]))")
        end
    end
end
ga.as_3Dview(db, fitness, n=Inf)
