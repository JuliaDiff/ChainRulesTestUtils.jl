module ChainRulesTestUtils

using ChainRulesCore
using ChainRulesCore: frule, rrule
using Compat: only
using FiniteDifferences
using FiniteDifferences: to_vec
using LinearAlgebra
using Random
using Test

import FiniteDifferences: rand_tangent

const _fdm = central_fdm(5, 1; max_range=1e-2)
const TEST_INFERRED = Ref(true)
const TRANSFORMS_TO_ALT_TEST_TANGENTS = Ref{Vector{Function}}([])

export TestIterator
export test_approx, test_scalar, test_frule, test_rrule, generate_well_conditioned_matrix
export ⊢
export @maybe_inferred

function __init__()
    TEST_INFERRED[] = if haskey(ENV, "CHAINRULES_TEST_INFERRED")
        parse(Bool, "CHAINRULES_TEST_INFERRED")
    else
        !parse(Bool, get(ENV, "JULIA_PKGEVAL", "false"))
    end

    !TEST_INFERRED[] && @warn "inference tests have been disabled"
end

include("generate_tangent.jl")
include("data_generation.jl")
include("iterator.jl")

include("output_control.jl")
include("check_result.jl")

include("rule_config.jl")
include("finite_difference_calls.jl")
include("testers.jl")

include("deprecated.jl")
end # module
