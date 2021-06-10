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

    @testset "test_scalar: $f at $z" begin
        # z = x + im * y
        # Ω = u(x, y) + im * v(x, y)
        Ω = f(z; fkwargs...)

        # test jacobian using forward mode
        Δx = one(z)
        @testset "with tangent $Δx" begin
            # check ∂u_∂x and (if Ω is complex) ∂v_∂x via forward mode
            test_frule(f, z ⊢ Δx; rule_test_kwargs...)
            if z isa Complex
                # check that same tangent is produced for tangent 1.0 and 1.0 + 0.0im
                ḟ = rand_tangent(f)
                _, real_tangent = frule((ḟ, real(Δx)), f, z; fkwargs...)
                _, embedded_tangent = frule((ḟ, Δx), f, z; fkwargs...)
                test_approx(real_tangent, embedded_tangent; isapprox_kwargs...)
            end
        end
        if z isa Complex
            Δy = one(z) * im
            @testset "with tangent $Δy" begin
                # check ∂u_∂y and (if Ω is complex) ∂v_∂y via forward mode
                test_frule(f, z ⊢ Δy; rule_test_kwargs...)
            end
        end

        # test jacobian transpose using reverse mode
        Δu = one(Ω)
        @testset "with cotangent $Δu" begin
            # check ∂u_∂x and (if z is complex) ∂u_∂y via reverse mode
            test_rrule(f, z ⊢ Δx; output_tangent=Δu, rule_test_kwargs...)
            if Ω isa Complex
                # check that same cotangent is produced for cotangent 1.0 and 1.0 + 0.0im
                _, back = rrule(f, z)
                _, real_cotangent = back(real(Δu))
                _, embedded_cotangent = back(Δu)
                test_approx(real_cotangent, embedded_cotangent; isapprox_kwargs...)
            end
        end
        if Ω isa Complex
            Δv = one(Ω) * im
            @testset "with cotangent $Δv" begin
                # check ∂v_∂x and (if z is complex) ∂v_∂y via reverse mode
                test_rrule(f, z ⊢ Δx; output_tangent=Δv, rule_test_kwargs...)
            end
        end
    end  # top-level testset
end

"""
    test_frule(f, args..; kwargs...)

# Arguments
- `f`: Function for which the `frule` should be tested. Can also provide `f ⊢ ḟ`.
- `args` either the primal args `x`, or primals and their tangents: `x ⊢ ẋ`
   - `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
   - `ẋ`: differential w.r.t. `x`, will be generated automatically if not provided
   Non-differentiable arguments, such as indices, should have `ẋ` set as `NoTangent()`.

# Keyword Arguments
   - `output_tangent` tangent to test accumulation of derivatives against
     should be a differential for the output of `f`. Is set automatically if not provided.
   - `tangent_transforms=TRANSFORMS_TO_TEST_TANGENTS[]`: a vector of functions that transform
     the passed argument tangents into multiple tangents that should be tested.
   - `fdm::FiniteDifferenceMethod`: the finite differencing method to use.
   - If `check_inferred=true`, then the inferrability of the `frule` is checked,
     as long as `f` is itself inferrable.
   - `fkwargs` are passed to `f` as keyword arguments.
   - All remaining keyword arguments are passed to `isapprox`.
"""
function test_frule(
    f,
    args...;
    output_tangent=Auto(),
    tangent_transforms=TRANSFORMS_TO_TEST_TANGENTS[],
    fdm=_fdm,
    check_inferred::Bool=true,
    fkwargs::NamedTuple=NamedTuple(),
    rtol::Real=1e-9,
    atol::Real=1e-9,
    kwargs...,
)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)

    # and define a helper closure
    call_on_copy(f, xs...) = deepcopy(f)(deepcopy(xs)...; deepcopy(fkwargs)...)

    @testset "test_frule: $f on $(_string_typeof(args))" begin
        primals_and_tangents = auto_primal_and_tangent.((f, args...))
        primals = primal.(primals_and_tangents)
        tangents = tangent.(primals_and_tangents)

        @testset "for ȧrgs $(_string_typeof(tsf.(tangents)))" for tsf in tangent_transforms
            these_tangents = tsf.(tangents)

            if check_inferred && _is_inferrable(deepcopy(primals)...; deepcopy(fkwargs)...)
                _test_inferred(frule, deepcopy(these_tangents), deepcopy(primals)...; deepcopy(fkwargs)...)
            end

            res = frule(deepcopy(these_tangents), deepcopy(primals)...; deepcopy(fkwargs)...)
            res === nothing && throw(MethodError(frule, typeof(primals)))
            @test_msg "The frule should return (y, ∂y), not $res." res isa Tuple{Any,Any}
            Ω_ad, dΩ_ad = res
            Ω = call_on_copy(primals...)
            test_approx(Ω_ad, Ω; isapprox_kwargs...)

            # TODO: remove Nothing when https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/113
            is_ignored = isa.(these_tangents, Union{Nothing,NoTangent})
            if any(these_tangents .== nothing)
                Base.depwarn(
                    "test_frule(f, k ⊢ nothing) is deprecated, use " *
                    "test_frule(f, k ⊢ NoTangent()) instead for non-differentiable ks",
                    :test_frule,
                )
            end

            # Correctness testing via finite differencing.
            dΩ_fd = _make_jvp_call(fdm, call_on_copy, Ω, primals, these_tangents, is_ignored)
            test_approx(dΩ_ad, dΩ_fd; isapprox_kwargs...)

            acc = output_tangent isa Auto ? rand_tangent(Ω) : output_tangent
            _test_add!!_behaviour(acc, dΩ_ad; rtol=rtol, atol=atol, kwargs...)
        end
    end  # top-level testset
