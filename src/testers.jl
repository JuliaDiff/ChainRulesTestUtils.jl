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
    test_frule([config::RuleConfig,] f, args..; kwargs...)

# Arguments
- `config`: defaults to `ChainRulesTestUtils.ADviaRuleConfig`.
- `f`: Function for which the `frule` should be tested. Can also provide `f ⊢ ḟ`.
- `args` either the primal args `x`, or primals and their tangents: `x ⊢ ẋ`
   - `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
   - `ẋ`: differential w.r.t. `x`, will be generated automatically if not provided
   Non-differentiable arguments, such as indices, should have `ẋ` set as `NoTangent()`.

# Keyword Arguments
   - `output_tangent` tangent to test accumulation of derivatives against
     should be a differential for the output of `f`. Is set automatically if not provided.
   - `tangent_transforms=TRANSFORMS_TO_ALT_TANGENTS`: a vector of functions that
      transform the passed argument tangents into alternative tangents that should be tested.
      Note that the alternative tangents are only tested for not erroring when passed to
      frule. Testing for correctness using finite differencing can be done using a
      separate `test_frule` call, e.g. for testing a `ZeroTangent()` for correctness:
      `test_frule(f, x ⊢ ZeroTangent(); tangent_transforms=[])`.
   - `fdm::FiniteDifferenceMethod`: the finite differencing method to use.
   - `frule_f=frule`: Function with an `frule`-like API that is tested (defaults to
     `frule`). Used for testing gradients from AD systems.
   - If `check_inferred=true`, then the inferrability of the `frule` is checked,
     as long as `f` is itself inferrable.
   - `fkwargs` are passed to `f` as keyword arguments.
   - All remaining keyword arguments are passed to `isapprox`.
"""
function test_frule(args...; kwargs...)
    config = ChainRulesTestUtils.ADviaRuleConfig()
    test_frule(config, args...; kwargs...)
end

function test_frule(
    config::RuleConfig,
    f,
    args...;
    output_tangent=Auto(),
    tangent_transforms=unique(TRANSFORMS_TO_ALT_TANGENTS),
    fdm=_fdm,
    frule_f=ChainRulesCore.frule,
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

        if check_inferred && _is_inferrable(deepcopy(primals)...; deepcopy(fkwargs)...)
            _test_inferred(frule_f, deepcopy(config), deepcopy(tangents), deepcopy(primals)...; deepcopy(fkwargs)...)
        end

        res = call_on_copy(frule_f, config, tangents, primals...)
        res === nothing && throw(MethodError(frule_f, typeof(primals)))
        @test_msg "The frule should return (y, ∂y), not $res." res isa Tuple{Any,Any}
        Ω_ad, dΩ_ad = res
        Ω = call_on_copy(primals...)
        test_approx(Ω_ad, Ω; isapprox_kwargs...)

        # TODO: remove Nothing when https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/113
        is_ignored = isa.(tangents, Union{Nothing,NoTangent})
        if any(tangents .== nothing)
            Base.depwarn(
                "test_frule(f, k ⊢ nothing) is deprecated, use " *
                "test_frule(f, k ⊢ NoTangent()) instead for non-differentiable ks",
                :test_frule,
            )
        end

        # Correctness testing via finite differencing.
        dΩ_fd = _make_jvp_call(fdm, call_on_copy, Ω, primals, tangents, is_ignored)
        test_approx(dΩ_ad, dΩ_fd; isapprox_kwargs...)

        acc = output_tangent isa Auto ? rand_tangent(Ω) : output_tangent
        _test_add!!_behaviour(acc, dΩ_ad; isapprox_kwargs...)

        # test that rules work for other tangents
        _test_frule_alt_tangents(
            call_on_copy, frule_f, config, tangent_transforms, tangents, primals, acc;
            isapprox_kwargs...
        )
    end  # top-level testset
end

function _test_frule_alt_tangents(
    call, frule_f, config, tangent_transforms, tangents, primals, acc;
    isapprox_kwargs...
)
    @testset "ȧrgs = $(_string_typeof(tsf.(tangents)))" for tsf in tangent_transforms
        _, dΩ = call(frule_f, config, tsf.(tangents), primals...)
        _test_add!!_behaviour(acc, dΩ; isapprox_kwargs...)
    end
end

"""
    test_rrule([config::RuleConfig,] f, args...; kwargs...)

# Arguments
- `config`: defaults to `ChainRulesTestUtils.ADviaRuleConfig`.
- `f`: Function to which rule should be applied. Can also provide `f ⊢ f̄`.
- `args` either the primal args `x`, or primals and their tangents: `x ⊢ x̄`
    - `x`: input at which to evaluate `f` (should generally be set to an arbitary point in the domain).
    - `x̄`: currently accumulated cotangent, will be generated automatically if not provided
    Non-differentiable arguments, such as indices, should have `x̄` set as `NoTangent()`.

# Keyword Arguments
 - `output_tangent` the seed to propagate backward for testing (technically a cotangent).
   should be a differential for the output of `f`. Is set automatically if not provided.
- `tangent_transforms=TRANSFORMS_TO_ALT_TANGENTS`: a vector of functions that
   transform the passed `output_tangent` into alternative tangents that should be tested.
   Note that the alternative tangents are only tested for not erroring when passed to
   rrule. Testing for correctness using finite differencing can be done using a
   separate `test_rrule` call, e.g. for testing a `ZeroTangent()` for correctness:
   `test_rrule(f, args...; output_tangent=ZeroTangent(), tangent_transforms=[])`.
 - `fdm::FiniteDifferenceMethod`: the finite differencing method to use.
 - `rrule_f=rrule`: Function with an `rrule`-like API that is tested (defaults to `rrule`).
   Used for testing gradients from AD systems.
 - If `check_inferred=true`, then the inferrability of the `rrule` is checked
   — if `f` is itself inferrable — along with the inferrability of the pullback it returns.
 - `fkwargs` are passed to `f` as keyword arguments.
 - All remaining keyword arguments are passed to `isapprox`.
"""
function test_rrule(args...; kwargs...)
    config = ChainRulesTestUtils.ADviaRuleConfig()
    test_rrule(config, args...; kwargs...)
end

function test_rrule(
    config::RuleConfig,
    f,
    args...;
    output_tangent=Auto(),
    tangent_transforms=unique(TRANSFORMS_TO_ALT_TANGENTS),
    fdm=_fdm,
    rrule_f=ChainRulesCore.rrule,
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

        # Check correctness of evaluation.
        primals_and_tangents = auto_primal_and_tangent.((f, args...))
        primals = primal.(primals_and_tangents)
        accum_cotangents = tangent.(primals_and_tangents)

        if check_inferred && _is_inferrable(primals...; fkwargs...)
            _test_inferred(rrule_f, config, primals...; fkwargs...)
        end
        res = rrule_f(config, primals...; fkwargs...)
        res === nothing && throw(MethodError(rrule_f, typeof(primals)))
        y_ad, pullback = res
        y = call(primals...)
        test_approx(y_ad, y; isapprox_kwargs...)  # make sure primal is correct

        ȳ = output_tangent isa Auto ? rand_tangent(y) : output_tangent

        check_inferred && _test_inferred(pullback, ȳ)
        ad_cotangents = pullback(ȳ)
        @test_msg(
            "The pullback must return a Tuple (∂self, ∂args...)",
            ad_cotangents isa Tuple
        )
        @test_msg(
            "The pullback should return 1 cotangent for the primal and each primal input.",
            length(ad_cotangents) == length(primals)
        )

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

        fd_cotangents = _make_j′vp_call(fdm, call, ȳ, primals, is_ignored)

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

        # test other tangents don't error when passed to the pullback
        _test_rrule_alt_tangents(pullback, tangent_transforms, ȳ, accum_cotangents)
    end  # top-level testset
end

function _test_rrule_alt_tangents(
    pullback, tangent_transforms, ȳ, accum_cotangents;
    isapprox_kwargs...
)
    @testset "ȳ = $(_string_typeof(tsf(ȳ)))" for tsf in tangent_transforms
        ad_cotangents = pullback(tsf(ȳ))
        for (accum_cotangent, ad_cotangent) in zip(accum_cotangents, ad_cotangents)
            _test_add!!_behaviour(accum_cotangent, ad_cotangent; isapprox_kwargs...)
        end
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
