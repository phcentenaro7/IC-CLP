using GLPK
import .Hummingbird as HB

#TESTS
db = HB.Database()
HB.add_item!(db, [40, 40, 50], 122)
HB.add_item!(db, [27, 43, 32], 124)
HB.add_item!(db, [50, 60, 40], 1383)
HB.add_container!(db, [220,350,720], 220*350*720)
HB.add_container!(db, [260,440,1000], 260*440*1000)
HB.add_container!(db, [260,440,1400], 260*440*1400)
HB.add_container!(db, [240,360,790], 240*360*790)
HB.add_container!(db, [200,300,450], 200*300*450)
HB.add_container!(db, [200,250,700], 200*250*700)
HB.add_container!(db, [250,500,1000], 250*500*1000)
HB.add_container!(db, [300,550,1200], 300*550*1200)
HB.add_container!(db, [210,410,1100], 210*410*1100)
HB.add_container!(db, [180,380,800], 180*380*800)
seq = HB.solve_CLP(db, GLPK.Optimizer, verbose=true)
##