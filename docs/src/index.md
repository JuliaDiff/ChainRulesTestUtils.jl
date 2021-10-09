# ChainRulesTestUtils

[![CI](https://github.com/JuliaDiff/ChainRulesTestUtils.jl/workflows/CI/badge.svg?branch=main)](https://github.com/JuliaDiff/ChainRulesTestUtils.jl/actions?query=workflow%3ACI)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)


[ChainRulesTestUtils.jl](https://github.com/JuliaDiff/ChainRulesTestUtils.jl) helps you test [`ChainRulesCore.frule`](http://www.juliadiff.org/ChainRulesCore.jl/dev/api.html) and [`ChainRulesCore.rrule`](http://www.juliadiff.org/ChainRulesCore.jl/dev/api.html) methods, when adding rules for your functions in your own packages.
For information about ChainRules, including how to write rules, refer to the general ChainRules Documentation:
[![](https://img.shields.io/badge/docs-main-blue.svg)](https://JuliaDiff.github.io/ChainRulesCore.jl/dev)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaDiff.github.io/ChainRulesCore.jl/stable)

## Canonical example

Let's suppose a custom transformation has been defined
```jldoctest ex
function two2three(x1::Float64, x2::Float64)
    return 1.0, 2.0*x1, 3.0*x2
end

# output
two2three (generic function with 1 method)
```
along with the `frule`
```jldoctest ex
using ChainRulesCore

function ChainRulesCore.frule((Δf, Δx1, Δx2), ::typeof(two2three), x1, x2)
    y = two2three(x1, x2)
    ∂y = Tangent{Tuple{Float64, Float64, Float64}}(ZeroTangent(), 2.0*Δx1, 3.0*Δx2)
    return y, ∂y
end
# output

```
and `rrule`
```jldoctest ex
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

```jldoctest ex
julia> using ChainRulesTestUtils;

julia> test_frule(two2three, 3.33, -7.77);
Test Summary:                            | Pass  Total
test_frule: two2three on Float64,Float64 |    6      6

```

### Testing the `rrule`

[`test_rrule`](@ref) takes in the function `f`, and primal inputsr `x`.
The call will test the `rrule` for function `f` at the point `x`, and similarly to `frule` some rules should be tested at multiple points in the domain.

```jldoctest ex
julia> test_rrule(two2three, 3.33, -7.77);
Test Summary:                            | Pass  Total
test_rrule: two2three on Float64,Float64 |    9      9

```

## Scalar example

For functions with a single argument and a single output, such as e.g. ReLU,
```jldoctest ex
function relu(x::Real)
    return max(0, x)
end

# output
relu (generic function with 1 method)
```
with the `frule` and `rrule` defined with the help of `@scalar_rule` macro
```jldoctest ex
@scalar_rule relu(x::Real) x <= 0 ? zero(x) : one(x)

# output

```

`test_scalar` function is provided to test both the `frule` and the `rrule` with a single
call.
```jldoctest ex
julia> test_scalar(relu, 0.5);
Test Summary:            | Pass  Total
test_scalar: relu at 0.5 |   11     11


julia> test_scalar(relu, -0.5);
Test Summary:             | Pass  Total
test_scalar: relu at -0.5 |   11     11

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
By default, tangents will be automatically generated via `FiniteDifferences.rand_tangent`.
To explicitly specify a tangent, pass in `x ⊢ Δx`, where `x` is the primal and `Δx` is the tangent, in the place of the primal inputs.
(You can enter [`⊢`](@ref) via `\vdash` + tab in the Julia REPL and supporting editors.)
A special case of this is that if you specify it as `x ⊢ NoTangent()` then finite differencing will not be used on that input.
Similarly, by setting the `output_tangent` keyword argument, you can specify the tangent for the primal output.

This can be useful when the default provided `FiniteDifferences.rand_tangent` doesn't produce the desired tangent for your type.
For example, the default tangent for an `Int` is `NoTangent()`, which is correct e.g. when the `Int` represents a discrete integer like in indexing.
But if you are testing something where the `Int` is actually a special case of a real number, then you would want to specify the tangent as a `Float64`.

Care must be taken when manually specifying tangents.
In particular, when specifying the input tangents to [`test_frule`](@ref) and the output tangent to [`test_rrule`](@ref).
As these tangents are used to seed the derivative computation.
Inserting inappropriate zeros can thus hide errors.

## Testing higher order functions

Higher order functions, such as `map`, take a function (or a functor) `f` as an argument.
`f/rrule`s for these functions call back into AD to compute the `f/rrule` of `f`.
To test these functions, we use a dummy AD system, which simply calls the appropriate rule for `f` directly.
For this reason, when testing `map(f, collection)`, the rules for `f` need to be defined.
The `RuleConfig` for this dummy AD system is the default one, and does not need to be provided.
```julia
test_rrule(map, x->2x [1, 2, 3.]) # fails, because there is no rrule for x->2x

mydouble(x) = 2x
function ChainRulesCore.rrule(::typeof(mydouble), x)
    mydouble_pullback(ȳ) = (NoTangent(), ȳ)
    return mydouble(x), mydouble_pullback
end
test_rrule(map, mydouble, [1, 2, 3.]) # works
```

## Testing AD systems

The gradients computed by AD systems can be also be tested using `test_rrule`.
To do that, one needs to provide an `rrule_f`/`frule_f` keyword argument, as well as the `RuleConfig` used by the AD system.
`rrule_f` is a function that wraps the gradient computation by an AD system in the same API as the `rrule`.
`RuleConfig` is an object that determines which sets of rules are defined for an AD system.
For example, let's say we have a complicated function

```julia
function complicated(x, y)
    return do(x + y) + some(x) * hard(y) + maths(x * y)
end
```

that we do not know an `rrule` for, and we want to check whether the gradients provided by the AD system are correct.

To test gradients computed by the AD system you need to provide a `rrule_f` function that acts like calling `rrule` but use AD rather than a defined rule.
This has the exact same semantics as is required to overload `ChainRulesCore.rrule_via_ad`, thus almost all systems doing so should just overload that, and pass in that and the config, and then trigger `test_rrule(MyADConfig, f, xs; rrule_f = ChainRulesCore.rrule_via_ad)`.
See more info on `rrule_via_ad` and the rule configs in the [ChainRules documentation](https://juliadiff.org/ChainRulesCore.jl/stable/config.html).
For some AD systems (e.g. Zygote) `rrule_via_ad` already exists.
If it does not exist, see [How to write `rrule_via_ad` function](#How-to-write-rrule_via_ad-function) section below.

We use the `test_rrule` function to test the gradients using the config used by the AD system
```julia
config = MyAD.CustomRuleConfig()
test_rrule(config, complicated, 2.3, 6.1; rrule_f=rrule_via_ad)
```
by providing the rule config and specifying the `rrule_via_ad` as the `rrule_f` keyword argument.


### How to write `rrule_via_ad` function

`rrule_via_ad` will use the AD system to compute gradients and will package them in the `rrule`-like API.

Let's say the AD package uses some custom differential types and does not provide a gradient w.r.t. the function itself.
In order to make the pullback compatible with the `rrule` API we need to add a `NoTangent()` to represent the differential w.r.t. the function itself.
We also need to transform the `ChainRules` differential types to the custom types (`cr2custom`) before feeding the `Δ` to the AD-generated pullback, and back to `ChainRules` differential types when returning from the `rrule` (`custom2cr`).

```julia
function rrule_via_ad(config::MyAD.CustomRuleConfig, f::Function, args...)
    y, ad_pullback = MyAD.pullback(f, args...)
    function rrulelike_pullback(Δ)
        diffs = custom2cr(ad_pullback(cr2custom(Δ)))
        return NoTangent(), diffs...
    end
        
    return y, rrulelike_pullback
end

custom2cr(differential) = ...
cr2custom(differential) = ...
```

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

## Inference tests

By default, all functions for testing rules check whether the output type (as well as that of the pullback for `rrule`s) can be completely inferred, such that everything is type stable:

```julia
julia> function ChainRulesCore.rrule(::typeof(abs), x)
           abs_pullback(Δ) = (NoTangent(), x >= 0 ? Δ : big(-1.0) * Δ)
           return abs(x), abs_pullback
       end

julia> test_rrule(abs, 1.)
test_rrule: abs on Float64: Error During Test at /home/runner/work/ChainRulesTestUtils.jl/ChainRulesTestUtils.jl/src/testers.jl:170
  Got exception outside of a @test
  return type Tuple{ChainRulesCore.NoTangent, Float64} does not match inferred return type Tuple{ChainRulesCore.NoTangent, Union{Float64, BigFloat}}
[...]
```

This can be disabled on a per-rule basis using the `check_inferred` keyword argument:

```julia
julia> test_rrule(abs, 1.; check_inferred=false)
Test Summary:              | Pass  Total
test_rrule: abs on Float64 |    5      5
Test.DefaultTestSet("test_rrule: abs on Float64", Any[], 5, false, false)
```

This behavior can also be overridden globally by setting the environment variable `CHAINRULES_TEST_INFERRED` before ChainRulesTestUtils is loaded or by changing `ChainRulesTestUtils.TEST_INFERRED[]` from inside Julia.
ChainRulesTestUtils can detect whether a test is run as part of [PkgEval](https://github.com/JuliaCI/PkgEval.jl) and in this case disables inference tests automatically. Packages can use [`@maybe_inferred`](@ref) to get the same behavior for other inference tests.
