@testset "Data Generation" begin
    function _is_well_conditioned(matrix::Array{Float64})
        @test !isempty(matrix)
        @test isposdef(matrix)
        @assert length(matrix) ≤ 25  
        @test cond(matrix) < 20
    end


    @testset "Generate Well Conditioned Matrix" begin
        @testset "Pass in RNG" begin
            rng = MersenneTwister(1)
            matrix = generate_well_conditioned_matrix(rng, 5)

            _is_well_conditioned(matrix)
        end

        @testset "Global RNG" begin
            matrix = generate_well_conditioned_matrix(5)

            _is_well_conditioned(matrix)
        end
    end
end
