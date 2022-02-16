# For testing this config re-dispatches Xrule_via_ad to Xrule without config argument
struct ADviaRuleConfig <: RuleConfig{Union{HasReverseMode, HasForwardsMode}} end

function ChainRulesCore.frule_via_ad(config::ADviaRuleConfig, ȧrgs, f, args...; kws...)
    ret = frule(config, ȧrgs, f, args...; kws...)
    # we don't support actually doing AD: the rule has to exist. lets give helpfulish error
    ret === nothing && throw(MethodError(frule, (ȧrgs, f, args...)))
    return ret
end

function ChainRulesCore.rrule_via_ad(config::ADviaRuleConfig, f, args...; kws...)
    ret = rrule(config, f, args...; kws...)
    # we don't support actually doing AD: the rule has to exist. lets give helpfulish error
    ret === nothing && throw(MethodError(rrule, (f, args...)))
    return ret
end

# For testing this config uses finite differences to evaluate the frule and rrule
struct ADviaFDConfig <: RuleConfig{Union{HasReverseMode, HasForwardsMode}}
    fdm
end

function ChainRulesCore.frule_via_ad(config::ADviaFDConfig, ȧrgs, f, args...; kws...)

    call_on_copy(f, xs...) = deepcopy(f)(deepcopy(xs)...; deepcopy(kws)...)

    primals = (f, args...)
    is_ignored = isa.(ȧrgs, NoTangent)

    Ω = call_on_copy(f, args...)
    ΔΩ = _make_jvp_call(config.fdm, call_on_copy, Ω, primals, ȧrgs, is_ignored)

    return Ω, ΔΩ
end

function ChainRulesCore.rrule_via_ad(config::ADviaFDConfig, f, args...; kws...)

    call(f, xs...) = f(xs...; kws...)

    primals_and_tangents = auto_primal_and_tangent.((f, args...))
    primals = primal.(primals_and_tangents)
    accum_cotangents = tangent.(primals_and_tangents)
    is_ignored = isa.(accum_cotangents, NoTangent)

    function f_pb(ȳ)
        return _make_j′vp_call(config.fdm, call, ȳ, primals, is_ignored)
    end

    return call(f, args...), f_pb
end
