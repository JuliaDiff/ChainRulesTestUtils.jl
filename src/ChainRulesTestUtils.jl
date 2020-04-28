module ChainRulesTestUtils

using ChainRulesCore
using ChainRulesCore: frule, rrule
using Compat: only
using FiniteDifferences
using FiniteDifferences: to_vec
using LinearAlgebra
using Test

const _fdm = central_fdm(5, 1)

export test_scalar, frule_test, rrule_test, generate_well_conditioned_matrix

include("to_vec.jl")
include("isapprox.jl")
include("data_generation.jl")
include("testers.jl")
end # module
