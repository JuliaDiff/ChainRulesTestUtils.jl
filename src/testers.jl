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
    _wrap_function(f, xs, ignores)

Return a new version of `f`, `fnew`, that ignores some of the arguments `xs`.

# Arguments
- `f`: The function to be wrapped.
- `xs`: Inputs to `f`, such that `y = f(xs...)`.
- `ignores`: Collection of `Bool`s, the same length as `xs`.
  If `ignores[i] === true`, then `xs[i]` is ignored; `∂xs[i] === nothing`.
"""
function _wrap_function(f, xs, ignores)
    function fnew(sigargs...)
        callargs = Any[]
        j = 1

        for (i, (x, ignore)) in enumerate(zip(xs, ignores))
            if ignore
                push!(callargs, x)
            else
                push!(callargs, sigargs[j])
                j += 1
            end
        end
        @assert j == length(sigargs) + 1
        @assert length(callargs) == length(xs)
        return f(callargs...)
    end
    return fnew
end

"""
    _make_j′vp_call(fdm, f, ȳ, xs, ignores) -> Tuple

Call `FiniteDifferences.j′vp`, with the option to ignore certain `xs`.

# Arguments
- `fdm::FiniteDifferenceMethod`: How to numerically differentiate `f`.
- `f`: The function to differentiate.
- `ȳ`: The adjoint w.r.t. output of `f`.
- `xs`: Inputs to `f`, such that `y = f(xs...)`.
- `ignores`: Collection of `Bool`s, the same length as `xs`.
  If `ignores[i] === true`, then `xs[i]` is ignored; `∂xs[i] === nothing`.

# Returns
- `∂xs::Tuple`: Derivatives estimated by finite differencing.
"""
function _make_j′vp_call(fdm, f, ȳ, xs, ignores)
    f2 = _wrap_function(f, xs, ignores)

    ignores = collect(ignores)
    args = Any[nothing for _ in 1:length(xs)]
    all(ignores) && return (args...,)
    sigargs = xs[.!ignores]
    arginds = (1:length(xs))[.!ignores]
    fd = j′vp(fdm, f2, ȳ, sigargs...)
    @assert length(fd) == length(arginds)

    for (dx, ind) in zip(fd, arginds)
        args[ind] = _maybe_fix_to_composite(xs[ind], dx)
    end
    return (args...,)
end

"""
    _make_jvp_call(fdm, f, y, xs, ẋs, ignores)

Call `FiniteDifferences.jvp`, with the option to ignore certain `xs`.

# Arguments
- `fdm::FiniteDifferenceMethod`: How to numerically differentiate `f`.
- `f`: The function to differentiate.
- `y`: The primal output `y=f(xs...)` or at least something of the right type
- `xs`: Inputs to `f`, such that `y = f(xs...)`.
- `ẋs`: The directional derivatives of `xs` w.r.t. some real number `t`.
- `ignores`: Collection of `Bool`s, the same length as `xs` and `ẋs`.
   If `ignores[i] === true`, then `ẋs[i]` is ignored for derivative estimation.

# Returns
- `Ω̇`: Derivative of output w.r.t. `t` estimated by finite differencing.
"""
function _make_jvp_call(fdm, f, y, xs, ẋs, ignores)
    f2 = _wrap_function(f, xs, ignores)

    ignores = collect(ignores)
    all(ignores) && return ntuple(_->nothing, length(xs))
    sigargs = zip(xs[.!ignores], ẋs[.!ignores])
    return _maybe_fix_to_composite(y, jvp(fdm, f2, sigargs...))
end

# TODO: remove after https://github.com/JuliaDiff/FiniteDifferences.jl/issues/97
# For functions which return a tuple, FD returns a tuple to represent the differential. Tuple
# is not a natural differential, because it doesn't overload +, so make it a Composite.
_maybe_fix_to_composite(::P, x::Tuple) where {P} = Composite{P}(x...)
_maybe_fix_to_composite(::P, x::NamedTuple) where {P} = Composite{P}(;x...)
_maybe_fix_to_composite(::Any, x) = x

"""
    test_scalar(f, z; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), check_inferred=true, kwargs...)

Given a function `f` with scalar input and scalar output, perform finite differencing checks,
at input point `z` to confirm that there are correct `frule` and `rrule`s provided.

