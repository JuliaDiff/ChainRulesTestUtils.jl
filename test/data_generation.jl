@testset "Data Generation" begin
    function _is_well_conditioned(matrix)
        @test !isempty(matrix)
        @test isposdef(matrix)
        @assert length(matrix) ≤ 25
        @test cond(matrix) < 100
    end


    @testset "Generate Well Conditioned Matrix" begin
        rng = MersenneTwister(1)
        @testset "Pass in RNG" begin
            matrix = generate_well_conditioned_matrix(rng, 5)
            _is_well_conditioned(matrix)
            @testset "$T" for T in (Float64, ComplexF64)
                matrix = generate_well_conditioned_matrix(rng, T, 5)
                _is_well_conditioned(matrix)
            end
        end

        @testset "Global RNG" begin
            matrix = generate_well_conditioned_matrix(5)
            _is_well_conditioned(matrix)
            @testset "$T" for T in (Float64, ComplexF64)
                matrix = generate_well_conditioned_matrix(T, 5)
            end
        end
    end
end
