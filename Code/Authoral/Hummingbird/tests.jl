using GLPK
using BenchmarkTools
import .Hummingbird as HB

#TESTS
db = HB.Database()
HB.add_item!(db, [40, 40, 50], false, 10000)
HB.add_item!(db, [27, 43, 32], false, 10000)
HB.add_item!(db, [50, 60, 40], false, 10000)
den = 300*550*1200
HB.add_container!(db, [220,350,720], 220*350*720/den)
HB.add_container!(db, [260,440,1000], 260*440*1000/den)
HB.add_container!(db, [260,440,1400], 260*440*1400/den)
HB.add_container!(db, [240,360,790], 240*360*790/den)
HB.add_container!(db, [200,300,450], 200*300*450/den)
HB.add_container!(db, [200,250,700], 200*250*700/den)
HB.add_container!(db, [250,500,1000], 250*500*1000/den)
HB.add_container!(db, [300,550,1200], 300*550*1200/den)
HB.add_container!(db, [210,410,1100], 210*410*1100/den)
HB.add_container!(db, [180,380,800], 180*380*800/den)
t0 = Dates.time()
sol = HB.solve_CLP(db, GLPK.Optimizer, flexible_ratio=0.1, separate_rankings=false, verbose=true)
##