# Arguments
- `f`: Function for which the `frule` and `rrule` should be tested.
- `z`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).

`fkwargs` are passed to `f` as keyword arguments.
If `check_inferred=true`, then the type-stability of the `frule` and `rrule` are checked.
All remaining keyword arguments are passed to `isapprox`.
"""
function test_scalar(f, z; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), check_inferred=true, kwargs...)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    rule_test_kwargs = (; rtol=rtol, atol=atol, fdm=fdm, fkwargs=fkwargs, check_inferred=check_inferred, kwargs...)
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)

    _ensure_not_running_on_functor(f, "test_scalar")
    # z = x + im * y
    # Ω = u(x, y) + im * v(x, y)
    Ω = f(z; fkwargs...)

    # test jacobian using forward mode
    Δx = one(z)
    @testset "$f at $z, with tangent $Δx" begin
        # check ∂u_∂x and (if Ω is complex) ∂v_∂x via forward mode
        frule_test(f, (z, Δx); rule_test_kwargs...)
        if z isa Complex
            # check that same tangent is produced for tangent 1.0 and 1.0 + 0.0im
            _, real_tangent = frule((Zero(), real(Δx)), f, z; fkwargs...)
            _, embedded_tangent = frule((Zero(), Δx), f, z; fkwargs...)
            check_equal(real_tangent, embedded_tangent; isapprox_kwargs...)
        end
    end
    if z isa Complex
        Δy = one(z) * im
        @testset "$f at $z, with tangent $Δy" begin
            # check ∂u_∂y and (if Ω is complex) ∂v_∂y via forward mode
            frule_test(f, (z, Δy); rule_test_kwargs...)
        end
    end

    # test jacobian transpose using reverse mode
    Δu = one(Ω)
    @testset "$f at $z, with cotangent $Δu" begin
        # check ∂u_∂x and (if z is complex) ∂u_∂y via reverse mode
        rrule_test(f, Δu, (z, Δx); rule_test_kwargs...)
        if Ω isa Complex
            # check that same cotangent is produced for cotangent 1.0 and 1.0 + 0.0im
            _, back = rrule(f, z)
            _, real_cotangent = back(real(Δu))
            _, embedded_cotangent = back(Δu)
            check_equal(real_cotangent, embedded_cotangent; isapprox_kwargs...)
        end
    end
    if Ω isa Complex
        Δv = one(Ω) * im
        @testset "$f at $z, with cotangent $Δv" begin
            # check ∂v_∂x and (if z is complex) ∂v_∂y via reverse mode
            rrule_test(f, Δv, (z, Δx); rule_test_kwargs...)
        end
    end
end

"""
    _test_inferred(f, args...; kwargs...)

Simple wrapper for `@inferred f(args...: kwargs...)`, avoiding the type-instability in not
knowing how many `kwargs` there are.
"""
function _test_inferred(f, args...; kwargs...)
    if isempty(kwargs)
        @inferred f(args...)
    else
        @inferred f(args...; kwargs...)
    end
end

"""
    _is_typestable(f, args...; kwargs...) -> Bool

Return whether `f(args...; kwargs...)` is type-stable.
"""
function _is_typestable(f, args...; kwargs...)
    try
        _test_inferred(f, args...; kwargs...)
        return true
    catch ErrorException
        return false
    end
end

"""
    frule_test(f, (x, ẋ)...; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), check_inferred=true, kwargs...)

