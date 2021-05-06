using ChainRulesCore
using ChainRulesTestUtils
using LinearAlgebra
using Random
using Test

@testset "ChainRulesTestUtils.jl" begin
    include("meta_testing_tools.jl")
    include("iterator.jl")
    include("check_result.jl")
    include("testers.jl")
    include("data_generation.jl")

    include("deprecated.jl")
end
