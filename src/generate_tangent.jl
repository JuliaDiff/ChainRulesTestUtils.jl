"""
    Auto()

Use this in the place of a tangent/cotangent in [`test_frule`](@ref) or
[`test_rrule`](@ref) to have that tangent/cotangent generated automatically based on the
primal. Uses [`rand_tangent`](@ref)
"""
struct Auto end

"""
    PrimalAndTangent

A struct that represents a primal value paired with its tangent or cotangent.
For conciseness we refer to both tangent and cotangent as "tangent".
"""
struct PrimalAndTangent{P,D}
    primal::P
    tangent::D
end
primal(p::PrimalAndTangent) = p.primal
tangent(p::PrimalAndTangent) = p.tangent

"""
    primal ⊢ tangent

Infix shorthand method to construct a `PrimalAndTangent`.
Enter via `\\vdash` + tab on supporting editors.
"""
const ⊢ = PrimalAndTangent

"""
    auto_primal_and_tangent(primal; rng=Random.GLOBAL_RNG)
    auto_primal_and_tangent(::PrimalAndTangent; rng=Random.GLOBAL_RNG)

Convience constructor for `PrimalAndTangent` where the primal is provided

This function is idempotent. If you pass it a `PrimalAndTangent` it doesn't change it.
"""
auto_primal_and_tangent(primal; rng=Random.GLOBAL_RNG) = primal ⊢ rand_tangent(rng, primal)
auto_primal_and_tangent(both::PrimalAndTangent; kwargs...) = both

"""
    rand_tangent([rng::AbstractRNG,] x)

Returns a randomly generated tangent vector appropriate for the primal value `x`.
"""
rand_tangent(x) = rand_tangent(Random.GLOBAL_RNG, x)

function rand_tangent(rng::AbstractRNG, x::Union{Symbol, AbstractChar, AbstractString})
    return DoesNotExist()
end

rand_tangent(rng::AbstractRNG, x::Integer) = DoesNotExist()

rand_tangent(rng::AbstractRNG, x::T) where {T<:Number} = randn(rng, T)

rand_tangent(rng::AbstractRNG, x::StridedArray) = rand_tangent.(Ref(rng), x)

function rand_tangent(rng::AbstractRNG, x::T) where {T<:Tuple}
    return Composite{T}(rand_tangent.(Ref(rng), x)...)
end

function rand_tangent(rng::AbstractRNG, xs::T) where {T<:NamedTuple}
    return Composite{T}(; map(x -> rand_tangent(rng, x), xs)...)
end

function rand_tangent(rng::AbstractRNG, x::T) where {T}
    if !isstructtype(T)
        throw(ArgumentError("Non-struct types are not supported by this fallback."))
    end

    field_names = fieldnames(T)
    if length(field_names) > 0
        tangents = map(field_names) do field_name
            rand_tangent(rng, getfield(x, field_name))
        end
        return Composite{T}(; NamedTuple{field_names}(tangents)...)
    else
        return NO_FIELDS
    end
end
