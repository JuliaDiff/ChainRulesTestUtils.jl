@testset "check_result.jl" begin
    @testset "_check_add!!_behavour" begin
        check = ChainRulesTestUtils._check_add!!_behavour

        check(10.0, 2.0)
        check(11.0, Zero())
        check([10.0, 20.0],  @thunk([2.0, 0.0]))

        check(12.0, InplaceableThunk(@thunk(2.0), X̄ -> error("Should not have in-placed")))

        check([10.0, 20.0], InplaceableThunk(
            @thunk([2.0, 0.0]),
            X̄ -> (X̄[1] += 2.0; X̄)
        ))
        @test fails(()->check([10.0, 20.0], InplaceableThunk(
            @thunk([2.0, 0.0]),
            X̄ -> (X̄[1] += 3.0; X̄),
        )))
    end


    @testset "_check_equal" begin
        check = ChainRulesTestUtils._check_equal

        @testset "possive cases" begin
            check(1.0, 1.0)
            check(1.0 + im, 1.0 + im)
            check(1.0, 1.0+1e-10)  # isapprox _behaviour
            check((1.5, 2.5, 3.5), (1.5, 2.5, 3.5 + 1e-10))

            check(Zero(), 0.0)

            check([1.0, 2.0], [1.0, 2.0])
            check([[1.0], [2.0]], [[1.0], [2.0]])

            check(@thunk(10*0.1*[[1.0], [2.0]]), [[1.0], [2.0]])

            check(
                Composite{Tuple{Float64, Float64}}(1.0, 2.0),
                Composite{Tuple{Float64, Float64}}(1.0, 2.0)
            )

            D = Diagonal(randn(5))
            check(
                Composite{typeof(D)}(diag=D.diag),
                Composite{typeof(D)}(diag=D.diag)
            )

            T = (a=1.0, b=2.0)
            check(
                Composite{typeof(T)}(a=1.0),
                Composite{typeof(T)}(a=1.0, b=Zero())
            )
            check(
                Composite{typeof(T)}(a=1.0),
                Composite{typeof(T)}(a=1.0+1e-10, b=Zero())
            )
        end
        @testset "negative case" begin
            @test fails(()->check(1.0, 2.0))
            @test fails(()->check(1.0 + im, 1.0 - im))
            @test fails(()->check((1.5, 2.5, 3.5), (1.5, 2.5, 4.5)))

            @test fails(()->check(Zero(), 20.0))
            @test fails(()->check(10.0, Zero()))
            @test fails(()->check(DoesNotExist(), Zero()))

            @test fails(()->check([1.0, 2.0], [1.0, 3.9]))
            @test fails(()->check([[1.0], [2.0]], [[1.1], [2.0]]))

            @test fails(()->check(@thunk(10*[[1.0], [2.0]]), [[1.0], [2.0]]))
        end
        @testset "type negative" begin
            @test fails() do  # these have different primals so should not be equal
                check(
                    Composite{Tuple{Float32, Float32}}(1f0, 2f0),
                    Composite{Tuple{Float64, Float64}}(1.0, 2.0)
                )
            end
            @test fails(()->check((1.0, 2.0), Composite{Tuple{Float64, Float64}}(1.0, 2.0)))
        end

        @testset "TestIterator" begin
            data = randn(3)
            iter1 = TestIterator(data, Base.HasLength(), Base.HasEltype())
            iter2 = TestIterator(data, Base.HasLength(), Base.EltypeUnknown())
            check(iter2, iter1)

            iter3 = TestIterator(data .+ 1e-10, Base.HasLength(), Base.HasEltype())
            check(iter3, iter1)

            iter_bad = TestIterator(data .+ 010, Base.HasLength(), Base.HasEltype())
            @test fails(()->check(iter_bad, iter1))
        end
    end
end
