using OffsetArrays

function dynamic_knapsack(p::Vector{Int}, v::Vector{Int}, c::Int)
    n = length(p)
    t = zeros(Int, n+1, c+1)
    t = OffsetArray(t, 0:n, 0:c)
    for i in 0:n
        t[i,0] = 0
    end
    for j in 1:c
        t[0,j] = 0
        for i in 1:n
            if p[i] > j
                t[i,j] = t[i-1,j]
            else
                t[i,j] = max(t[i-1,j], v[i]+t[i-1,j-p[i]])
            end
        end
    end
    return t
end

##
p = [4,2,1,3]
v = [500,400,300,450]
t = dynamic_knapsack(p, v, 5)