# For once you have the sensitivity by two methods (e.g  both finite-differencing and  AD)
# the code here checks it is correct.
# Goal is to only call `@isapprox` on things that render well
# Note that this must work well both on Differential types and Primal types

"""
    test_approx(actual, expected, [msg]; kwargs...)

`@test`'s  that `actual ≈ expected`, but breaks up data such that human readable results
are shown on failures.
Understands things like `unthunk`ing `ChainRuleCore.Thunk`s, etc.

If provided `msg` is printed on a failure. Often additional items are appended to `msg` to
give bread-crumbs into nested structures.

All keyword arguments are passed to `isapprox`.
"""
function test_approx(
    actual::Union{AbstractArray{<:Number},Number},
    expected::Union{AbstractArray{<:Number},Number},
    msg="";
    kwargs...,
)
    @test_msg msg isapprox(actual, expected; kwargs...)
end

for (T1, T2) in ((AbstractThunk, Any), (AbstractThunk, AbstractThunk), (Any, AbstractThunk))
    @eval function test_approx(actual::$T1, expected::$T2, msg=""; kwargs...)
        return test_approx(unthunk(actual), unthunk(expected), msg; kwargs...)
    end
end

test_approx(::AbstractZero, x, msg=""; kwargs...) = test_approx(zero(x), x, msg; kwargs...)
test_approx(x, ::AbstractZero, msg=""; kwargs...) = test_approx(x, zero(x), msg; kwargs...)
test_approx(x::ZeroTangent, y::ZeroTangent, msg=""; kwargs...) = @test true
test_approx(x::NoTangent, y::NoTangent, msg=""; kwargs...) = @test true

# remove once https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/113
test_approx(x::NoTangent, y::Nothing, msg=""; kwargs...) = @test true
test_approx(x::Nothing, y::NoTangent, msg=""; kwargs...) = @test true

# Checking equality with `NotImplemented` reports `@test_broken` since the derivative has intentionally
# not yet been implemented
# `@test_broken x == y` yields more descriptive messages than `@test_broken false`
test_approx(x::ChainRulesCore.NotImplemented, y, msg=""; kwargs...) = @test_broken x == y
test_approx(x, y::ChainRulesCore.NotImplemented, msg=""; kwargs...) = @test_broken x == y
# In this case we check for equality (messages etc. have to be equal)
function test_approx(
    x::ChainRulesCore.NotImplemented, y::ChainRulesCore.NotImplemented, msg=""; kwargs...
)
    return @test_msg msg x == y
end

"""
    _can_pass_early(actual, expected; kwargs...)
Used to check if `actual` is basically equal to `expected`, so we don't need to check deeper
and can just report `test_approx` as passing.

If either `==` or `≈` return true then so does this.
The `kwargs` are passed on to `isapprox`
"""
function _can_pass_early(actual, expected; kwargs...)
    actual == expected && return true
    try
        return isapprox(actual, expected; kwargs...)
    catch err
        # Might MethodError, might DimensionMismatch, might fail for some other reason
        # we don't care, whatever errored it means we can't quit early
    end
    return false
end

function test_approx(actual::AbstractArray, expected::AbstractArray, msg=""; kwargs...)
    if _can_pass_early(actual, expected)
        @test true
    else
        @test_msg "$msg: indices must match" eachindex(actual) == eachindex(expected)
        for ii in eachindex(actual)
            new_msg = "$msg $(typeof(actual))[$ii]"
            test_approx(actual[ii], expected[ii], new_msg; kwargs...)
        end
    end
end

function test_approx(actual::Tangent{P}, expected::Tangent{P}, msg=""; kwargs...) where {P}
    if _can_pass_early(actual, expected)
        @test true
    else
        all_keys = union(keys(actual), keys(expected))
        for ii in all_keys
            new_msg = "$msg $P.$ii"
            test_approx(
                getproperty(actual, ii), getproperty(expected, ii), new_msg; kwargs...
            )
        end
    end
end

