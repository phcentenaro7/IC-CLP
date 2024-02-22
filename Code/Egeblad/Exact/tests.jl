using GLPK
using Gurobi
include("knapsack.jl")

## EXACT METHOD TESTS

problem = KnapsackProblem(
            [20, 20, 20],
            [ItemInfo(2, 4, 5, 6, 10, "rgb(255,0,0)"),
            ItemInfo(6, 8, 4, 2, 12, "rgb(0,255,0)"),
            ItemInfo(5, 10, 7, 2, 15, "rgb(0,0,255)"),   
            ItemInfo(2, 2, 2, 4, 5, "rgb(128,128,128)"),
            ItemInfo(8, 9, 10, 6, 13, "rgb(255,255,255)"),
            ItemInfo(12, 12, 12, 1, 20, "rgb(0,0,0)"),
            ItemInfo(3, 7, 10, 2, 15, "rgb(128,128,0)"),
            ItemInfo(4, 8, 6, 3, 11, "rgb(0,128,128)")]
)
model = create_knapsack_model(problem)
set_optimizer(model, Gurobi.Optimizer)
set_time_limit_sec(model, 90)
optimize!(model)
kv = KnapsackVectors(problem, model)
draw_knapsack_solution(kv)