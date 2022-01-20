using ChainRulesCore
using ChainRulesTestUtils
using ChainRulesTestUtils: rand_tangent
using FiniteDifferences
using LinearAlgebra
using Random
using Test

# in these meta tests, we always want to use `@inferred`
ChainRulesTestUtils.TEST_INFERRED[] = true

@testset "ChainRulesTestUtils.jl" begin
    include("meta_testing_tools.jl")
    include("iterator.jl")
    include("check_result.jl")
    include("testers.jl")
    include("data_generation.jl")
    include("rand_tangent.jl")

    include("method_checks.jl")
end
