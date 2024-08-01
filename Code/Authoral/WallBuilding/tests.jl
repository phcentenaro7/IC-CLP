using Gurobi
include("wb.jl")
import .WallBuilding as wb

#TESTS
db = wb.Database()
# wb.add_item!(db, [40, 40, 50], true, 122)
# wb.add_item!(db, [27, 43, 32], true, 124)
# wb.add_item!(db, [50, 60, 40], true, 1383)
wb.add_item!(db, [40, 40, 50], false, 2000)
wb.add_item!(db, [27, 43, 32], false, 2000)
wb.add_item!(db, [50, 60, 40], false, 2000)
den = 260*440*1860
wb.add_container!(db, [220,350,720], 220*350*720/den)
wb.add_container!(db, [260,440,1000], 260*440*1000/den)
wb.add_container!(db, [260,440,1860], 260*440*1860/den)
sol = wb.solve_CLP(db, Gurobi.Optimizer, flexible_ratio=0.1, separate_rankings=false, verbose=true)
# wb.as_3Dview(db, wb.get_node(sol.sequence, 15))