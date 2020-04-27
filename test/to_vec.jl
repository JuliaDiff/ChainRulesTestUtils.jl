@testset "to_vec" begin
    @testset "Composite{Tuple}" begin
        @testset "basic" begin
            x_tup = (1.0, 2.0, 3.0)
            x_comp = Composite{typeof(x_tup)}(x_tup...)

            x_vec, from_vec = ChainRulesTestUtils.to_vec(x_comp)
            @test x_vec == collect(x_tup)
            x_regen = from_vec(x_vec)

            @test x_comp == x_regen
        end

        @testset "nested" begin
            x_inner = (2, 3)
            x_outer = (1, x_inner)
            x_comp = Composite{typeof(x_outer)}(1, Composite{typeof(x_inner)}(2, 3))

            x_vec, from_vec = ChainRulesTestUtils.to_vec(x_comp)
            x_regen = from_vec(x_vec)

            @test x_comp == x_regen
        end
    end
end
