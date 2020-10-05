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
        args[ind] = dx
    end
    return (args...,)
end

"""
    _make_jvp_call(fdm, f, xs, ẋs, ignores)

Call `FiniteDifferences.jvp`, with the option to ignore certain `xs`.

# Arguments
- `fdm::FiniteDifferenceMethod`: How to numerically differentiate `f`.
- `f`: The function to differentiate.
- `xs`: Inputs to `f`, such that `y = f(xs...)`.
- `ẋs`: The directional derivatives of `xs` w.r.t. some real number `t`.
- `ignores`: Collection of `Bool`s, the same length as `xs` and `ẋs`.
   If `ignores[i] === true`, then `ẋs[i]` is ignored for derivative estimation.

# Returns
- `Ω̇`: Derivative of output w.r.t. `t` estimated by finite differencing.
"""
function _make_jvp_call(fdm, f, xs, ẋs, ignores)
    f2 = _wrap_function(f, xs, ignores)

    ignores = collect(ignores)
    all(ignores) && return ntuple(_->nothing, length(xs))
    sigargs = zip(xs[.!ignores], ẋs[.!ignores])
    return jvp(fdm, f2, sigargs...)
end

"""
    test_scalar(f, z; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), kwargs...)

Given a function `f` with scalar input and scalar output, perform finite differencing checks,
at input point `z` to confirm that there are correct `frule` and `rrule`s provided.

# Arguments
- `f`: Function for which the `frule` and `rrule` should be tested.
- `z`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).

`fkwargs` are passed to `f` as keyword arguments.
All keyword arguments except for `fdm` and `fkwargs` are passed to `isapprox`.
"""
function test_scalar(f, z; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), kwargs...)
    _ensure_not_running_on_functor(f, "test_scalar")
    # z = x + im * y
    # Ω = u(x, y) + im * v(x, y)
    Ω = f(z; fkwargs...)

    # test jacobian using forward mode
    Δx = one(z)
    @testset "$f at $z, with tangent $Δx" begin
        # check ∂u_∂x and (if Ω is complex) ∂v_∂x via forward mode
        frule_test(f, (z, Δx); rtol=rtol, atol=atol, fdm=fdm, fkwargs=fkwargs, kwargs...)
        if z isa Complex
            # check that same tangent is produced for tangent 1.0 and 1.0 + 0.0im
            check_equal(
                frule((Zero(), real(Δx)), f, z; fkwargs...)[2]::Number,
                frule((Zero(), Δx), f, z; fkwargs...)[2]::Number,
                rtol=rtol,
                atol=atol,
                kwargs...,
            )
        end
    end
    if z isa Complex
        Δy = one(z) * im
        @testset "$f at $z, with tangent $Δy" begin
            # check ∂u_∂y and (if Ω is complex) ∂v_∂y via forward mode
            frule_test(f, (z, Δy); rtol=rtol, atol=atol, fdm=fdm, fkwargs=fkwargs, kwargs...)
        end
    end

    # test jacobian transpose using reverse mode
    Δu = one(Ω)
    @testset "$f at $z, with cotangent $Δu" begin
        # check ∂u_∂x and (if z is complex) ∂u_∂y via reverse mode
        rrule_test(f, Δu, (z, Δx); rtol=rtol, atol=atol, fdm=fdm, fkwargs=fkwargs, kwargs...)
        if Ω isa Complex
            # check that same cotangent is produced for cotangent 1.0 and 1.0 + 0.0im
            _, back = rrule(f, z)
            check_equal(
                back(real(Δu))[2],
                back(Δu)[2],
                rtol=rtol,
                atol=atol,
                kwargs...,
            )
        end
    end
    if Ω isa Complex
        Δv = one(Ω) * im
        @testset "$f at $z, with cotangent $Δv" begin
            # check ∂v_∂x and (if z is complex) ∂v_∂y via reverse mode
            rrule_test(f, Δv, (z, Δx); rtol=rtol, atol=atol, fdm=fdm, fkwargs=fkwargs, kwargs...)
        end
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
    Ω_ad, dΩ_ad = frule((NO_FIELDS, deepcopy(ẋs)...), f, deepcopy(xs)...; deepcopy(fkwargs)...)
    Ω = f(deepcopy(xs)...; deepcopy(fkwargs)...)
    # if equality check fails, check approximate equality
    # use collect so can do vector equality
    # TODO: add isapprox replacement that works for more types
    @test Ω_ad == Ω || isapprox(collect(Ω_ad), collect(Ω); rtol=rtol, atol=atol)

    ẋs_is_ignored = ẋs .== nothing
    # Correctness testing via finite differencing.
    dΩ_fd = _make_jvp_call(fdm, (xs...) -> f(deepcopy(xs)...; deepcopy(fkwargs)...), xs, ẋs, ẋs_is_ignored)
    @test isapprox(
        collect(extern.(dΩ_ad)),  # Use collect so can use vector equality
        collect(dΩ_fd);
        rtol=rtol,
        atol=atol,
        kwargs...
    )

    # No tangent is passed in to test accumlation, so generate one
    # See: https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/66
    acc = rand_tangent(Ω)
    _check_add!!_behavour(acc, dΩ_ad; rtol=rtol, atol=atol, kwargs...)
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
function rrule_test(f, ȳ, xx̄s::Tuple{Any, Any}...; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), kwargs...)
    _ensure_not_running_on_functor(f, "rrule_test")

    # Check correctness of evaluation.
    xs = first.(xx̄s)
    x̄s_acc = last.(xx̄s)
    y_ad, pullback = rrule(f, xs...; fkwargs...)
    y = f(xs...; fkwargs...)
    # if equality check fails, check approximate equality
    # use collect so can do vector equality
    # TODO: add isapprox replacement that works for more types
    @test y_ad == y || isapprox(collect(y_ad), collect(y); rtol=rtol, atol=atol)
    @assert !(isa(ȳ, Thunk))

    ∂s = pullback(ȳ)
    ∂self = ∂s[1]
    x̄s_ad = ∂s[2:end]
    @test ∂self === NO_FIELDS  # No internal fields

    x̄s_is_dne = x̄s_acc .== nothing
    # Correctness testing via finite differencing.
    x̄s_fd = _make_j′vp_call(fdm, (xs...) -> f(xs...; fkwargs...), ȳ, xs, x̄s_is_dne)
    for (x̄_acc, x̄_ad, x̄_fd) in zip(x̄s_acc, x̄s_ad, x̄s_fd)
        if  x̄_acc === nothing
            @assert x̄_fd === nothing  # this is how `_make_j′vp_call` works
            @test x̄_ad isa DoesNotExist  # we said it wasn't differentiable.
        else
            # The main test of the actual deriviative being correct:
            check_result(accumulated_x̄, x̄_ad, x̄_fd; rtol=rtol, atol=atol, kwargs...)
            _check_add!!_behavour(x̄_acc, x̄_ad; rtol=rtol, atol=atol, kwargs...)
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
