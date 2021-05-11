# For once you have the sensitivity by two methods (e.g  both finite-differencing and  AD)
# the code here checks it is correct.
# Goal is to only call `@isapprox` on things that render well
# Note that this must work well both on Differential types and Primal types

"""
    check_equal(actual, expected; kwargs...)

`@test`'s  that `actual ≈ expected`, but breaks up data such that human readable results
are shown on failures.
Understands things like `unthunk`ing `ChainRuleCore.Thunk`s, etc.
All keyword arguments are passed to `isapprox`.
"""
function check_equal(
    actual::Union{AbstractArray{<:Number}, Number},
    expected::Union{AbstractArray{<:Number}, Number};
    kwargs...
)
    @test isapprox(actual, expected; kwargs...)
end

for (T1, T2) in ((AbstractThunk, Any), (AbstractThunk, AbstractThunk), (Any, AbstractThunk))
    @eval function check_equal(actual::$T1, expected::$T2; kwargs...)
        check_equal(unthunk(actual), unthunk(expected); kwargs...)
    end
end

check_equal(::Zero, x; kwargs...) = check_equal(zero(x), x; kwargs...)
check_equal(x, ::Zero; kwargs...) = check_equal(x, zero(x); kwargs...)
check_equal(x::Zero, y::Zero; kwargs...) = @test true

# remove once https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/113
check_equal(x::DoesNotExist, y::Nothing; kwargs...) = @test true
check_equal(x::Nothing, y::DoesNotExist; kwargs...) = @test true

# Checking equality with `NotImplemented` reports `@test_broken` since the derivative has intentionally
# not yet been implemented
# `@test_broken x == y` yields more descriptive messages than `@test_broken false`
check_equal(x::ChainRulesCore.NotImplemented, y; kwargs...) = @test_broken x == y
check_equal(x, y::ChainRulesCore.NotImplemented; kwargs...) = @test_broken x == y
# In this case we check for equality (messages etc. have to be equal)
function check_equal(
    x::ChainRulesCore.NotImplemented, y::ChainRulesCore.NotImplemented; kwargs...
)
    return @test x == y
end

"""
    _can_pass_early(actual, expected; kwargs...)
Used to check if `actual` is basically equal to `expected`, so we don't need to check deeper;
and can just report `check_equal` as passing.

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

function check_equal(actual::AbstractArray, expected::AbstractArray; kwargs...)
    if _can_pass_early(actual, expected)
        @test true
    else
        @test eachindex(actual) == eachindex(expected)
        @testset "$(typeof(actual))[$ii]" for ii in eachindex(actual)
            check_equal(actual[ii], expected[ii]; kwargs...)
        end
    end
end

function check_equal(actual::Composite{P}, expected::Composite{P}; kwargs...) where P
    if _can_pass_early(actual, expected)
        @test true
    else
        all_keys = union(keys(actual), keys(expected))
        @testset "$P.$ii" for ii in all_keys
            check_equal(getproperty(actual, ii), getproperty(expected, ii); kwargs...)
        end
    end
end

function check_equal(
    ::Composite{ActualPrimal}, expected::Composite{ExpectedPrimal}; kwargs...
) where {ActualPrimal, ExpectedPrimal}
    # this will certainly fail as we have another dispatch for that, but this will give as
    # good error message
    @test ActualPrimal === ExpectedPrimal
end


# Some structual differential and a natural differential
function check_equal(actual::Composite{P, T}, expected; kwargs...) where {T, P}
    if _can_pass_early(actual, expected)
        @test true
    else
        @assert (T <: NamedTuple)  # it should be a structual differential if we hit this

        # We are only checking the properties that are in the Composite
        # the natural differential is allowed to have other properties that we ignore
        @testset "$P.$ii" for ii in propertynames(actual)
            check_equal(getproperty(actual, ii), getproperty(expected, ii); kwargs...)
        end
    end
end
check_equal(x, y::Composite; kwargs...) = check_equal(y, x; kwargs...)

# This catches comparisons of Composites and Tuples/NamedTuple
# and gives an error message complaining about that
const LegacyZygoteCompTypes = Union{Tuple,NamedTuple}
check_equal(::C, ::T; kwargs...) where {C<:Composite,T<:LegacyZygoteCompTypes} = @test C === T
check_equal(::T, ::C; kwargs...) where {C<:Composite,T<:LegacyZygoteCompTypes} = @test T === C

# Generic fallback, probably a tuple or something
function check_equal(actual::A, expected::E; kwargs...) where {A, E}
    if _can_pass_early(actual, expected)
        @test true
    else
        c_actual = collect(actual)
        c_expected = collect(expected)
        if (c_actual isa A) && (c_expected isa E)  # prevent stack-overflow
            throw(MethodError, check_equal, (actual, expected))
        end
        check_equal(c_actual, c_expected; kwargs...)
    end
end

"""
_check_add!!_behaviour(acc, val)

This checks that `acc + val` is the same as `add!!(acc, val)`.
It matters primarily for types that overload `add!!` such as `InplaceableThunk`s.

`acc` is the value that has been accumulated so far.
`val` is a deriviative, being accumulated into `acc`.

`kwargs` are all passed on to isapprox
"""
function _check_add!!_behaviour(acc, val; kwargs...)
    # Note, we don't test that `acc` is actually mutated because it doesn't have to be
    # e.g. if it is immutable. We do test the `add!!` return value.
    # That is what people should rely on. The mutation is just to save allocations.
    acc_mutated = deepcopy(acc)  # prevent this test changing others
    check_equal(add!!(acc_mutated, val), acc + val; kwargs...)
end

# Checking equality with `NotImplemented` reports `@test_broken` since the derivative has intentionally
# not yet been implemented
# `@test_broken x == y` yields more descriptive messages than `@test_broken false`
function _check_add!!_behaviour(acc_mutated, acc::ChainRulesCore.NotImplemented; kwargs...)
    return @test_broken acc_mutated == acc
end
function _check_add!!_behaviour(acc_mutated::ChainRulesCore.NotImplemented, acc; kwargs...)
    return @test_broken acc_mutated == acc
end
# In this case we check for equality (messages etc. have to be equal)
function _check_add!!_behaviour(
    acc_mutated::ChainRulesCore.NotImplemented, acc::ChainRulesCore.NotImplemented;
    kwargs...,
)
    return @test acc_mutated == acc
end
