@testset "Data Generation" begin
    @testset "Generate Well Conditioned Matrix - RNG" begin
        rng = MersenneTwister(1)
        matrix = generate_well_conditioned_matrix(rng, 5)

        @test isempty(matrix) == false
    end

    @testset "Generate Well Conditioned Matrix - Global RNG" begin
        matrix = generate_well_conditioned_matrix(5)

        @test isempty(matrix) == false
    end
end