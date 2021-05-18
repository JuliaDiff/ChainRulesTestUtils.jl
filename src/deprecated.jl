# TODO remove these in version 0.6
# We are silently deprecating them as there is no alternative we are providing

Base.isapprox(a, b::Union{AbstractZero, AbstractThunk}; kwargs...) = isapprox(b, a; kwargs...)
Base.isapprox(d_ad::AbstractThunk, d_fd; kwargs...) = isapprox(extern(d_ad), d_fd; kwargs...)
Base.isapprox(d_ad::NoTangent, d_fd; kwargs...) = error("Tried to differentiate w.r.t. a `NoTangent`")
# Call `all` to handle the case where `Zero` is standing in for a non-scalar zero
Base.isapprox(d_ad::Zero, d_fd; kwargs...) = all(isapprox.(extern(d_ad), d_fd; kwargs...))

isapprox_vec(a, b; kwargs...) = isapprox(first(to_vec(a)), first(to_vec(b)); kwargs...)
Base.isapprox(a, b::Tangent; kwargs...) = isapprox(b, a; kwargs...)
function Base.isapprox(d_ad::Tangent{<:Tuple}, d_fd::Tuple; kwargs...)
    return isapprox_vec(d_ad, d_fd; kwargs...)
end
function Base.isapprox(
    d_ad::Tangent{P, <:Tuple}, d_fd::Tangent{P, <:Tuple}; kwargs...
) where {P <: Tuple}
    return isapprox_vec(d_ad, d_fd; kwargs...)
end

function Base.isapprox(
    d_ad::Tangent{P, <:NamedTuple{T}}, d_fd::Tangent{P, <:NamedTuple{T}}; kwargs...,
) where {P, T}
    return isapprox_vec(d_ad, d_fd; kwargs...)
end


# Must be for same primal
Base.isapprox(d_ad::Tangent{P}, d_fd::Tangent{Q}; kwargs...) where {P, Q} = false


# From when primal and tangent was passed as a tuple
@deprecate(
    rrule_test(f, ȳ, inputs::Tuple{Any,Any}...; kwargs...),
    test_rrule(f, ((x ⊢ dx) for (x, dx) in inputs)...; output_tangent=ȳ, kwargs...)
)

@deprecate(
    frule_test(f, inputs::Tuple{Any,Any}...; kwargs...),
    test_frule(f, ((x ⊢ dx) for (x, dx) in inputs)...; kwargs...)
)