function test_approx(
    ::Tangent{ActualPrimal}, expected::Tangent{ExpectedPrimal}, msg=""; kwargs...
) where {ActualPrimal,ExpectedPrimal}
    # this will certainly fail as we have another dispatch for that, but this will give as
    # good error message
    @test ActualPrimal === ExpectedPrimal
end

# Some structual differential and a natural differential
function test_approx(actual::Tangent{P,T}, expected, msg=""; kwargs...) where {T,P}
    if _can_pass_early(actual, expected)
        @test true
    else
        @assert (T <: NamedTuple)  # it should be a structual differential if we hit this

        # We are only checking the properties that are in the Tangent
        # the natural differential is allowed to have other properties that we ignore
        for ii in propertynames(actual)
            new_msg = "$msg $P.$ii"
            test_approx(
                getproperty(actual, ii), getproperty(expected, ii), new_msg; kwargs...
            )
        end
    end
end
test_approx(x, y::Tangent, msg=""; kwargs...) = test_approx(y, x, msg; kwargs...)

function test_approx(actual::Tangent, expected::AbstractThunk, msg=""; kwargs...)
    return test_approx(actual, unthunk(expected), msg; kwargs...)
end

# This catches comparisons of Tangents and Tuples/NamedTuple
# and gives an error message complaining about that. the `@test` will definitely fail
const LegacyZygoteCompTypes = Union{Tuple,NamedTuple}
function test_approx(x::Tangent, y::LegacyZygoteCompTypes, msg=""; kwargs...)
    @test_msg "$msg: for structural differentials use `Tangent`" typeof(x) === typeof(y)
end
function test_approx(x::LegacyZygoteCompTypes, y::Tangent, msg=""; kwargs...)
    return test_approx(y, x, msg; kwargs...)
end

# Generic fallback, probably a tuple or something
function test_approx(actual::A, expected::E, msg=""; kwargs...) where {A,E}
    if _can_pass_early(actual, expected)
        @test true
    else
        # Works around https://github.com/JuliaLang/julia/issues/43847 on pre-Julia v1.9
        c_actual = collect(Broadcast.materialize(actual))
        c_expected = collect(Broadcast.materialize(expected))
        if (c_actual isa A) && (c_expected isa E)  # prevent stack-overflow
            throw(MethodError, test_approx, (actual, expected))
        end
        test_approx(c_actual, c_expected, msg; kwargs...)
    end
end

###########################################################################################

"""
_test_add!!_behaviour(acc, val)

This checks that `acc + val` is the same as `add!!(acc, val)`.
It matters primarily for types that overload `add!!` such as `InplaceableThunk`s.

`acc` is the value that has been accumulated so far.
`val` is a deriviative, being accumulated into `acc`.

`kwargs` are all passed on to isapprox
"""
function _test_add!!_behaviour(acc, val; kwargs...)
    # Note, we don't test that `acc` is actually mutated because it doesn't have to be
    # e.g. if it is immutable. We do test the `add!!` return value.
    # That is what people should rely on. The mutation is just to save allocations.
    acc_mutated = deepcopy(acc)  # prevent this test changing others
    return test_approx(add!!(acc_mutated, val), acc + val, "in add!!"; kwargs...)
end

# Checking equality with `NotImplemented` reports `@test_broken` since the derivative has
# intentionally not yet been implemented
# `@test_broken x == y` yields more descriptive messages than `@test_broken false`
function _test_add!!_behaviour(acc_mutated, acc::ChainRulesCore.NotImplemented; kwargs...)
    return @test_broken acc_mutated == acc
end
function _test_add!!_behaviour(acc_mutated::ChainRulesCore.NotImplemented, acc; kwargs...)
    return @test_broken acc_mutated == acc
end
# In this case we check for equality (not implemented messages etc. have to be equal)
function _test_add!!_behaviour(
    acc_mutated::ChainRulesCore.NotImplemented,
    acc::ChainRulesCore.NotImplemented;
    kwargs...,
)
    return @test acc_mutated == acc
end
