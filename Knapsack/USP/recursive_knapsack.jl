function recursive_knapsack(p::Vector{Int}, v::Vector{Int}, c::Int; n::Int=length(p), X::Vector{Int}=Vector{Int}([]), s::Int=0)
    if n == 0
        return X,s
    end
    Xₙ = copy(X)   
    X₁, s₁ = recursive_knapsack(p, v, c, n=n-1, X=Xₙ, s=s)
    X₂ = []
    s₂ = 0
    if p[n] ≤ c
        X₂, s₂ = recursive_knapsack(p, v, c-p[n], n=n-1, X=push!(Xₙ, n), s=(s + v[n]))
    end
    s = max(s₁, s₂)
    X₃ = s == s₁ ? X₁ : X₂
    return X₃,s
end

##
p = [4,2,1,3]
v = [500,400,300,450]
recursive_knapsack(p, v, 7)