module ChainRulesTestUtils

@nospecialize

using ChainRulesCore
using ChainRulesCore: frule, rrule
using Compat: only
using FiniteDifferences
using FiniteDifferences: to_vec
using LinearAlgebra
using Random
using Test
using Suppressor

export TestIterator
export test_approx, test_scalar, test_frule, test_rrule, generate_well_conditioned_matrix
export ⊢, rand_tangent
export @maybe_inferred
export test_method_tables

function __init__()
    init_test_inferred_setting!()

    # Try to disable backtrace scrubbing so that full failures are shown
    try
        isdefined(Test, :scrub_backtrace) || error("Test.scrub_backtrace not defined")
        @suppress begin  # mute warning about monkey-patching
            # depending on julia version or one or the other of these will be hit
            @eval Test scrub_backtrace(bt,) = bt  # make it do nothing
            @eval Test scrub_backtrace(bt, file_ts, file_t) = bt  # make it do nothing
        end
    catch err
        @warn "Failed to monkey=patch scrub_backtrace. Code is functional but stacktraces may be less useful" exception=(err, catch_backtrace())
    end
end

include("global_config.jl")

include("rand_tangent.jl")
include("generate_tangent.jl")
include("data_generation.jl")
include("iterator.jl")

include("output_control.jl")
include("check_result.jl")

include("rule_config.jl")
include("finite_difference_calls.jl")
include("testers.jl")

include("deprecated.jl")
include("global_checks.jl")
end # module

