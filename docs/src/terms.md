# Term symbols

```@meta
DocTestSetup = quote
    using AtomicLevels
end
```

AtomicLevels provides types and methods to work and determine term symbols. The ["Term
symbol"](https://en.wikipedia.org/wiki/Term_symbol) and ["Angular momentum
coupling"](https://en.wikipedia.org/wiki/Angular_momentum_coupling) Wikipedia articles give a good basic
overview of the terminology.

For term symbols in LS coupling, AtomicLevels provides the [`Term`](@ref) type.

```@docs
Term
```

The [`Term`](@ref) objects can also be constructed with the [`@T_str`](@ref) string macro.

```@docs
@T_str
```

The [`terms`](@ref) function can be used to generate all possible term symbols. In the case
of relativistic orbitals, the term symbols are simply the valid ``J`` values, represented
with the `HalfInteger` type.

```@docs
terms
```

## Term multiplicity and intermediate terms

For subshells starting with `d³`, the possible terms may occur more
than once (multiplicity higher than one), corresponding to different
physical states. These arise from different sequences of coupling the
``w`` equivalent electrons of the same ``\ell``, and are distinguished
using a _seniority number_, which the [`IntermediateTerm`](@ref) type
implements. For partially filled `f` shells, seniority is not enough
to distinguish all possible couplings. Using `count_terms`, we can see
that e.g. the `²Dᵒ` has higher multiplicity than can be described with
seniority only:

```jldoctest
julia> count_terms(o"4f", 3, T"2Do")
2

julia> count_terms(o"4f", 5, T"2Do")
5
```

```@docs
IntermediateTerm
intermediate_terms
count_terms
```

### Internal implementation of term multiplicity calculation

AtomicLevels.jl uses the algorithm presented in

- _Alternative mathematical technique to determine LS spectral terms_
  by Xu Renjun and Dai Zhenwen, published in JPhysB, 2006.

  [doi:10.1088/0953-4075/39/16/007](https://dx.doi.org/10.1088/0953-4075/39/16/007)

to compute the multiplicity of individual subshells, beyond the
trivial cases of a single electron or a filled subshell. These
routines need not be used directly, instead use [`terms`](@ref) and
[`count_terms`](@ref).

In the following, ``S'=2S\in\mathbb{Z}`` and
``M_S'=2M_S\in\mathbb{Z}``, as in the original article.

```@docs
AtomicLevels.xu_terms
AtomicLevels.Xu.X
AtomicLevels.Xu.A
AtomicLevels.Xu.f
```

## Term couplings

The angular momentum coupling method is based on the [vector
model](https://en.wikipedia.org/wiki/Vector_model_of_the_atom),
where two angular momenta can be combined via vector addition to form
a total angular momentum:

```math
\vec{J} = \vec{L} + \vec{S},
```

where the length of the resultant momentum ``\vec{J}`` obeys

```math
|L-S| \leq J \leq L+S.
```

Relations such as these are used to couple the term symbols in both
``LS`` and ``jj`` coupling; however, not all values of ``J`` predicted
by the vector model are valid physical states, see
[`couple_terms`](@ref).

To generate the possible [`terms`](@ref) of a configuration, all the
possible terms of the individual subshells, have to be coupled
together to form the final terms; this is done from
left-to-right. When generating all possible [`CSFs`](@ref CSFs) from a
configuration, it is also necessary to find the intermediate couplings
of the individual subshells. As an example, if we want to find the
possible terms of `3p² 4s 5p²`, we first find the possible terms of the
individual subshells:

```jldoctest intermediate_term_examples
julia> its = intermediate_terms(c"3p2 4s 5p2")
3-element Array{Array{IntermediateTerm,1},1}:
 [₀¹S, ₂¹D, ₂³P]
 [₁²S]
 [₀¹S, ₂¹D, ₂³P]
```

where the seniority numbers are indicated as preceding subscripts. We
then need to couple each intermediate term of the first subshell with
each of the second subshell, and couple each of the resulting terms
with each of the third subshell, and so on. E.g. coupling the `₂³P`
intermediate term with `₁²S` produces two terms:

```jldoctest
julia> couple_terms(T"3P", T"2S")
2-element Array{Term,1}:
 ²P
 ⁴P
```

each of which need to be coupled with e.g. `₂¹D`:

```jldoctest
julia> couple_terms(T"2P", T"1D")
3-element Array{Term,1}:
 ²P
 ²D
 ²F

julia> couple_terms(T"4P", T"1D")
3-element Array{Term,1}:
 ⁴P
 ⁴D
 ⁴F
```

[`terms`](@ref) uses [`couple_terms`](@ref) (through
[`AtomicLevels.final_terms`](@ref)) to produce all possible terms
coupling trees, folding from left-to-right:

```jldoctest
julia> a = couple_terms([T"1S", T"1D", T"3P"], [T"2S"])
4-element Array{Term,1}:
 ²S
 ²P
 ²D
 ⁴P

julia> couple_terms(a, [T"1S", T"1D", T"3P"])
12-element Array{Term,1}:
 ²S
 ²P
 ²D
 ²F
 ²G
 ⁴S
 ⁴P
 ⁴D
 ⁴F
 ⁶S
 ⁶P
 ⁶D
```

which gives the same result as

```jldoctest
julia> terms(c"3p2 4s 5p2")
12-element Array{Term,1}:
 ²S
 ²P
 ²D
 ²F
 ²G
 ⁴S
 ⁴P
 ⁴D
 ⁴F
 ⁶S
 ⁶P
 ⁶D
```

Note that for the generation of final terms, the intermediate terms
need not be kept (and their seniority is not important). However, for
the generation of [`CSFs`](@ref CSFs), we need to form all possible
combinations of intermediate terms for each subshell, and couple them,
again left-to-right, to form all possible coupling chains (each one
corresponding to a unique physical state). E.g. for the last term of
each subshell of `3p² 4s 5p²`

```jldoctest intermediate_term_examples
julia> last.(its)
3-element Array{IntermediateTerm,1}:
 ₂³P
 ₁²S
 ₂³P
```

we find the following chains:

```jldoctest intermediate_term_examples
julia> intermediate_couplings(last.(its))
15-element Array{Array{Term,1},1}:
 [¹S, ³P, ²P, ²S]
 [¹S, ³P, ²P, ²P]
 [¹S, ³P, ²P, ²D]
 [¹S, ³P, ²P, ⁴S]
 [¹S, ³P, ²P, ⁴P]
 [¹S, ³P, ²P, ⁴D]
 [¹S, ³P, ⁴P, ²S]
 [¹S, ³P, ⁴P, ²P]
 [¹S, ³P, ⁴P, ²D]
 [¹S, ³P, ⁴P, ⁴S]
 [¹S, ³P, ⁴P, ⁴P]
 [¹S, ³P, ⁴P, ⁴D]
 [¹S, ³P, ⁴P, ⁶S]
 [¹S, ³P, ⁴P, ⁶P]
 [¹S, ³P, ⁴P, ⁶D]
```

```@docs
couple_terms
AtomicLevels.final_terms
intermediate_couplings
```

```@meta
DocTestSetup = nothing
```
