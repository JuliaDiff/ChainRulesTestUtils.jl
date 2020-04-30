@testset "Data Generation" begin
    @testset "Generate Well Conditioned Matrix" begin
        @testset "Pass in RNG" begin
            rng = MersenneTwister(1)
            matrix = generate_well_conditioned_matrix(rng, 5)

            @test !isempty(matrix)
            @test isposdef(matrix)
        end

        @testset "Global RNG" begin
            matrix = generate_well_conditioned_matrix(5)

            @test !isempty(matrix)
            @test isposdef(matrix)
        end
    end
end