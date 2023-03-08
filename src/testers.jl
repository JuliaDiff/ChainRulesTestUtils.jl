"""
    test_scalar(f, z; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), check_inferred=true, kwargs...)

Given a function `f` with scalar input and scalar output, perform finite differencing checks,
at input point `z` to confirm that there are correct `frule` and `rrule`s provided.

# Arguments
- `f`: function for which the `frule` and `rrule` should be tested.
- `z`: input at which to evaluate `f` (should generally be set to an arbitrary point in the domain).

# Keyword Arguments
- `fdm`: the finite differencing method to use.
- `fkwargs` are passed to `f` as keyword arguments.
- If `check_inferred=true`, then the inferrability (type-stability) of the `frule` and `rrule` are checked.
- `testset_name`: if provided, the name of the testset used to wrap the tests.
  Otherwise it is determined from the function and argument types.
- All remaining keyword arguments are passed to `isapprox`.
"""
function test_scalar(f, z; rtol=1e-9, atol=1e-9, fdm=_fdm, fkwargs=NamedTuple(), check_inferred=true, testset_name=nothing, kwargs...)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    rule_test_kwargs = (; rtol=rtol, atol=atol, fdm=fdm, fkwargs=fkwargs, check_inferred=check_inferred, kwargs...)
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)
    testset_name = isnothing(testset_name) ? "test_scalar: $f at $z" : testset_name

    @testset "$(testset_name)" begin
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
- `config`: defaults to `ChainRulesTestUtils.TestConfig`.
- `f`: function for which the `frule` should be tested. Its tangent can be provided using `f ⊢ ḟ`.
  (You can enter `⊢` via `\\vdash` + tab in the Julia REPL and supporting editors.)
- `args...`: either the primal args `x`, or primals and their tangents: `x ⊢ ẋ`
   - `x`: input at which to evaluate `f` (should generally be set to an arbitrary point in the domain).
   - `ẋ`: differential w.r.t. `x`; will be generated automatically if not provided.
   Non-differentiable arguments, such as indices, should have `ẋ` set as `NoTangent()`.

# Keyword Arguments
   - `output_tangent`: tangent against which to test accumulation of derivatives.
     Should be a differential for the output of `f`. Is set automatically if not provided.
   - `fdm::FiniteDifferenceMethod`: the finite differencing method to use.
   - `frule_f=frule`: function with an `frule`-like API that is tested (defaults to
     `frule`). Used for testing gradients from AD systems.
   - If `check_inferred=true`, then the inferrability (type-stability) of the `frule` is checked,
     as long as `f` is itself inferrable.
   - `fkwargs` are passed to `f` as keyword arguments.
- `testset_name`: if provided, the name of the testset used to wrap the tests.
  Otherwise it is determined from the function and argument types.
   - All remaining keyword arguments are passed to `isapprox`.
"""
function test_frule(args...; kwargs...)
    test_frule(TestConfig(), args...; kwargs...)
end

function test_frule(
    config::RuleConfig,
    f,
    args...;
    output_tangent=Auto(),
    fdm=_fdm,
    frule_f=ChainRulesCore.frule,
    check_inferred::Bool=true,
    fkwargs::NamedTuple=NamedTuple(),
    rtol::Real=1e-9,
    atol::Real=1e-9,
    testset_name=nothing,
    kwargs...,
)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)
    testset_name = isnothing(testset_name) ? "test_frule: $f on $(_string_typeof(args))" : testset_name
    # and define a helper closure
    call_on_copy(f, xs...) = deepcopy(f)(deepcopy(xs)...; deepcopy(fkwargs)...)

    @testset "$(testset_name)" begin

        primals_and_tangents = auto_primal_and_tangent.((f, args...))
        primals = primal.(primals_and_tangents)
        tangents = tangent.(primals_and_tangents)

        if check_inferred && _is_inferrable(deepcopy(primals)...; deepcopy(fkwargs)...)
            _test_inferred(frule_f, deepcopy(config), deepcopy(tangents), deepcopy(primals)...; deepcopy(fkwargs)...)
        end

        res = call_on_copy(frule_f, config, tangents, primals...)
        res === nothing && throw(MethodError(frule_f, Tuple{Core.Typeof.(primals)...}))
        @test_msg "The frule should return (y, ∂y), not $res." res isa Tuple{Any,Any}
        Ω_ad, dΩ_ad = res
        Ω = call_on_copy(primals...)
        test_approx(Ω_ad, Ω; isapprox_kwargs...)

        # Correctness testing via finite differencing.
        is_ignored = isa.(tangents, NoTangent)
        dΩ_fd = _make_jvp_call(fdm, call_on_copy, Ω, primals, tangents, is_ignored)
        test_approx(dΩ_ad, dΩ_fd; isapprox_kwargs...)

        acc = output_tangent isa Auto ? rand_tangent(Ω) : output_tangent
        _test_add!!_behaviour(acc, dΩ_ad; isapprox_kwargs...)
    end  # top-level testset
end

"""
    test_rrule([config::RuleConfig,] f, args...; kwargs...)

# Arguments
- `config`: defaults to `ChainRulesTestUtils.TestConfig`.
- `f`: function for which the `rrule` should be tested. Its tangent can be provided using `f ⊢ f̄`.
  (You can enter `⊢` via `\\vdash` + tab in the Julia REPL and supporting editors.)
- `args...`: either the primal args `x`, or primals and their tangents: `x ⊢ x̄`
    - `x`: input at which to evaluate `f` (should generally be set to an arbitrary point in the domain).
    - `x̄`: currently accumulated cotangent; will be generated automatically if not provided.
    Non-differentiable arguments, such as indices, should have `x̄` set as `NoTangent()`.