end

"""
    test_rrule(f, args...; kwargs...)

# Arguments
- `f`: Function to which rule should be applied. Can also provide `f ⊢ f̄`.
- `args` either the primal args `x`, or primals and their tangents: `x ⊢ x̄`
    - `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
    - `x̄`: currently accumulated cotangent, will be generated automatically if not provided
    Non-differentiable arguments, such as indices, should have `x̄` set as `NoTangent()`.

# Keyword Arguments
 - `output_tangent` the seed to propagate backward for testing (technically a cotangent).
   should be a differential for the output of `f`. Is set automatically if not provided.
 - `cotangent_transforms=TRANSFORMS_TO_TEST_TANGENTS[]`: a vector of functions that transform
   the passed tangent into multiple tangents that should be tested.
 - `fdm::FiniteDifferenceMethod`: the finite differencing method to use.
 - If `check_inferred=true`, then the inferrability of the `rrule` is checked
   — if `f` is itself inferrable — along with the inferrability of the pullback it returns.
 - `fkwargs` are passed to `f` as keyword arguments.
 - All remaining keyword arguments are passed to `isapprox`.
"""
function test_rrule(
    f,
    args...;
    output_tangent=Auto(),
    cotangent_transforms=TRANSFORMS_TO_TEST_TANGENTS[],
    fdm=_fdm,
    check_inferred::Bool=true,
    fkwargs::NamedTuple=NamedTuple(),
    rtol::Real=1e-9,
    atol::Real=1e-9,
    kwargs...,
)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)

    # and define helper closure over fkwargs
    call(f, xs...) = f(xs...; fkwargs...)

    @testset "test_rrule: $f on $(_string_typeof(args))" begin
        primals_and_tangents = auto_primal_and_tangent.((f, args...))
        primals = primal.(primals_and_tangents)
        accum_cotangents = tangent.(primals_and_tangents)

        if check_inferred && _is_inferrable(primals...; fkwargs...)
            _test_inferred(rrule, primals...; fkwargs...)
        end

        res = rrule(primals...; fkwargs...)
        res === nothing && throw(MethodError(rrule, typeof((primals...))))
        y_ad, pullback = res
        y = call(primals...)
        test_approx(y_ad, y; isapprox_kwargs...)  # make sure primal is correct

        ȳ = output_tangent isa Auto ? rand_tangent(y) : output_tangent

        # Correctness testing via finite differencing.
        # TODO: remove Nothing when https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/113
        is_ignored = isa.(accum_cotangents, Union{Nothing, NoTangent})
        if any(accum_cotangents .== nothing)
            Base.depwarn(
                "test_rrule(f, k ⊢ nothing) is deprecated, use " *
                "test_rrule(f, k ⊢ NoTangent()) instead for non-differentiable ks",
                :test_rrule,
            )
        end

        # loop over the possible cotangents
        for cotangent_transform in cotangent_transforms
            new_ȳ = cotangent_transform(ȳ)
            fd_cotangents = _make_j′vp_call(fdm, call, new_ȳ, primals, is_ignored)

            _test_cotangents(
                primals, pullback, new_ȳ, fd_cotangents, accum_cotangents;
                check_inferred=check_inferred, isapprox_kwargs...
            )
        end
    end  # top-level testset
