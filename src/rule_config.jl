# For testing this config uses finite differences to evaluate the frule and rrule
struct TestConfig <: RuleConfig{Union{HasReverseMode, HasForwardsMode}}
    fdm
end
TestConfig() = TestConfig(central_fdm(5, 1))

function ChainRulesCore.frule_via_ad(config::TestConfig, ȧrgs, f, args...; kws...)

    # try using a rule
    ret = frule(config, ȧrgs, f, args...; kws...)
    ret === nothing || return ret

    # but if the rule doesn't exist, use finite differencing instead
    call_on_copy(f, xs...) = deepcopy(f)(deepcopy(xs)...; deepcopy(kws)...)

    primals = (f, args...)
    is_ignored = isa.(ȧrgs, NoTangent)

    Ω = call_on_copy(f, args...)
    ΔΩ = _make_jvp_call(config.fdm, call_on_copy, Ω, primals, ȧrgs, is_ignored)

    return Ω, ΔΩ
end

function ChainRulesCore.rrule_via_ad(config::TestConfig, f, args...; kws...)

    # try using a rule
    ret = rrule(config, f, args...; kws...)
    ret === nothing || return ret

    # but if the rule doesn't exist, use finite differencing instead
    call(f, xs...) = f(xs...; kws...)

    # this block is here just to work out which tangents should be ignored
    primals = (f, args...)
    primals_and_tangents = auto_primal_and_tangent.(primals)
    is_ignored = isa.(tangent.(primals_and_tangents), NoTangent)

    function f_pb(ȳ)
        return _make_j′vp_call(config.fdm, call, ȳ, primals, is_ignored)
    end

    return call(f, args...), f_pb
end
