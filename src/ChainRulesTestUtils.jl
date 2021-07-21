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

export TestIterator
export test_approx, test_scalar, test_frule, test_rrule, generate_well_conditioned_matrix
export ⊢
export @maybe_inferred

__init__() = init_test_inferred_setting!()

include("global_config.jl")

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