end

function _test_cotangents(primals, pullback, ȳ, fd_cotangents, accum_cotangents; check_inferred, isapprox_kwargs...)

    @testset "ȳ=$(_string_typeof(ȳ))" begin
        check_inferred && _test_inferred(pullback, ȳ)

        ad_cotangents = pullback(ȳ)
        ad_cotangents isa Tuple || error("The pullback must return (∂self, ∂args...), not $ad_cotangents.")
        msg = "The pullback should return 1 cotangent for the primal and each primal input."
        @test_msg msg length(ad_cotangents) == length(primals)

        for (accum_cotangent, ad_cotangent, fd_cotangent) in zip(
            accum_cotangents, ad_cotangents, fd_cotangents
        )
            if accum_cotangent isa Union{Nothing,NoTangent}  # then we marked this argument as not differentiable # TODO remove once #113
                @assert fd_cotangent === nothing  # this is how `_make_j′vp_call` works
                ad_cotangent isa ZeroTangent && error(
                    "The pullback in the rrule should use NoTangent()" *
                    " rather than ZeroTangent() for non-perturbable arguments.",
                )
                @test ad_cotangent isa NoTangent  # we said it wasn't differentiable.
            else
                ad_cotangent isa AbstractThunk && check_inferred && _test_inferred(unthunk, ad_cotangent)

                # The main test of the actual derivative being correct:
                test_approx(ad_cotangent, fd_cotangent; isapprox_kwargs...)
                _test_add!!_behaviour(accum_cotangent, ad_cotangent; isapprox_kwargs...)
            end
        end

        check_thunking_is_appropriate(ad_cotangents)
    end
end

function check_thunking_is_appropriate(x̄s)
    num_zeros = count(x -> x isa AbstractZero, x̄s)
    num_thunks = count(x -> x isa Thunk, x̄s)
    if num_zeros + num_thunks == length(x̄s)
        # num_thunks can be either 0, or greater than 1.
        @test_msg "Should not thunk only non_zero argument" num_thunks != 1
    end
end

"""
    @maybe_inferred [Type] f(...)

Like `@inferred`, but does not check the return type if tests are run as part of PkgEval or
if the environment variable `CHAINRULES_TEST_INFERRED` is set to `false`.
"""
macro maybe_inferred(ex...)
    inferred = Expr(:macrocall, GlobalRef(Test, Symbol("@inferred")), __source__, ex...)
    return :(TEST_INFERRED[] ? $(esc(inferred)) : $(esc(last(ex))))
end

"""
    _test_inferred(f, args...; kwargs...)

Simple wrapper for `@inferred f(args...: kwargs...)`, avoiding the type-instability in not
knowing how many `kwargs` there are.
"""
function _test_inferred(f, args...; kwargs...)
    if isempty(kwargs)
        @maybe_inferred f(args...)
    else
        @maybe_inferred f(args...; kwargs...)
    end
end

"""
    _is_inferrable(f, args...; kwargs...) -> Bool

Return whether the return type of `f(args...; kwargs...)` is inferrable.
"""
function _is_inferrable(f, args...; kwargs...)
    try
        _test_inferred(f, args...; kwargs...)
        return true
    catch ErrorException
        return false
    end
end
