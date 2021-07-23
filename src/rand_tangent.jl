"""
    rand_tangent([rng::AbstractRNG,] x)

Returns a arbitary tangent vector _appropriate_ for the primal value `x`.
Note that despite the name, no promises on the statistical randomness are made.
Rather it is an arbitary value, that is generated using the `rng`.
"""
rand_tangent(x) = rand_tangent(Random.GLOBAL_RNG, x)

rand_tangent(rng::AbstractRNG, x::Symbol) = NoTangent()
rand_tangent(rng::AbstractRNG, x::AbstractChar) = NoTangent()
rand_tangent(rng::AbstractRNG, x::AbstractString) = NoTangent()

rand_tangent(rng::AbstractRNG, x::Integer) = NoTangent()

# Try and make nice numbers with short decimal representations for good error messages
# while also not biasing the sample space too much
function rand_tangent(rng::AbstractRNG, x::T) where {T<:Number}
    # multiply by 9 to give a bigger range of values tested: no so tightly clustered around 0.
    return round(9 * randn(rng, T), sigdigits=5, base=2)
end
rand_tangent(rng::AbstractRNG, x::Float64) = rand(rng, -9:0.01:9)
function rand_tangent(rng::AbstractRNG, x::ComplexF64)
    return ComplexF64(rand(rng, -9:0.1:9), rand(rng, -9:0.1:9))
end

#BigFloat/MPFR is finicky about short numbers, this doesn't always work as well as it should

# multiply by 9 to give a bigger range of values tested: no so tightly clustered around 0.
rand_tangent(rng::AbstractRNG, ::BigFloat) = round(big(9 * randn(rng)), sigdigits=5, base=2)


rand_tangent(rng::AbstractRNG, x::Array{<:Any, 0}) = _compress_notangent(fill(rand_tangent(rng, x[])))
rand_tangent(rng::AbstractRNG, x::Array) = _compress_notangent(rand_tangent.(Ref(rng), x))

# All other AbstractArray's can be handled using the ProjectTo mechanics.
# and follow the same requirements
function rand_tangent(rng::AbstractRNG, x::AbstractArray)
    return _compress_notangent(ProjectTo(x)(rand_tangent(collect(x))))
end

# TODO: arguably ProjectTo should handle this for us for AbstactArrays
# https://github.com/JuliaDiff/ChainRulesCore.jl/issues/410
_compress_notangent(::AbstractArray{NoTangent}) = NoTangent()
_compress_notangent(x) = x

function rand_tangent(rng::AbstractRNG, x::T) where {T}
    if !isstructtype(T)
        throw(ArgumentError("Non-struct types are not supported by this fallback."))
    end

    field_names = fieldnames(T)
    tangents = map(field_names) do field_name
        rand_tangent(rng, getfield(x, field_name))
    end
    if all(tangent isa NoTangent for tangent in tangents)
        # if none of my fields can be perturbed then I can't be perturbed
        return NoTangent()
    end

    if T <: Tuple
        return Tangent{T}(tangents...)
    else
        return Tangent{T}(; NamedTuple{field_names}(tangents)...)
    end
end

rand_tangent(rng::AbstractRNG, ::Type) = NoTangent()
rand_tangent(rng::AbstractRNG, ::Module) = NoTangent()
