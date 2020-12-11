module ChainRulesTestUtils

using ChainRulesCore
using ChainRulesCore: frule, rrule
using Compat: only
using FiniteDifferences
using FiniteDifferences: to_vec
using LinearAlgebra
using Random
using Test

const _fdm = central_fdm(5, 1)

export TestIterator
export test_scalar, frule_test, rrule_test, generate_well_conditioned_matrix

include("generate_tangent.jl")
include("data_generation.jl")
include("iterator.jl")
include("check_result.jl")
include("testers.jl")

include("deprecated.jl")
end # module
