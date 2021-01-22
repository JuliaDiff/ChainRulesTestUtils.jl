# ChainRulesTestUtils

[![Travis](https://travis-ci.org/JuliaDiff/ChainRulesTestUtils.jl.svg?branch=master)](https://travis-ci.org/JuliaDiff/ChainRulesTestUtils.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)


[ChainRulesTestUtils.jl](https://github.com/JuliaDiff/ChainRulesTestUtils.jl) helps you test [`ChainRulesCore.frule`](http://www.juliadiff.org/ChainRulesCore.jl/dev/api.html) and [`ChainRulesCore.rrule`](http://www.juliadiff.org/ChainRulesCore.jl/dev/api.html) methods, when adding rules for your functions in your own packages.
For information about ChainRules, including how to write rules, refer to the general ChainRules Documentation:
[![](https://img.shields.io/badge/docs-master-blue.svg)](https://JuliaDiff.github.io/ChainRulesCore.jl/dev)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaDiff.github.io/ChainRulesCore.jl/stable)

## Canonical example

Let's suppose a custom transformation has been defined
```jldoctest ex; output = false
function two2three(x1::Float64, x2::Float64)
    return 1.0, 2.0*x1, 3.0*x2
end

# output
two2three (generic function with 1 method)
```
along with the `frule`
```jldoctest ex; output = false
using ChainRulesCore

function ChainRulesCore.frule((Δf, Δx1, Δx2), ::typeof(two2three), x1, x2)
    y = two2three(x1, x2)
    ∂y = Composite{Tuple{Float64, Float64, Float64}}(Zero(), 2.0*Δx1, 3.0*Δx2)
    return y, ∂y
end
# output

```
and `rrule`
```jldoctest ex; output = false
function ChainRulesCore.rrule(::typeof(two2three), x1, x2)
    y = two2three(x1, x2)
    function two2three_pullback(Ȳ)
        return (NO_FIELDS, 2.0*Ȳ[2], 3.0*Ȳ[3])
    end
    return y, two2three_pullback
end
# output

```

The [`frule_test`](@ref)/[`rrule_test`](@ref) helper function compares the `frule`/`rrule` outputs
to the gradients obtained by finite differencing.
They can be used for any type and number of inputs and outputs.

### Testing the `frule`

[`frule_test`](@ref) takes in the function `f` and tuples `(x, ẋ)` for each function argument `x`.
The call will test the `frule` for function `f` at the point `x` in the domain.
Keep this in mind when testing discontinuous rules for functions like [ReLU](https://en.wikipedia.org/wiki/Rectifier_(neural_networks)), which should ideally be tested at both `x` being above and below zero.
Additionally, choosing `ẋ` in an unfortunate way (e.g. as zeros) could hide underlying problems with the defined `frule`.

```jldoctest ex; output = false
using ChainRulesTestUtils

x1, x2 = (3.33, -7.77)
ẋ1, ẋ2 = (rand(), rand())

frule_test(two2three, (x1, ẋ1), (x2, ẋ2))
# output
Test Summary:                    | Pass  Total
Tuple{Float64,Float64,Float64}.1 |    1      1
Test Summary:                    | Pass  Total
Tuple{Float64,Float64,Float64}.2 |    1      1
Test Summary:                    | Pass  Total
Tuple{Float64,Float64,Float64}.3 |    1      1
Test Passed
```

### Testing the `rrule`

[`rrule_test`](@ref) takes in the function `f`, sensitivities of the function outputs `ȳ`, and tuples `(x, x̄)` for each function argument `x`.
`x̄` is the accumulated adjoint which can be set arbitrarily.
The call will test the `rrule` for function `f` at the point `x`, and similarly to `frule` some rules should be tested at multiple points in the domain.
Choosing `ȳ` in an unfortunate way (e.g. as zeros) could hide underlying problems with the `rrule`. 
```jldoctest ex; output = false
x1, x2 = (3.33, -7.77)
x̄1, x̄2 = (rand(), rand())
ȳs = (rand(), rand(), rand())

rrule_test(two2three, ȳs, (x1, x̄1), (x2, x̄2))

# output
Test Summary:                      |
Don't thunk only non_zero argument | No tests
Test.DefaultTestSet("Don't thunk only non_zero argument", Any[], 0, false)
```

## Scalar example

For functions with a single argument and a single output, such as e.g. ReLU,
```jldoctest ex; output = false
function relu(x::Real)
    return max(0, x)
end

# output
relu (generic function with 1 method)
```
with the `frule` and `rrule` defined with the help of `@scalar_rule` macro
```jldoctest ex; output = false
@scalar_rule relu(x::Real) x <= 0 ? zero(x) : one(x)

# output

```

`test_scalar` function is provided to test both the `frule` and the `rrule` with a single
call.
```jldoctest ex; output = false
test_scalar(relu, 0.5)
test_scalar(relu, -0.5)

# output
Test Summary:                 | Pass  Total
relu at 0.5, with tangent 1.0 |    3      3
Test Summary:                   | Pass  Total
relu at 0.5, with cotangent 1.0 |    4      4
Test Summary:                  | Pass  Total
relu at -0.5, with tangent 1.0 |    3      3
Test Summary:                    | Pass  Total
relu at -0.5, with cotangent 1.0 |    4      4
```

## Custom finite differencing

If a package is using a custom finite differencing method of testing the `frule`s and `rrule`s, `check_equal` function provides a convenient way of comparing [various types](https://www.juliadiff.org/ChainRulesCore.jl/dev/design/many_differentials.html#Design-Notes:-The-many-to-many-relationship-between-differential-types-and-primal-types.) of differentials.

It is effectively `(a, b) -> @test isapprox(a, b)`, but it preprocesses `thunk`s and `ChainRules` differential types `Zero()`, `DoesNotExist()`, and `Composite`, such that the error messages are helpful.

For example, 
```julia
check_equal((@thunk 2*2.0), 4.1)
```
shows both the expression and the evaluated `thunk`s
```julia
   Expression: isapprox(actual, expected; kwargs...)
   Evaluated: isapprox(4.0, 4.1)
ERROR: There was an error during testing
```
compared to
```julia
julia> @test isapprox(@thunk 2*2.0, 4.0)
Test Failed at REPL[52]:1
  Expression: isapprox(#= REPL[52]:1 =# @thunk((2 * 2.0, 4.0)))
   Evaluated: isapprox(Thunk(var"#24#25"()))
ERROR: There was an error during testing
```
which should have passed the test.
# API Documentation

```@autodocs
Modules = [ChainRulesTestUtils]
Private = false
```
