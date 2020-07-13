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
    function f2(sigargs...)
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
            @test isapprox(
                frule((Zero(), real(Δx)), f, z; fkwargs...)[2],
                frule((Zero(), Δx), f, z; fkwargs...)[2],
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
            back = rrule(f, z)[2]
            @test isapprox(
                extern(back(real(Δu))[2]),
                extern(back(Δu)[2]),
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
    Ω_ad, dΩ_ad = frule((NO_FIELDS, ẋs...), f, xs...; fkwargs...)
    Ω = f(xs...; fkwargs...)
    # if equality check fails, check approximate equality
    # use collect so can do vector equality
    # TODO: add isapprox replacement that works for more types
    @test Ω_ad == Ω || isapprox(collect(Ω_ad), collect(Ω); rtol=rtol, atol=atol)

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
function rrule_test(f, ȳ, xx̄s::Tuple{Any, Any}...; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), kwargs...)
    _ensure_not_running_on_functor(f, "rrule_test")

    # Check correctness of evaluation.
    xs, x̄s = collect(zip(xx̄s...))
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

    x̄s_is_dne = x̄s .== nothing
    # Correctness testing via finite differencing.
    x̄s_fd = _make_fdm_call(fdm, (xs...) -> f(xs...; fkwargs...), ȳ, xs, x̄s_is_dne)
    for (x̄_ad, x̄_fd) in zip(x̄s_ad, x̄s_fd)
        if x̄_fd === nothing
            # The way we've structured the above, this tests the propagator is returning a DoesNotExist
            @test x̄_ad isa DoesNotExist
        else
            @test isapprox(x̄_ad, x̄_fd; rtol=rtol, atol=atol, kwargs...)
        end
    end

    if count(!, x̄s_is_dne) == 1
        # for functions with pullbacks that only produce a single non-DNE adjoint, that
        # single adjoint should not be `Thunk`ed. InplaceableThunk is fine.
        i = findfirst(!, x̄s_is_dne)
        @test !(isa(x̄s_ad[i], Thunk))
    end
end
