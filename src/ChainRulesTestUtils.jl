module ChainRulesTestUtils

using ChainRulesCore
using ChainRulesCore: frule, rrule
using Compat: only
using FiniteDifferences
using FiniteDifferences: to_vec
using LinearAlgebra
using Random
using Test

const _fdm = central_fdm(5, 1; max_range=1e-2)

export TestIterator
export check_equal, test_scalar, test_frule, test_rrule, generate_well_conditioned_matrix
export Auto, ⟂


include("generate_tangent.jl")
include("data_generation.jl")
include("iterator.jl")
include("check_result.jl")

include("finite_difference_calls.jl")
include("testers.jl")

include("deprecated.jl")
end # module
