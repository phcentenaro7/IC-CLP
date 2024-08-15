include("ga.jl")
import .GeneticAlgorithm as ga
using Gurobi

ga.logging_on()
db = ga.Database()
ga.add_item!(db, [40, 40, 50], false, 2000)
ga.add_item!(db, [27, 43, 32], false, 2000)
ga.add_item!(db, [50, 60, 40], false, 2000)
den = 260*440*1860
ga.add_container!(db, [220,350,720], 220*350*720/den)
ga.add_container!(db, [260,440,1000], 260*440*1000/den)
ga.add_container!(db, [260,440,1860], 260*440*1860/den)
pop, pop_fit, fit_plot = ga.solve_CLP(db, 10, Gurobi.Optimizer, plot_data=true, pop_ratio=5)
fit_plot
