using ChainRulesCore
using ChainRulesTestUtils
using ChainRulesTestUtils: rand_tangent
using FiniteDifferences
using LinearAlgebra
using MetaTesting
using Random
using Test

# in these meta tests, we always want to use `@inferred`
ChainRulesTestUtils.TEST_INFERRED[] = true

@testset "ChainRulesTestUtils.jl" begin
    include("iterator.jl")
    include("check_result.jl")
    include("testers.jl")
    include("data_generation.jl")
    include("rand_tangent.jl")
    include("rule_config.jl")

    include("global_checks.jl")
end
