# * Relativistic orbital

"""
    kappa_to_ℓ(κ::Integer) :: Integer

Calculate the `ℓ` quantum number corresponding to the `κ` quantum number.

Note: `κ` and `ℓ` values are always integers.
"""
function kappa_to_ℓ(kappa::Integer)
    kappa == zero(kappa) && throw(ArgumentError("κ can not be zero"))
    (kappa < 0) ? -(kappa+1) : kappa
end

"""
    kappa_to_j(κ::Integer) :: HalfInteger

Calculate the `j` quantum number corresponding to the `κ` quantum number.

Note: `κ` is always an integer.
"""
function kappa_to_j(kappa::Integer)
    kappa == zero(kappa) && throw(ArgumentError("κ can not be zero"))
    half(2*abs(kappa) - 1)
end

"""
    ℓj_to_kappa(ℓ::Integer, j::Real) :: Integer

Converts a valid `(ℓ, j)` pair to the corresponding `κ` value.

**Note:** there is a one-to-one correspondence between valid `(ℓ,j)` pairs and `κ` values
such that for `j = ℓ ± 1/2`, `κ = ∓(j + 1/2)`.
"""
function ℓj_to_kappa(ℓ::Integer, j::Real)
    assert_orbital_ℓj(ℓ, j)
    (j < ℓ) ? ℓ : -(ℓ + 1)
end

function assert_orbital_ℓj(ℓ::Integer, j::Real)
    j = HalfInteger(j)
    s = half(1)
    (ℓ == j + s) || (ℓ == j - s) ||
        throw(ArgumentError("Invalid (ℓ, j) = $(ℓ), $(j) pair, expected j = ℓ ± 1/2."))
    return
end

"""
    struct RelativisticOrbital{N <: AtomicLevels.MQ} <: AbstractOrbital

Label for an atomic orbital with a principal quantum number `n::N` and well-defined total
angular momentum ``j``. The angular component of the orbital is labelled by the ``(\\ell, j)``
pair, conventionally written as ``\\ell_j`` (e.g. ``p_{3/2}``).

The ``\\ell`` and ``j`` can not be arbitrary, but must satisfy ``j = \\ell \\pm 1/2``.
Internally, the ``\\kappa`` quantum number, which is a unique integer corresponding to every
physical ``(\\ell, j)`` pair, is used to label each allowed pair.
When ``j = \\ell \\pm 1/2``, the corresponding ``\\kappa = \\mp(j + 1/2)``.

When printing and parsing `RelativisticOrbital`s, the notation `nℓ` and `nℓ-` is used (e.g.
`2p` and `2p-`), corresponding to the orbitals with ``j = \\ell + 1/2`` and
``j = \\ell - 1/2``, respectively.

The type parameter `N` has to be such that it can represent a proper principal quantum number
(i.e. a subtype of [`AtomicLevels.MQ`](@ref)).

# Properties

The following properties are part of the public API:

* `.n :: N` -- principal quantum number ``n``
* `.κ :: Int` -- ``\\kappa`` quantum number
* `.ℓ :: Int` -- the orbital angular momentum label ``\\ell``
* `.j :: HalfInteger` -- total angular momentum ``j``

```jldoctest
julia> orb = ro"5g-"
5g-

julia> orb.n
5

julia> orb.j
7/2

julia> orb.ℓ
4
```

# Constructors

    RelativisticOrbital(n::Integer, κ::Integer)
    RelativisticOrbital(n::Symbol, κ::Integer)
    RelativisticOrbital(n, ℓ::Integer, j::Real)

Construct an orbital label with the quantum numbers `n` and `κ`.
If the principal quantum number `n` is an integer, it has to positive and the orbital angular
momentum must satisfy `0 <= ℓ < n`.
Instead of `κ`, valid `ℓ` and `j` values can also be specified instead.

```jldoctest
julia> RelativisticOrbital(1, 0, 1//2)
1s

julia> RelativisticOrbital(2, -1)
2s

julia> RelativisticOrbital(:K, 2, 3//2)
Kd-
```
"""
struct RelativisticOrbital{N<:MQ} <: AbstractOrbital
    n::N
    κ::Int
    function RelativisticOrbital(n::Integer, κ::Integer)
        n ≥ 1 || throw(ArgumentError("Invalid principal quantum number $(n)"))
        κ == zero(κ) && throw(ArgumentError("κ can not be zero"))
        ℓ = kappa_to_ℓ(κ)
        0 ≤ ℓ && ℓ < n || throw(ArgumentError("Angular quantum number has to be ∈ [0,$(n-1)] when n = $(n)"))
        new{Int}(n, κ)
    end
    function RelativisticOrbital(n::Symbol, κ::Integer)
        κ == zero(κ) && throw(ArgumentError("κ can not be zero"))
        new{Symbol}(n, κ)
    end
