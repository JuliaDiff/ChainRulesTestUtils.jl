@testset "isapprox" begin
    @testset "Composite{Tuple}" begin
        @testset "basic" begin
            x_tup = (1.5, 2.5, 3.5)
            x_comp = Composite{typeof(x_tup)}(x_tup...)
            @test x_comp ≈ x_tup
            @test x_tup ≈ x_comp
            @test x_comp ≈ x_comp

            @test_throws Exception x_comp ≈  collect(x_tup)
        end

        @testset "different types" begin
            # both of these are reasonable diffentials for the `Tuple{Int, Int}` primal
            @test Composite{Tuple{Int, Int}}(1f0, 2f0) ≈ Composite{Tuple{Int, Int}}(1.0, 2.0)

            D = Diagonal(randn(5))
            @test Composite{typeof(D)}(diag=D.diag) ≈ Composite{typeof(D)}(diag=D.diag)

            # But these have different primals so should not be equal
            @test !(Composite{Tuple{Int, Int}}(1.0, 2.0) ≈ Composite{Tuple{Float64, Float64}}(1.0, 2.0))
        end
    end
end
