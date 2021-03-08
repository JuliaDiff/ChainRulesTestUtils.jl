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

The [`test_frule`](@ref)/[`test_rrule`](@ref) helper function compares the `frule`/`rrule` outputs
to the gradients obtained by finite differencing.
They can be used for any type and number of inputs and outputs.

### Testing the `frule`

[`test_frule`](@ref) takes in the function `f` and the primal input `x`.
The call will test the `frule` for function `f` at the point `x` in the domain.
Keep this in mind when testing discontinuous rules for functions like [ReLU](https://en.wikipedia.org/wiki/Rectifier_(neural_networks)), which should ideally be tested at both `x` being above and below zero.

```jldoctest ex; output = false
using ChainRulesTestUtils

test_frule(two2three, 3.33, -7.77);

# output
Test Summary:                          | Pass  Total
test_frule: two2three at (3.33, -7.77) |    5      5
Test.DefaultTestSet("test_frule: two2three at (3.33, -7.77)", Any[Test.DefaultTestSet("Tuple{Float64,Float64,Float64}.1", Any[], 1, false), Test.DefaultTestSet("Tuple{Float64,Float64,Float64}.2", Any[], 1, false), Test.DefaultTestSet("Tuple{Float64,Float64,Float64}.3", Any[], 1, false)], 2, false)
```

### Testing the `rrule`

[`test_rrule`](@ref) takes in the function `f`, and primal inputsr `x`.
The call will test the `rrule` for function `f` at the point `x`, and similarly to `frule` some rules should be tested at multiple points in the domain.

```jldoctest ex; output = false
test_rrule(two2three, 3.33, -7.77);

# output
Test Summary:                          | Pass  Total
test_rrule: two2three at (3.33, -7.77) |    6      6
Test.DefaultTestSet("test_rrule: two2three at (3.33, -7.77)", Any[Test.DefaultTestSet("Don't thunk only non_zero argument", Any[], 0, false)], 6, false)
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
test_scalar(relu, 0.5);
test_scalar(relu, -0.5);

# output
Test Summary:            | Pass  Total
test_scalar: relu at 0.5 |    7      7
Test Summary:             | Pass  Total
test_scalar: relu at -0.5 |    7      7
Test.DefaultTestSet("test_scalar: relu at -0.5", Any[Test.DefaultTestSet("with tangent 1.0", Any[Test.DefaultTestSet("test_frule: relu at (ChainRulesTestUtils.PrimalAndTangent{Float64,Float64}(-0.5, 1.0),)", Any[], 3, false)], 0, false), Test.DefaultTestSet("with cotangent 1.0", Any[Test.DefaultTestSet("test_rrule: relu at (ChainRulesTestUtils.PrimalAndTangent{Float64,Float64}(-0.5, 1.0),)", Any[Test.DefaultTestSet("Don't thunk only non_zero argument", Any[], 0, false)], 4, false)], 0, false)], 0, false)
```

## Specifying Tangents
[`test_frule`](@ref) and [`test_rrule`](@ref) allow you to specify the tangents used for testing.
This is done by passing in `x ⊢ Δx`, where `x` is the primal and `Δx` is the tangent, in the place of the primal inputs.
If this is not done the tangent will be automatically generated via [`ChainRulesTestUtils.rand_tangent`](@ref).
A special case of this is that if you specify it as `x ⊢ nothing` then finite differencing will not be used on that input.
Similarly, by setting the `output_tangent` keyword argument, you can specify the tangent for the primal output.

This can be useful when the default provided [`ChainRulesTestUtils.rand_tangent`](@ref) doesn't produce the desired tangent for your type.
For example the default tangent for an `Int` is `DoesNotExist()`.
Which is correct e.g. when the `Int` represents a discrete integer like in indexing.
But if you are testing something where the `Int` is actually a special case of a real number, then you would want to specify the tangent as a `Float64`.

Care must be taken when manually specifying tangents.
In particular, when specifying the input tangents to [`test_frule`](@ref) and the output tangent to [`test_rrule`](@ref).
As these tangents are used to seed the derivative computation.
Inserting inappropriate zeros can thus hide errors.

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

```@docs
ChainRulesTestUtils.rand_tangent
```
