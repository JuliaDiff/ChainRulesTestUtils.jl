# For once you have the sensitivity by two methods (e.g  both finite-differencing and  AD)
# the code here checks it is correct.
# Goal is to only call `@isapprox` on things that render well

"""
    check_equal(actual, expected; kwargs...)

`@test`'s  that `actual ≈ expected`, but breaks up data such that human readable results
are shown on failures.
All keyword arguments are passed to `isapprox`.
"""
function check_equal(
    actual::Union{AbstractArray{<:Number}, Number},
    expected::Union{AbstractArray{<:Number}, Number};
    kwargs...
)
    @test isapprox(actual, expected; kwargs...)
end

function check_equal(actual::AbstractThunk, expected; kwargs...)
    check_equal(unthunk(actual), expected; kwargs...)
end


function check_equal(
    actual::Union{Composite, AbstractArray},
    expected;
    kwargs...
)
    @test length(actual) == length(expected)
    @testset "$ii" for ii in keys(actual)  # keys works on all Composites
        check_equal(actual[ii], expected[ii]; kwargs...)
    end
end


"""
_check_add!!_behavour(acc, val)

This checks that `acc + val` is the same as `add!!(acc, val)`.
It matters primarily for types that overload `add!!` such as `InplaceableThunk`s.

`acc` is the value that has been accumulated so far.
`val` is a deriviative, being accumulated into `acc`.

`kwargs` are all passed on to isapprox
"""
function _check_add!!_behavour(acc, val; kwargs...)
    # Note, we don't test that `acc` is actually mutated because it doesn't have to be
    # e.g. if it is immutable. We do test the `add!!` return value.
    # That is what people should rely on. The mutation is just to save allocations.
    acc_mutated = deepcopy(acc)  # prevent this test changing others
    @test check_equal(add!!(acc_mutated, val), acc + val; kwargs...)
end
