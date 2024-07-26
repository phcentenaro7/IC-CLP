include("ga.jl")
import .GeneticAlgorithm as ga

ga.logging_on()
db = ga.Database()  
ga.add_item!(db, [40, 40, 50], true, 1000)
ga.add_item!(db, [27, 43, 32], true, 1000)
ga.add_item!(db, [50, 60, 40], true, 1000)
ga.add_container!(db, [260,440,1400], 260*440*1400)
node = ga.ContainerNode(db)
fitness = ga.solve_CLP(db, 10)
println(fitness)
#ga.as_3Dview(db, fitness, n=Inf)
