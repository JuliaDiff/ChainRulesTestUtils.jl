# ChainRulesTestUtils

[![Travis](https://travis-ci.org/JuliaDiff/ChainRulesTestUtils.jl.svg?branch=master)](https://travis-ci.org/JuliaDiff/ChainRulesTestUtils.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)


[ChainRulesTestUtils.jl](https://github.com/JuliaDiff/ChainRulesTestUtils.jl) helps you test [`ChainRulesCore.frule`](http://www.juliadiff.org/ChainRulesCore.jl/dev/api.html) and [`ChainRulesCore.rrule`](http://www.juliadiff.org/ChainRulesCore.jl/dev/api.html) methods, when adding rules for your functions in your own packages.
For information about ChainRules, including how to write rules, refer to the general ChainRules Documentation:
[![](https://img.shields.io/badge/docs-master-blue.svg)](https://JuliaDiff.github.io/ChainRulesCore.jl/dev)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaDiff.github.io/ChainRulesCore.jl/stable)

## Canonical example

Let's suppose a custom transformation has been defined
```
function two2three(a::Float64, b::Float64)
    return 1.0, 2.0*a, 3.0*b
end
```
along with the `frule`
```
function ChainRulesCore.frule((Δf, Δa, Δb), ::typeof(two2three), a, b)
    y = two2three(a, b)
    ∂y = Composite{Tuple{Float64, Float64, Float64}}(Zero(), 2.0*Δa, 3.0*Δb)
    return y, ∂y
end
```
and `rrule`
```
function ChainRulesCore.rrule(::typeof(two2three), a, b)
    y = two2three(a, b)
    function two2three_pullback(Ȳ)
        return (NO_FIELDS, 2.0*Ȳ[2], 3.0*Ȳ[3])
    end
    return y, two2three_pullback
end
```

The `test_frule`/`test_rrule` helper function compares the `frule`/`rrule` outputs
to the gradients obtained by finite differencing.
They can be used for any type and number of inputs and outputs.

### Testing the `frule`

`frule_test` takes in the function `f` and tuples `(x, ẋ)` for each function argument `x`.
The call will test the `frule` for function `f` at the point `x` in the domain. Keep
this in mind when testing discontinuous rules for functions like
[ReLU](https://en.wikipedia.org/wiki/Rectifier_(neural_networks)), which should ideally
be tested at both `x` being above and below zero.
Additionally, choosing `ẋ` in an unfortunate way (e.g. as zeros) could hide
underlying problems with the defined `frule`.

```
xs = (3.33, -7.77)
ẋs = (rand(), rand())
frule_test(two2three, (xs[1], ẋs[1]), (xs[2], ẋs[2]))
```

### Testing the `rrule`

`rrule_test` takes in the function `f`, sensitivities of the function outputs `ȳ`,
and tuples `(x, x̄)` for each function argument `x`.
`x̄` is the accumulated adjoint which should be set randomly.
The call will test the `rrule` for function `f` at the point `x`, and similarly to
`frule` some rules should be tested at multiple points in the domain.
Choosing `ȳ` in an unfortunate way (e.g. as zeros) could hide underlying problems with
the `rrule`. 
```
xs = (3.33, -7.77)
ȳs = (rand(), rand(), rand())
x̄s = (rand(), rand())
rrule_test(two2three, ȳs, (xs[1], x̄s[1]), (xs[2], x̄s[2]))
```

## Scalar example

For functions with a single argument and a single output, such as e.g. `ReLU`,
```
function relu(x::Real)
    return max(0, x)
end
```
with the `frule`
```
function ChainRulesCore.frule((Δf, Δx), ::typeof(relu), x::Real)
    y = relu(x)
    dydx = x <= 0 ? zero(x) : one(x)
    return y, dydx .* Δx
end
```
and `rrule` defined,
```
function ChainRulesCore.rrule(::typeof(relu), x::Real)
    y = relu(x)
    dydx = x <= 0 ? zero(x) : one(x)
    function relu_pullback(Ȳ)
        return (NO_FIELDS, Ȳ .* dydx)
    end
    return y, relu_pullback
end
```

`test_scalar` function is provided to test both the `frule` and the `rrule` with a single
call.
```
test_scalar(relu, 0.5)
test_scalar(relu, -0.5)
```


# API Documentation

```@autodocs
Modules = [ChainRulesTestUtils]
Private = false
```
