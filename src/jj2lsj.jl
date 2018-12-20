struct ClebschGordan{A,B,C,j₁T,j₂T}
    j₁::A
    m₁::A
    j₂::B
    m₂::B
    J::C
    M::C
end

Base.zero(::Type{ClebschGordan{A,B,C,j₁T,j₂T}}) where {A,B,C,j₁T,j₂T} =
    ClebschGordan{A,B,C,j₁T,j₂T}(zero(A),zero(A),zero(B),zero(B),zero(C),zero(C))

const ClebschGordanℓs{I<:Integer} = ClebschGordan{I,Rational{I},Rational{I},:ℓ,:s}
ClebschGordanℓs(j₁::I, m₁::I, j₂::R, m₂::R, J::R, M::R) where {I<:Integer,R<:Rational{I}} =
    ClebschGordanℓs{I}(j₁, m₁, j₂, m₂, J, M)

Base.convert(::Type{T}, cg::ClebschGordan) where {T<:Real} =
    clebschgordan(cg.j₁,cg.m₁,cg.j₂,cg.m₂,cg.J,cg.M)

Base.show(io::IO, cg::ClebschGordan) =
    write(io, "⟨$(rs(cg.j₁)),$(rs(cg.j₂));$(rs(cg.m₁)),$(rs(cg.m₂))|$(rs(cg.J)),$(rs(cg.M))⟩")

function Base.show(io::IO, cg::ClebschGordanℓs)
    spin = cg.m₂ > 0 ? "↑" : "↓"
    write(io, "⟨$(spectroscopic_label(cg.j₁));$(cg.m₁),$(spin)|$(rs(cg.J)),$(rs(cg.M))⟩")
end

#=
Relevant equations taken from

- Sakurai, J. J., & Napolitano, J. J. (2010). Modern quantum mechanics
(2nd edition). : Addison-Wesley.
=#

#=

Repeated action [Eq. (3.8.45)] with the ladder operators on the jmⱼ
basis

J±|ℓs;jmⱼ⟩

gives the following recursion relations, Eq. (3.8.49):

√((j∓mⱼ)(j±mⱼ+1))⟨ℓs;mₗ,mₛ|ℓs;j,mⱼ±1⟩
= √((ℓ∓mₗ+1)(ℓ±mₗ))⟨ℓs;mₗ∓1,mₛ|ℓs;j,mⱼ⟩
+ √((s∓mₛ+1)(s±mₛ))⟨ℓs;mₗ,mₛ∓1|ℓs;j,mⱼ⟩.

We know [Eq. (3.8.58)] that

⟨ℓs;±ℓ,±1/2|ℓs;ℓ±1/2,ℓ±1/2⟩ = 1.

=#
function rotate!(block::M, orbs::RelativisticOrbital...) where {T,M<:AbstractMatrix{T}}
    size(block,1) == size(block,2) == sum(degeneracy.(orbs))-2 ||
        throw(ArgumentError("Invalid block size for $(orbs...)"))
    ℓ = kappa_to_ℓ(first(orbs).κ)
    # We sort by mⱼ and remove the first and last elements since they
    # are pure and trivially unity.
    ℓms = vcat([[(ℓ,m,s) for m ∈ -ℓ:ℓ] for s = -1//2:1//2]...)[2:end-1]
    jmⱼ = sort(vcat([[(j,mⱼ) for mⱼ ∈ -j:j] for j ∈ [convert(Rational, kappa_to_j(o.κ)) for o in orbs]]...), by=last)[2:end-1]
    for (a,(ℓ,m,s)) in enumerate(ℓms)
        for (b,(j,mⱼ)) in enumerate(jmⱼ)
            block[a,b] = ClebschGordanℓs(ℓ,m,1//2,s,j,mⱼ)
        end
    end
    block
end

"""
    jj2lsj(orbs...)

Generates the block-diagonal matrix that transforms jj-coupled
configurations to lsj-coupled ones.

The blocks correspond to invariant subspaces, which rotate among
themselves to form new linear combinations.

They are sorted according to n,ℓ and within the blocks, the columns
are sorted according to mⱼ,j (increasing) and the rows according to
s,ℓ,m (increasing).

E.g. the p-block will have the following structure:

```
 ⟨p;-1,↓|3/2,-3/2⟩  │         ⋅                  ⋅                  ⋅                 ⋅          │         ⋅
 ───────────────────┼────────────────────────────────────────────────────────────────────────────┼─────────────────
        ⋅           │  ⟨p;0,↓|1/2,-1/2⟩   ⟨p;0,↓|3/2,-1/2⟩   ⟨p;0,↓|1/2,1/2⟩   ⟨p;0,↓|3/2,1/2⟩   │         ⋅
        ⋅           │  ⟨p;1,↓|1/2,-1/2⟩   ⟨p;1,↓|3/2,-1/2⟩   ⟨p;1,↓|1/2,1/2⟩   ⟨p;1,↓|3/2,1/2⟩   │         ⋅
        ⋅           │  ⟨p;-1,↑|1/2,-1/2⟩  ⟨p;-1,↑|3/2,-1/2⟩  ⟨p;-1,↑|1/2,1/2⟩  ⟨p;-1,↑|3/2,1/2⟩  │         ⋅
        ⋅           │  ⟨p;0,↑|1/2,-1/2⟩   ⟨p;0,↑|3/2,-1/2⟩   ⟨p;0,↑|1/2,1/2⟩   ⟨p;0,↑|3/2,1/2⟩   │         ⋅
 ───────────────────┼────────────────────────────────────────────────────────────────────────────┼─────────────────
        ⋅           │         ⋅                  ⋅                  ⋅                 ⋅          │  ⟨p;1,↑|3/2,3/2⟩
```

"""
function jj2lsj(::Type{T}, orbs::RelativisticOrbital...) where T
    nℓs = map(o -> (o.n, kappa_to_ℓ(o.κ)), sort([orbs...]))
    blocks = map(unique(nℓs)) do (n,ℓ)
        i = findall(isequal((n,ℓ)), nℓs)
        subspace = orbs[i]
        mⱼ = map(subspace) do orb
            j = convert(Rational, kappa_to_j(orb.κ))
            -j:j
        end

        jₘₐₓ = maximum([convert(Rational, kappa_to_j(o.κ)) for o in subspace])
        pure = [Matrix{T}(undef,1,1),Matrix{T}(undef,1,1)]
        pure[1][1]=ClebschGordanℓs(ℓ,-ℓ,1//2,-1//2,jₘₐₓ,-jₘₐₓ)
        pure[2][1]=ClebschGordanℓs(ℓ,ℓ,1//2,1//2,jₘₐₓ,jₘₐₓ)

        n = sum(length.(mⱼ))-2
        if n > 0
            b = zeros(T,n,n)
            rotate!(b, subspace...)
            [pure[1],b,pure[2]]
        else
            pure
        end
    end |> b -> vcat(b...)
    rows = size.(blocks,1)
    N = sum(rows)
    R = BlockBandedMatrix(Zeros{T}(N,N), (rows,rows), (0,0))
    for (i,b) in enumerate(blocks)
        R[Block(i,i)] .= b
    end
    R
end
jj2lsj(orbs::RelativisticOrbital...) = jj2lsj(Float64, orbs...)

export jj2lsj, ClebschGordan, ClebschGordanℓs