# Keyword Arguments
 - `output_tangent`: the seed to propagate backward for testing (technically a cotangent).
   should be a differential for the output of `f`. Is set automatically if not provided.
 - `check_thunked_output_tangent=true`: also checks that passing a thunked version of the 
    output tangent to the pullback returns the same result.
 - `fdm::FiniteDifferenceMethod`: the finite differencing method to use.
 - `rrule_f=rrule`: function with an `rrule`-like API that is tested (defaults to `rrule`).
   Used for testing gradients from AD systems.
 - If `check_inferred=true`, then the inferrability (type-stability) of the `rrule` is checked
   — if `f` is itself inferrable — along with the inferrability of the pullback it returns.
 - `fkwargs` are passed to `f` as keyword arguments.
- `testset_name`: if provided, the name of the testset used to wrap the tests.
  Otherwise it is determined from the function and argument types.
 - All remaining keyword arguments are passed to `isapprox`.
"""
function test_rrule(args...; kwargs...)
    test_rrule(TestConfig(), args...; kwargs...)
end

function test_rrule(
    config::RuleConfig,
    f,
    args...;
    output_tangent=Auto(),
    check_thunked_output_tangent=true,
    fdm=_fdm,
    rrule_f=ChainRulesCore.rrule,
    check_inferred::Bool=true,
    fkwargs::NamedTuple=NamedTuple(),
    rtol::Real=1e-9,
    atol::Real=1e-9,
    testset_name=nothing,
    kwargs...,
)
    # To simplify some of the calls we make later lets group the kwargs for reuse
    isapprox_kwargs = (; rtol=rtol, atol=atol, kwargs...)
    testset_name = isnothing(testset_name) ? "test_rrule: $f on $(_string_typeof(args))" : testset_name
    # and define helper closure over fkwargs
    call(f, xs...) = f(xs...; fkwargs...)

    @testset "$(testset_name)" begin

        # Check correctness of evaluation.
        primals_and_tangents = auto_primal_and_tangent.((f, args...))
        primals = primal.(primals_and_tangents)
        accum_cotangents = tangent.(primals_and_tangents)

        if check_inferred && _is_inferrable(primals...; fkwargs...)
            _test_inferred(rrule_f, config, primals...; fkwargs...)
        end
        res = rrule_f(config, primals...; fkwargs...)
        res === nothing && throw(MethodError(rrule_f, Tuple{Core.Typeof.(primals)...}))
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
        is_ignored = isa.(accum_cotangents, NoTangent)
        fd_cotangents = _make_j′vp_call(fdm, call, ȳ, primals, is_ignored)
        foreach(accum_cotangents, ad_cotangents, fd_cotangents) do args...
            _test_cotangent(args...; check_inferred=check_inferred, isapprox_kwargs...)
        end

        if check_thunked_output_tangent
            test_approx(ad_cotangents, pullback(@thunk(ȳ)), "pulling back a thunk:"; isapprox_kwargs...)
            check_inferred && _test_inferred(pullback, @thunk(ȳ))
        end
    end  # top-level testset
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

Simple wrapper for [`@maybe_inferred f(args...: kwargs...)`](@ref `@maybe_inferred`), avoiding the type-instability in not
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

"""
    _test_cotangent(accum_cotangent, ad_cotangent, fd_cotangent; kwargs...)

Check if the cotangent `ad_cotangent` from `rrule` is consistent with `accum_tangent` and
approximately equal to the cotangent `fd_cotangent` obtained with finite differencing.

If `accum_cotangent` is `NoTangent()`, i.e., the argument was marked as non-differentiable,
`ad_cotangent` and `fd_cotangent` should be `NoTangent()` as well.

# Keyword arguments
- If `check_inferred=true` (the default) and `ad_cotangent` is a thunk, then it is checked if
  its content can be inferred.
- All remaining keyword arguments are passed to `isapprox`.
"""
function _test_cotangent(
    accum_cotangent,
    ad_cotangent,
    fd_cotangent;
    check_inferred=true,
    kwargs...,
)
    ad_cotangent isa AbstractThunk && check_inferred && _test_inferred(unthunk, ad_cotangent)

    # The main test of the actual derivative being correct:
    test_approx(ad_cotangent, fd_cotangent; kwargs...)
    _test_add!!_behaviour(accum_cotangent, ad_cotangent; kwargs...)
end

# we marked the argument as non-differentiable
function _test_cotangent(::NoTangent, ad_cotangent, ::NoTangent; kwargs...)
    @test ad_cotangent isa NoTangent
end
function _test_cotangent(::NoTangent, ::ZeroTangent, ::NoTangent; kwargs...)
    error(
        "The pullback in the rrule should use NoTangent()" *
        " rather than ZeroTangent() for non-perturbable arguments."
    )
end
function _test_cotangent(
    ::NoTangent,
    ad_cotangent::ChainRulesCore.NotImplemented,
    ::NoTangent;
    kwargs...,
)
    # this situation can occur if a cotangent is not implemented and
    # the default `rand_tangent` is `NoTangent`: e.g. due to having no fields
    # the `@test_broken` below should tell them that there is an easy implementation for
    # this case of `NoTangent()` (`@test_broken false` would be less useful!)
    # https://github.com/JuliaDiff/ChainRulesTestUtils.jl/issues/217
    @test_broken ad_cotangent isa NoTangent
end
function _test_cotangent(::NoTangent, ad_cotangent, fd_cotangent; kwargs...)
    error("cotangent obtained with finite differencing has to be NoTangent()")
end
