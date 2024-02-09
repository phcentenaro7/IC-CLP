function packing_to_sequence_tuple(problem::KnapsackProblem, model::GenericModel{T}) where {T <: Real}
    return @match value(model[:dims]) begin
        2 => packing_to_sequence_pair(problem, model)
        3 => packing_to_sequence_triple(problem, model)
    end
end

function packing_to_sequence_pair(kv::KnapsackVectors)
    s = kv.in_container
    x, y, _ = kv_pos(kv)
    w, h, _  = kv_dims(kv)
    selected = findall(x->isone(x), s)
    𝔄(i, j) = x[i] + w[i] ≤ x[j] || y[j] + h[j] ≤ y[i]
    𝔅(i, j) = x[i] + w[i] ≤ x[j] || y[i] + h[i] ≤ y[j]
    A = sort(selected, lt=𝔄)
    B = sort(selected, lt=𝔅)
    seq_pair = (A, B)
    dims = (w, h)
    return seq_pair, dims
end

function packing_to_sequence_triple(kv::KnapsackVectors)
    s = kv.in_container
    x, y, z = kv_pos(kv)
    w, h, d = kv_dims(kv)
    selected = findall(x->isone(x), s)
    𝔄(i, j) = x[i] + w[i] ≤ x[j] || y[j] + h[j] ≤ y[i] || z[j] + d[j] ≤ z[i]
    𝔅(i, j) = x[i] ≤ x[j] + w[j] || y[i] ≤ y[j] + h[j] || z[i] ≤ z[j] + d[j]
    ℭ(i, j) = x[j] + w[j] ≤ x[i] || y[i] + h[i] ≤ y[j] || z[j] + d[j] ≤ z[i]
    A = sort(selected, lt=𝔄, alg=MergeSort)
    B = sort(selected, lt=𝔅, alg=MergeSort)
    C = sort(selected, lt=ℭ, alg=MergeSort)
    seq_triple = (A, B, C)
    dims = (w, h, d)
    return seq_triple, dims
end

function sequence_tuple_to_digraphs(tuple::Tuple)
    A, B, C = tuple
    nv = length(A)
    d = [SimpleDiGraph(nv), SimpleDiGraph(nv), SimpleDiGraph(nv)]
    α(i, j, X) = findfirst(==(i), X) < findfirst(==(j), X)
    for i in 1:nv
        i ∉ A && continue
        for j in 1:nv
            i == j || j ∉ A && continue
            𝔄ᵢⱼ, 𝔅ᵢⱼ, ℭᵢⱼ = α(i, j, A), α(i, j, B), α(i, j, C) 
            if 𝔄ᵢⱼ && 𝔅ᵢⱼ && !ℭᵢⱼ
                add_edge!(d[1], i, j)
            elseif !𝔄ᵢⱼ && 𝔅ᵢⱼ && ℭᵢⱼ
                add_edge!(d[2], i, j)
            elseif (!𝔄ᵢⱼ && 𝔅ᵢⱼ && !ℭᵢⱼ) || (𝔄ᵢⱼ && 𝔅ᵢⱼ && ℭᵢⱼ)
                add_edge!(d[3], i, j)
            end
        end
    end
    return d
end

function sequence_tuple_to_packing!(kv, tuple)
    s = shuffle(tuple)
    A, B, C = s
    n = max(A...)
    x, y, z = zeros(n), zeros(n), zeros(n)
    w, h, d = kv_dims(kv)
    W, H, D = kv_cdims(kv)
    P = [B[1]]
    kv.in_container[P[1]] = true
    α(i, j, X) = findfirst(==(i), X) < findfirst(==(j), X)
    in_container(i) = begin
        x[i] ≥ 0        && y[i] ≥ 0        && z[i] ≥ 0 &&
        x[i] + w[i] ≤ W && y[i] + h[i] ≤ H && z[i] + d[i] ≤ D
    end
    for i in B[2:end]
        Px = [j for j in P if (α(i, j, A) && !α(i, j, C))]
        Py = [j for j in P if !α(i, j, A) && α(i, j, C)]
        Pz = [j for j in P if (!α(i, j, A) && !α(i, j, C)) || ((α(i, j, A) && α(i, j, C)))]
        x[i] = isempty(Px) ? 0 : max([x[j] + w[j] for j in Px]...)
        y[i] = isempty(Py) ? 0 : max([y[j] + h[j] for j in Py]...)
        z[i] = isempty(Pz) ? 0 : max([z[j] + d[j] for j in Pz]...)
        kv.in_container[i] = in_container(i)
        push!(P, i)
    end
    kv.x, kv.y, kv.z = x, y, z
end