end
RelativisticOrbital(n::MQ, ℓ::Integer, j::Real) = RelativisticOrbital(n, ℓj_to_kappa(ℓ, j))

"""
    mqtype(::RelativisticOrbital{MQ}) = MQ

Returns the main quantum number type of a [`RelativisticOrbital`](@ref).
"""
mqtype(::RelativisticOrbital{MQ}) where MQ = MQ

Base.propertynames(::RelativisticOrbital) = (fieldnames(RelativisticOrbital)..., :j, :ℓ)
function Base.getproperty(o::RelativisticOrbital, s::Symbol)
    s === :j ? kappa_to_j(o.κ) :
    s === :ℓ ? kappa_to_ℓ(o.κ) :
    getfield(o, s)
end

function Base.show(io::IO, orb::RelativisticOrbital)
    write(io, "$(orb.n)$(spectroscopic_label(kappa_to_ℓ(orb.κ)))")
    orb.κ > 0 && write(io, "-")
end

function flip_j(orb::RelativisticOrbital)
    orb.κ == -1 && return RelativisticOrbital(orb.n, -1) # nothing to flip for s-orbitals
    RelativisticOrbital(orb.n, orb.κ < 0 ? abs(orb.κ) - 1 : -(orb.κ + 1))
end

degeneracy(orb::RelativisticOrbital{N}) where N = 2*abs(orb.κ) # 2j + 1 = 2|κ|

function Base.isless(a::RelativisticOrbital, b::RelativisticOrbital)
    nisless(a.n, b.n) && return true
    aℓ, bℓ = kappa_to_ℓ(a.κ), kappa_to_ℓ(b.κ)
    a.n == b.n && aℓ < bℓ && return true
    a.n == b.n && aℓ == bℓ && abs(a.κ) < abs(b.κ) && return true
    false
end

parity(orb::RelativisticOrbital) = p"odd"^kappa_to_ℓ(orb.κ)
symmetry(orb::RelativisticOrbital) = orb.κ

isbound(::RelativisticOrbital{Int}) = true
isbound(::RelativisticOrbital{Symbol}) = false

"""
    angular_momenta(orbital)

Returns the angular momentum quantum numbers of `orbital`.

# Examples
```jldoctest
julia> angular_momenta(ro"2p-")
(1/2,)

julia> angular_momenta(ro"3d")
(5/2,)
```
"""
angular_momenta(orbital::RelativisticOrbital) = (orbital.j,)
angular_momentum_labels(::RelativisticOrbital) = ("j",)

"""
    @ro_str -> RelativisticOrbital

A string macro to construct an [`RelativisticOrbital`](@ref) from the canonical string
representation.

```jldoctest
julia> ro"1s"
1s

julia> ro"2p-"
2p-

julia> ro"Kf-"
Kf-
```
"""
macro ro_str(orb_str)
    orbital_from_string(RelativisticOrbital, orb_str)
end

"""
    @ros_str -> Vector{RelativisticOrbital}

Can be used to easily construct a list of [`RelativisticOrbital`](@ref)s.

# Examples

```jldoctest
julia> ros"2[s-p] 3[p] k[0-d]"
10-element Array{RelativisticOrbital,1}:
 2s
 2p-
 2p
 3p-
 3p
 ks
 kp-
 kp
 kd-
 kd
```
"""
macro ros_str(orbs_str)
    orbitals_from_string(RelativisticOrbital, orbs_str)
end

function kappa_from_string(κ_str)
    m = match(r"^([a-z]|\[[0-9]+\])([-]{0,1})$", κ_str)
    m === nothing && throw(ArgumentError("Invalid κ string: $(κ_str)"))
    ℓ = parse_orbital_ℓ(m, 1)
    j = ℓ + half(m[2] == "-" ? -1 : 1)
    ℓj_to_kappa(ℓ, j)
end

"""
    @κ_str -> Int

A string macro to convert the canonical string representation of a ``\\ell_j`` angular label
(i.e. `ℓ-` or `ℓ`) into the corresponding ``\\kappa`` quantum number.

```jldoctest
julia> κ"s", κ"p-", κ"p"
(-1, 1, -2)
```
"""
macro κ_str(κ_str)
    kappa_from_string(κ_str)
end

"""
    nonrelorbital(o)

Return the non-relativistic orbital corresponding to `o`.

# Examples

```jldoctest
julia> nonrelorbital(o"2p")
2p

julia> nonrelorbital(ro"2p-")
2p
```
"""
nonrelorbital(o::Orbital) = o
nonrelorbital(o::RelativisticOrbital) = Orbital(o.n, o.ℓ)

export RelativisticOrbital, @ro_str, @ros_str, @κ_str, nonrelorbital
