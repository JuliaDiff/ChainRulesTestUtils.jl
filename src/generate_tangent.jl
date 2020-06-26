"""
    rand_tangent([rng::AbstractRNG], x)

Returns a randomly generated tangent vector appropriate for the primal value `x`.
"""
rand_tangent(x) = rand_tangent(Random.GLOBAL_RNG, x)

function rand_tangent(rng::AbstractRNG, x::Union{Symbol, AbstractChar, AbstractString})
    return DoesNotExist()
end

rand_tangent(rng::AbstractRNG, x::Integer) = DoesNotExist()

rand_tangent(rng::AbstractRNG, x::T) where {T<:Number} = randn(rng, T)

rand_tangent(rng::AbstractRNG, x::StridedArray) = rand_tangent.(rng, x)

function rand_tangent(rng::AbstractRNG, x::T) where {T<:Tuple}
    return Composite{T}(rand_tangent.(rng, x)...)
end

function rand_tangent(rng::AbstractRNG, xs::T) where {T<:NamedTuple}
    return Composite{T}(; map(x -> rand_tangent(rng, x), xs)...)
end
