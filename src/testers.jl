function _ensure_not_running_on_functor(f, name)
    # if x itself is a Type, then it is a constructor, thus not a functor.
    # This also catchs UnionAll constructors which have a `:var` and `:body` fields
    f isa Type && return

    if fieldcount(typeof(f)) > 0
        throw(ArgumentError(
            "$name cannot be used on closures/functors (such as $f)"
        ))
    end
end


"""
    _make_fdm_call(fdm, f, ȳ, xs, ignores) -> Tuple

Call `FiniteDifferences.j′vp`, with the option to ignore certain `xs`.

# Arguments
- `fdm::FiniteDifferenceMethod`: How to numerically differentiate `f`.
- `f`: The function to differentiate.
- `ȳ`: adjoint w.r.t. output of `f`.
- `xs`: Inputs to `f`, such that `y = f(xs...)`.
- `ignores`: Collection of `Bool`s, the same length as `xs`.
  If `ignores[i] === true`, then `xs[i]` is ignored; `∂xs[i] === nothing`.

# Returns
- `∂xs::Tuple`: Derivatives estimated by finite differencing.
"""
function _make_fdm_call(fdm, f, ȳ, xs, ignores)
    sig = Expr(:tuple)
    call = Expr(:call, f)
    newxs = Any[]
    arginds = Int[]
    i = 1
    for (x, ignore) in zip(xs, ignores)
        if ignore
            push!(call.args, x)
        else
            push!(call.args, Symbol(:x, i))
            push!(sig.args, Symbol(:x, i))
            push!(newxs, x)
            push!(arginds, i)
        end
        i += 1
    end
    fdexpr = :(j′vp($fdm, $sig -> $call, $ȳ, $(newxs...)))
    fd = eval(fdexpr)
    args = Any[nothing for _ in 1:length(xs)]
    for (dx, ind) in zip(fd, arginds)
        args[ind] = dx
    end
    return (args...,)
end

"""
    test_scalar(f, x; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), kwargs...)

Given a function `f` with scalar input and scalar output, perform finite differencing checks,
at input point `x` to confirm that there are correct `frule` and `rrule`s provided.

# Arguments
- `f`: Function for which the `frule` and `rrule` should be tested.
- `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).

`fkwargs` are passed to `f` as keyword arguments.
All keyword arguments except for `fdm` and `fkwargs` are passed to `isapprox`.
"""
function test_scalar(f, x; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), kwargs...)
    _ensure_not_running_on_functor(f, "test_scalar")

    r_res = rrule(f, x; fkwargs...)
    f_res = frule((Zero(), 1), f, x; fkwargs...)
    @test r_res !== nothing  # Check the rule was defined
    @test f_res !== nothing
    r_fx, prop_rule = r_res
    f_fx, f_∂x = f_res
    @testset "$f at $x, $(nameof(rule))" for (rule, fx, ∂x) in (
        (rrule, r_fx, prop_rule(1)),
        (frule, f_fx, f_∂x)
    )
        @test fx == f(x; fkwargs...)  # Check we still get the normal value, right

        if rule == rrule
            ∂self, ∂x = ∂x
            @test ∂self === NO_FIELDS
        end
        @test isapprox(∂x, fdm(x -> f(x; fkwargs...), x); rtol=rtol, atol=atol, kwargs...)
    end
end

"""
    frule_test(f, (x, ẋ)...; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), kwargs...)

# Arguments
- `f`: Function for which the `frule` should be tested.
- `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
- `ẋ`: differential w.r.t. `x` (should generally be set randomly).

`fkwargs` are passed to `f` as keyword arguments.
All keyword arguments except for `fdm` and `fkwargs` are passed to `isapprox`.
"""
function frule_test(f, xẋs::Tuple{Any, Any}...; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), kwargs...)
    _ensure_not_running_on_functor(f, "frule_test")
    xs, ẋs = first.(xẋs), last.(xẋs)
    Ω, dΩ_ad = frule((NO_FIELDS, ẋs...), f, xs...; fkwargs...)
    @test f(xs...; fkwargs...) == Ω

    # Correctness testing via finite differencing.
    dΩ_fd = jvp(fdm, xs->f(xs...; fkwargs...), (xs, ẋs))
    @test isapprox(
        collect(extern.(dΩ_ad)),  # Use collect so can use vector equality
        collect(dΩ_fd);
        rtol=rtol,
        atol=atol,
        kwargs...
    )
end


"""
    rrule_test(f, ȳ, (x, x̄)...; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), kwargs...)

# Arguments
- `f`: Function to which rule should be applied.
- `ȳ`: adjoint w.r.t. output of `f` (should generally be set randomly).
  Should be same structure as `f(x)` (so if multiple returns should be a tuple)
- `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
- `x̄`: currently accumulated adjoint (should generally be set randomly).

`fkwargs` are passed to `f` as keyword arguments.
All keyword arguments except for `fdm` and `fkwargs` are passed to `isapprox`.
"""
function rrule_test(f, ȳ, (x, x̄)::Tuple{Any, Any}; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), kwargs...)
    _ensure_not_running_on_functor(f, "rrule_test")

    # Check correctness of evaluation.
    fx, pullback = rrule(f, x; fkwargs...)
    @test collect(fx) ≈ collect(f(x; fkwargs...))  # use collect so can do vector equality
    (∂self, x̄_ad) = if fx isa Tuple
        # If the function returned multiple values,
        # then it must have multiple seeds for propagating backwards
        pullback(ȳ...)
    else
        pullback(ȳ)
    end

    @test ∂self === NO_FIELDS  # No internal fields
    # Correctness testing via finite differencing.
    x̄_fd = only(j′vp(fdm, x -> f(x; fkwargs...), ȳ, x))  # j′vp returns a tuple, but `f` is a unary function.
    @test isapprox(x̄_ad, x̄_fd; rtol=rtol, atol=atol, kwargs...)
end

# case where `f` takes multiple arguments
function rrule_test(f, ȳ, xx̄s::Tuple{Any, Any}...; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), kwargs...)
    _ensure_not_running_on_functor(f, "rrule_test")

    # Check correctness of evaluation.
    xs, x̄s = collect(zip(xx̄s...))
    y, pullback = rrule(f, xs...; fkwargs...)
    @test f(xs...; fkwargs...) == y

    @assert !(isa(ȳ, Thunk))
    ∂s = pullback(ȳ)
    ∂self = ∂s[1]
    x̄s_ad = ∂s[2:end]
    @test ∂self === NO_FIELDS

    # Correctness testing via finite differencing.
    x̄s_fd = _make_fdm_call(fdm, (xs...) -> f(xs...; fkwargs...), ȳ, xs, x̄s .== nothing)
    for (x̄_ad, x̄_fd) in zip(x̄s_ad, x̄s_fd)
        if x̄_fd === nothing
            # The way we've structured the above, this tests the propagator is returning a DoesNotExist
            @test x̄_ad isa DoesNotExist
        else
            @test isapprox(x̄_ad, x̄_fd; rtol=rtol, atol=atol, kwargs...)
        end
    end
end