# Arguments
- `f`: Function for which the `frule` should be tested.
- `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
- `ẋ`: differential w.r.t. `x` (should generally be set randomly).

`fkwargs` are passed to `f` as keyword arguments.
If `check_inferred=true`, then the type-stability of the `frule` is checked.
All remaining keyword arguments are passed to `isapprox`.
"""
function frule_test(f, xẋs::Tuple{Any, Any}...; rtol::Real=1e-9, atol::Real=1e-9, fdm=_fdm, fkwargs::NamedTuple=NamedTuple(), check_inferred::Bool=true, kwargs...)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)

    _ensure_not_running_on_functor(f, "frule_test")

    xs = first.(xẋs)
    ẋs = last.(xẋs)
    check_inferred && _test_inferred(frule, (NO_FIELDS, deepcopy(ẋs)...), f, deepcopy(xs)...; deepcopy(fkwargs)...)
    res = frule((NO_FIELDS, deepcopy(ẋs)...), f, deepcopy(xs)...; deepcopy(fkwargs)...)
    res === nothing && throw(MethodError(frule, typeof((f, xs...))))
    Ω_ad, dΩ_ad = res
    Ω = f(deepcopy(xs)...; deepcopy(fkwargs)...)
    check_equal(Ω_ad, Ω; isapprox_kwargs...)

    ẋs_is_ignored = ẋs .== nothing
    # Correctness testing via finite differencing.
    dΩ_fd = _make_jvp_call(fdm, (xs...) -> f(deepcopy(xs)...; deepcopy(fkwargs)...), Ω, xs, ẋs, ẋs_is_ignored)
    check_equal(dΩ_ad, dΩ_fd; isapprox_kwargs...)


    # No tangent is passed in to test accumlation, so generate one
    # See: https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/66
    acc = rand_tangent(Ω)
    _check_add!!_behaviour(acc, dΩ_ad; rtol=rtol, atol=atol, kwargs...)
end


"""
    rrule_test(f, ȳ, (x, x̄)...; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), check_inferred=true, kwargs...)

# Arguments
- `f`: Function to which rule should be applied.
- `ȳ`: adjoint w.r.t. output of `f` (should generally be set randomly).
  Should be same structure as `f(x)` (so if multiple returns should be a tuple)
- `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
- `x̄`: currently accumulated adjoint (should generally be set randomly).

`fkwargs` are passed to `f` as keyword arguments.
If `check_inferred=true`, then the type-stability of the `rrule` and the pullback it
returns are checked.
All remaining keyword arguments are passed to `isapprox`.
"""
function rrule_test(f, ȳ, xx̄s::Tuple{Any, Any}...; rtol::Real=1e-9, atol::Real=1e-9, fdm=_fdm, check_inferred::Bool=true, fkwargs::NamedTuple=NamedTuple(), kwargs...)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)

    _ensure_not_running_on_functor(f, "rrule_test")

    # Check correctness of evaluation.
    xs = first.(xx̄s)
    accumulated_x̄ = last.(xx̄s)
    check_inferred && _test_inferred(rrule, f, xs...; fkwargs...)
    res = rrule(f, xs...; fkwargs...)
    res === nothing && throw(MethodError(rrule, typeof((f, xs...))))
    y_ad, pullback = res
    y = f(xs...; fkwargs...)
    check_equal(y_ad, y; isapprox_kwargs...)  # make sure primal is correct

    check_inferred && _test_inferred(pullback, ȳ)
    ∂s = pullback(ȳ)
    ∂self = ∂s[1]
    x̄s_ad = ∂s[2:end]
    @test ∂self === NO_FIELDS  # No internal fields

    # Correctness testing via finite differencing.
    x̄s_is_dne = accumulated_x̄ .== nothing
    x̄s_fd = _make_j′vp_call(fdm, (xs...) -> f(xs...; fkwargs...), ȳ, xs, x̄s_is_dne)
    for (accumulated_x̄, x̄_ad, x̄_fd) in zip(accumulated_x̄, x̄s_ad, x̄s_fd)
        if accumulated_x̄ === nothing  # then we marked this argument as not differentiable
            @assert x̄_fd === nothing  # this is how `_make_j′vp_call` works
            @test x̄_ad isa DoesNotExist  # we said it wasn't differentiable.
        else
            x̄_ad isa AbstractThunk && check_inferred && _test_inferred(unthunk, x̄_ad)

            # The main test of the actual deriviative being correct:
            check_equal(x̄_ad, x̄_fd; isapprox_kwargs...)
            _check_add!!_behaviour(accumulated_x̄, x̄_ad; isapprox_kwargs...)
        end
    end

    check_thunking_is_appropriate(x̄s_ad)
end

function check_thunking_is_appropriate(x̄s)
    @testset "Don't thunk only non_zero argument" begin
        num_zeros = count(x->x isa AbstractZero, x̄s)
        num_thunks = count(x->x isa Thunk, x̄s)
        if num_zeros + num_thunks == length(x̄s)
            @test num_thunks !== 1
        end
    end
end
