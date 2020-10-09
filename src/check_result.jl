
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
    @test isapprox(add!!(acc_mutated, val), acc + val; kwargs...)
end
