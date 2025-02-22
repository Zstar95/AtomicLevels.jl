"""
    terms(o::RelativisticOrbital, w = 1) -> Vector{HalfInt}

Returns a sorted list of valid ``J`` values of `w` equivalent ``jj``-coupled particles on
orbital `o` (i.e. `oʷ`).

When there are degeneracies (i.e. multiple states with the same ``J`` and ``M`` quantum
numbers), the corresponding ``J`` value is repeated in the output array.

# Examples

```jldoctest
julia> terms(ro"3d", 3)
3-element Array{HalfIntegers.Half{Int64},1}:
 3/2
 5/2
 9/2

julia> terms(ro"3d-", 3)
1-element Array{HalfIntegers.Half{Int64},1}:
 3/2

julia> terms(ro"4f", 4)
8-element Array{HalfIntegers.Half{Int64},1}:
 0
 2
 2
 4
 4
 5
 6
 8
```
"""
function terms(orb::RelativisticOrbital, w::Int=one(Int))
    j = kappa_to_j(orb.κ)
    0 <= w <= 2*j+1 || throw(DomainError(w, "w must be 0 <= w <= 2j+1 (=$(2j+1)) for j=$j"))
    # We can equivalently calculate the JJ terms for holes, so we'll do that when we have
    # fewer holes than particles on this shell
    2w ≥ 2j+1 && (w = convert(Int, 2j) + 1 - w)
    # Zero and one particle cases are simple special cases
    w == 0 && return [zero(HalfInt)]
    w == 1 && return [j]
    # _terms_jw is guaranteed to be in descending order
    reverse!(_terms_jw(j, w))
end

function _terms_jw(j::HalfInteger, w::Integer)
    j >= 0 || throw(DomainError(j, "j must be positive"))
    1 <= w <= 2*j+1 || throw(DomainError(w, "w must be 1 <= w <= 2j+1 (=$(2j+1)) for j=$j"))
    # This works by considering all possible n-particle fermionic product states (Slater
    # determinants; i.e. each orbital can only appear once) of the orbitals with different
    # m quantum numbers -- they are just different n-element combinations of the possible
    # m quantum numbers (m ∈ -j:j).
    #
    # Each of the product states is still a J_z eigenstate and the eigenvalue is just a sum
    # of the J_z eigenvalues of the orbitals. As for every coupled J, we also get M ∈ -J:J,
    # we can just look at the histogram of all the M quantum numbers to figure out which
    # J states and how many of them we have.
    Jmax = j*w
    NJ = convert(Int, 2*Jmax + 1)
    hist = zeros(Int, NJ)
    for c in combinations(HalfInt(-j):HalfInt(j), w)
        M = sum(c)
        i = convert(Int, M + Jmax) + 1
        hist[i] += 1
    end
    # Go through the histogram to figure out the J terms.
    jvalues = HalfInt[]
    Jmid = div(NJ, 2) + (isodd(NJ) ? 1 : 0)
    for i = 1:Jmid
        @assert hist[NJ - i + 1] == hist[i] # make sure that the histogram is symmetric
        J = convert(HalfInt, Jmax - i + 1)
        lastbin = (i > 1) ? hist[i-1] : 0
        @assert hist[i] >= lastbin
        for _ = 1:(hist[i]-lastbin)
            push!(jvalues, J)
        end
    end
    return jvalues
end

# This is a workaround until seniority number are implemented for
# jj-coupled subshells.
intermediate_terms(orb::RelativisticOrbital, w::Int=one(Int)) =
    terms(orb, w)

export terms, intermediate_terms
