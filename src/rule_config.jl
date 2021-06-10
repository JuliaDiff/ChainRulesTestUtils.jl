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
