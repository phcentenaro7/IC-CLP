using GLPK
using Gurobi
using BenchmarkTools
import .Hummingbird as HB

#TESTS
db = HB.Database()
# HB.add_item!(db, [40, 40, 50], true, 122)
# HB.add_item!(db, [27, 43, 32], true, 124)
# HB.add_item!(db, [50, 60, 40], true, 1383)
HB.add_item!(db, [40, 40, 50], false, 10000)
HB.add_item!(db, [27, 43, 32], false, 10000)
HB.add_item!(db, [50, 60, 40], false, 10000)
den = 260*440*1860
HB.add_container!(db, [220,350,720], 220*350*720/den)
HB.add_container!(db, [260,440,1000], 260*440*1000/den)
HB.add_container!(db, [260,440,1400], 260*440*1400/den)
HB.add_container!(db, [260,440,1860], 260*440*1860/den)

sol = HB.solve_CLP(db, Gurobi.Optimizer, flexible_ratio=0.1, separate_rankings=false, verbose=true)
##
