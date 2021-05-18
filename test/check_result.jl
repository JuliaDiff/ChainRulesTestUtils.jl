
struct FakeNaturalDiffWithIsApprox  # For testing overloading isapprox(::Tangent) works:
    x
end
function Base.isapprox(c::Tangent, d::FakeNaturalDiffWithIsApprox; kwargs...)
    return isapprox(c.x, d.x, kwargs...)
end
function Base.isapprox(d::FakeNaturalDiffWithIsApprox, c::Tangent; kwargs...)
    return isapprox(c.x, d.x, kwargs...)
end


@testset "check_result.jl" begin
    @testset "_check_add!!_behaviour" begin
        check = ChainRulesTestUtils._check_add!!_behaviour

        check(10.0, 2.0)
        check(11.0, ZeroTangent())
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


    @testset "check_equal" begin

        @testset "positive cases" begin
            check_equal(1.0, 1.0)
            check_equal(1.0 + im, 1.0 + im)
            check_equal(1.0, 1.0+1e-10)  # isapprox _behaviour
            check_equal((1.5, 2.5, 3.5), (1.5, 2.5, 3.5 + 1e-10))

            check_equal(ZeroTangent(), 0.0)

            check_equal([1.0, 2.0], [1.0, 2.0])
            check_equal([[1.0], [2.0]], [[1.0], [2.0]])

            check_equal(@thunk(10*0.1*[[1.0], [2.0]]), [[1.0], [2.0]])

            check_equal(@not_implemented(""), rand(3))
            check_equal(rand(3), @not_implemented(""))
            check_equal(@not_implemented("a"), @not_implemented("a"))

            check_equal(
                Tangent{Tuple{Float64, Float64}}(1.0, 2.0),
                Tangent{Tuple{Float64, Float64}}(1.0, 2.0)
            )

            diag_eg = Diagonal(randn(5))
            check_equal( # Structual == Structural
                Tangent{typeof(diag_eg)}(diag=diag_eg.diag),
                Tangent{typeof(diag_eg)}(diag=diag_eg.diag)
            )
            check_equal( # Structural == Natural
                Tangent{typeof(diag_eg)}(diag=diag_eg.diag),
                diag_eg
            )

            T = (a=1.0, b=2.0)
            check_equal(
                Tangent{typeof(T)}(a=1.0),
                Tangent{typeof(T)}(a=1.0, b=ZeroTangent())
            )
            check_equal(
                Tangent{typeof(T)}(a=1.0),
                Tangent{typeof(T)}(a=1.0+1e-10, b=ZeroTangent())
            )

            check_equal(
                Tangent{FakeNaturalDiffWithIsApprox}(; x=1.4),
                FakeNaturalDiffWithIsApprox(1.4)
            )
            check_equal(
                FakeNaturalDiffWithIsApprox(1.4),
                Tangent{FakeNaturalDiffWithIsApprox}(; x=1.4)
            )
        end
        @testset "negative case" begin
            @test fails(()->check_equal(1.0, 2.0))
            @test fails(()->check_equal(1.0 + im, 1.0 - im))
            @test fails(()->check_equal((1.5, 2.5, 3.5), (1.5, 2.5, 4.5)))

            @test fails(()->check_equal(ZeroTangent(), 20.0))
            @test fails(()->check_equal(10.0, ZeroTangent()))

            @test fails(()->check_equal([1.0, 2.0], [1.0, 3.9]))
            @test fails(()->check_equal([[1.0], [2.0]], [[1.1], [2.0]]))

            @test fails(()->check_equal(@thunk(10*[[1.0], [2.0]]), [[1.0], [2.0]]))

            @test fails(()->check_equal(@not_implemented("a"), @not_implemented("b")))
        end
        @testset "type negative" begin
            @test fails() do  # these have different primals so should not be equal
                check_equal(
                    Tangent{Tuple{Float32, Float32}}(1f0, 2f0),
                    Tangent{Tuple{Float64, Float64}}(1.0, 2.0)
                )
            end
            @test fails() do
                check_equal((1.0, 2.0), Tangent{Tuple{Float64, Float64}}(1.0, 2.0))
            end
        end

        @testset "TestIterator" begin
            data = randn(3)
            iter1 = TestIterator(data, Base.HasLength(), Base.HasEltype())
            iter2 = TestIterator(data, Base.HasLength(), Base.EltypeUnknown())
            check_equal(iter2, iter1)

            iter3 = TestIterator(data .+ 1e-10, Base.HasLength(), Base.HasEltype())
            check_equal(iter3, iter1)

            iter_bad = TestIterator(data .+ 010, Base.HasLength(), Base.HasEltype())
            @test fails(()->check_equal(iter_bad, iter1))
        end
    end
end
