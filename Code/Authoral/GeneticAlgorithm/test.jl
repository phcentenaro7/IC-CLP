include("ga.jl")
import .GeneticAlgorithm as ga
using Gurobi

db = ga.Database()  
ga.add_item!(db, [40, 40, 50], true, 122)
ga.add_item!(db, [27, 43, 32], true, 124)
ga.add_item!(db, [50, 60, 40], true, 1383)
ga.add_container!(db, [260,440,1400], 260*440*1400)
pop_fitness = ga.solve_CLP(db, 10)
println(pop_fitness)
