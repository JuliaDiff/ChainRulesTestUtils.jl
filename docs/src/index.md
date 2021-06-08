# ChainRulesTestUtils

[![CI](https://github.com/JuliaDiff/ChainRulesTestUtils.jl/workflows/CI/badge.svg?branch=master)](https://github.com/JuliaDiff/ChainRulesTestUtils.jl/actions?query=workflow%3ACI)
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
    ∂y = Tangent{Tuple{Float64, Float64, Float64}}(ZeroTangent(), 2.0*Δx1, 3.0*Δx2)
    return y, ∂y
end
# output

```
and `rrule`
```jldoctest ex; output = false
function ChainRulesCore.rrule(::typeof(two2three), x1, x2)
    y = two2three(x1, x2)
    function two2three_pullback(Ȳ)
        return (NoTangent(), 2.0*Ȳ[2], 3.0*Ȳ[3])
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
julia> using ChainRulesTestUtils;

julia> test_frule(two2three, 3.33, -7.77);
Test Summary:                            | Pass  Total
test_frule: two2three on Float64,Float64 |    6      6
```

### Testing the `rrule`

[`test_rrule`](@ref) takes in the function `f`, and primal inputsr `x`.
The call will test the `rrule` for function `f` at the point `x`, and similarly to `frule` some rules should be tested at multiple points in the domain.

```jldoctest ex; output = false
julia> test_rrule(two2three, 3.33, -7.77);
Test Summary:                            | Pass  Total
test_rrule: two2three on Float64,Float64 |    7      7
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
julia> test_scalar(relu, 0.5);
Test Summary:            | Pass  Total
test_scalar: relu at 0.5 |    9      9

julia> test_scalar(relu, -0.5);
Test Summary:             | Pass  Total
test_scalar: relu at -0.5 |    9      9
```

## Testing constructors and functors (callable objects)

Testing constructor and functors works as you would expect. For struct `Foo`
```julia
struct Foo
    a::Float64
end
(f::Foo)(x) = return f.a + x
Base.length(::Foo) = 1
Base.iterate(f::Foo) = iterate(f.a)
Base.iterate(f::Foo, state) = iterate(f.a, state)
```
the `f/rrule`s can be tested by
```julia
test_rrule(Foo, rand()) # constructor

foo = Foo(rand())
test_rrule(foo, rand()) # functor

# it is also possible to provide tangents for `foo` explicitly
test_frule(foo ⊢ Tangent{Foo}(;a=rand()), rand())
```

## Specifying Tangents
[`test_frule`](@ref) and [`test_rrule`](@ref) allow you to specify the tangents used for testing.
This is done by passing in `x ⊢ Δx`, where `x` is the primal and `Δx` is the tangent, in the place of the primal inputs.
If this is not done the tangent will be automatically generated via `FiniteDifferences.rand_tangent`.
A special case of this is that if you specify it as `x ⊢ NoTangent()` then finite differencing will not be used on that input.
Similarly, by setting the `output_tangent` keyword argument, you can specify the tangent for the primal output.

This can be useful when the default provided `FiniteDifferences.rand_tangent` doesn't produce the desired tangent for your type.
For example the default tangent for an `Int` is `NoTangent()`.
Which is correct e.g. when the `Int` represents a discrete integer like in indexing.
But if you are testing something where the `Int` is actually a special case of a real number, then you would want to specify the tangent as a `Float64`.

Care must be taken when manually specifying tangents.
In particular, when specifying the input tangents to [`test_frule`](@ref) and the output tangent to [`test_rrule`](@ref).
As these tangents are used to seed the derivative computation.
Inserting inappropriate zeros can thus hide errors.

## Custom finite differencing

If a package is using a custom finite differencing method of testing the `frule`s and `rrule`s, `test_approx` function provides a convenient way of comparing [various types](https://www.juliadiff.org/ChainRulesCore.jl/dev/design/many_differentials.html#Design-Notes:-The-many-to-many-relationship-between-differential-types-and-primal-types.) of differentials.

It is effectively `(a, b) -> @test isapprox(a, b)`, but it preprocesses `thunk`s and `ChainRules` differential types `ZeroTangent()`, `NoTangent()`, and `Tangent`, such that the error messages are helpful.

For example,
```julia
test_approx((@thunk 2*2.0), 4.1)
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
