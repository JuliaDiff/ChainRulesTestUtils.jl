@testset "check_result.jl" begin
    @testset "_check_add!!_behavour" begin
        check = ChainRulesTestUtils._check_add!!_behavour

        check(10.0, 2.0)
        check(11.0, Zero())
        check([10.0, 20.0],  @thunk([2.0, 0.0]))

        # These `InplaceableThunk`s aren't actually inplace, but that's ok.
        check(12.0, InplaceableThunk(@thunk(2.0), X̄ -> X̄ + 2.0))

        @test fails(()->check(12.0, InplaceableThunk(@thunk(2.0), X̄ -> X̄ + 3.0)))

        check([10.0, 20.0], InplaceableThunk(
            @thunk([2.0, 0.0]),
            X̄ -> (X̄[1] += 2.0; X̄)
        ))
        @test fails(()->check([10.0, 20.0], InplaceableThunk(
            @thunk([2.0, 0.0]),
            X̄ -> (X̄[1] += 3.0; X̄),
        )))
    end
end
