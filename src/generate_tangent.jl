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
