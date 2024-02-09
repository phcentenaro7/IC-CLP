using GLPK
using Gurobi
include("knapsack.jl")

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
kvh = KnapsackVectors(problem)
s = solve_by_3d_simulated_annealing(kvh)
sequence_tuple_to_packing!(kvh, s)
draw_3d_knapsack_solution(kvh)
# seq_tuple, dims = packing_to_sequence_tuple(problem, model)
# d = sequence_tuple_to_digraphs(seq_tuple)
# for k in 1:3
#     gplot(d[k], layout=circular_layout, nodelabel=seq_tuple[k])
# end
# x, y, z = sequence_tuple_to_packing(seq_tuple, dims)
# deletion_indices = findall(==(0), value.(model[:s]))
# for index in deletion_indices
#     popat!(x, index); popat!(y, index); popat!(z, index)
#     popat!(dims[1], index); popat!(dims[2], index); popat!(dims[3], index)
# end
# draw_3d_knapsack_solution(problem.container_dims, (x, y, z), dims)