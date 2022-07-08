
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
    @testset "_test_add!!_behaviour" begin
        check = ChainRulesTestUtils._test_add!!_behaviour

        check(10.0, 2.0)
        check(11.0, ZeroTangent())
        check([10.0, 20.0], @thunk([2.0, 0.0]))

        check(12.0, InplaceableThunk(X̄ -> error("Should not have in-placed"), @thunk(2.0)))

        check([10.0, 20.0], InplaceableThunk(X̄ -> (X̄[1] += 2.0; X̄), @thunk([2.0, 0.0])))
        @test fails() do
            check([10.0, 20.0], InplaceableThunk(X̄ -> (X̄[1] += 3.0; X̄), @thunk([2.0, 0.0])))
        end
    end

    @testset "test_approx" begin
        @testset "positive cases" begin
            test_approx(1.0, 1.0)
            test_approx(1.0 + im, 1.0 + im)
            test_approx(1.0, 1.0 + 1e-10)  # isapprox _behaviour
            test_approx((1.5, 2.5, 3.5), (1.5, 2.5, 3.5 + 1e-10))

            test_approx(ZeroTangent(), 0.0)

            test_approx([1.0, 2.0], [1.0, 2.0])
            test_approx([[1.0], [2.0]], [[1.0], [2.0]])
            test_approx(Broadcast.broadcasted(identity, [1.0 2.0; 3.0 4.0]), [1.0 2.0; 3.0 4.0])

            test_approx(@thunk(10 * 0.1 * [[1.0], [2.0]]), [[1.0], [2.0]])

            test_approx(@not_implemented(""), rand(3))
            test_approx(rand(3), @not_implemented(""))
            test_approx(@not_implemented("a"), @not_implemented("a"))

            test_approx(
                Tangent{Tuple{Float64,Float64}}(1.0, 2.0),
                Tangent{Tuple{Float64,Float64}}(1.0, 2.0),
            )

            diag_eg = Diagonal(randn(5))
            test_approx( # Structual == Structural
                Tangent{typeof(diag_eg)}(; diag=diag_eg.diag),
                Tangent{typeof(diag_eg)}(; diag=diag_eg.diag),
            )
            test_approx( # Structural == Natural
                Tangent{typeof(diag_eg)}(; diag=diag_eg.diag),
                diag_eg,
            )

            T = (a=1.0, b=2.0)
            test_approx(
                Tangent{typeof(T)}(; a=1.0), Tangent{typeof(T)}(; a=1.0, b=ZeroTangent())
            )
            test_approx(
                Tangent{typeof(T)}(; a=1.0),
                Tangent{typeof(T)}(; a=1.0 + 1e-10, b=ZeroTangent()),
            )

            test_approx(
                Tangent{FakeNaturalDiffWithIsApprox}(; x=1.4),
                FakeNaturalDiffWithIsApprox(1.4),
            )
            test_approx(
                FakeNaturalDiffWithIsApprox(1.4),
                Tangent{FakeNaturalDiffWithIsApprox}(; x=1.4),
            )

            # ambig with CRC after:
            # https://github.com/JuliaDiff/ChainRulesCore.jl/pull/524#issuecomment-1074037647
            test_approx(
                Tangent{Tuple{Float64,Float64}}(1.0, 2.0),
                @thunk(Tangent{Tuple{Float64,Float64}}(1.0, 2.0)),
            )
            test_approx(
                @thunk(Tangent{Tuple{Float64,Float64}}(1.0, 2.0)),
                Tangent{Tuple{Float64,Float64}}(1.0, 2.0),
            )
            test_approx(@thunk(ZeroTangent()), ZeroTangent())
            test_approx(ZeroTangent(), @thunk(ZeroTangent()))
            test_approx(
                Tangent{Tuple{Float64,Float64}}(ZeroTangent(), NoTangent()),
                NoTangent(),
            )
            test_approx(
                NoTangent(),
                Tangent{Tuple{Float64,Float64}}(ZeroTangent(), NoTangent()),
            )
        end
        @testset "negative case" begin
            @test fails(() -> test_approx(1.0, 2.0))
            @test fails(() -> test_approx(1.0 + im, 1.0 - im))
            @test fails(() -> test_approx((1.5, 2.5, 3.5), (1.5, 2.5, 4.5)))

            @test fails(() -> test_approx(ZeroTangent(), 20.0))
            @test fails(() -> test_approx(10.0, ZeroTangent()))

            @test fails(() -> test_approx([1.0, 2.0], [1.0, 3.9]))
            @test fails(() -> test_approx([[1.0], [2.0]], [[1.1], [2.0]]))

            @test fails(() -> test_approx(@thunk(10 * [[1.0], [2.0]]), [[1.0], [2.0]]))

            @test fails(() -> test_approx(@not_implemented("a"), @not_implemented("b")))

            # should fail, not ambig error
            @test fails() do 
                test_approx(
                    Tangent{Tuple{Float64,Float64}}(1.0, 2.0),
                    @thunk(Tangent{Tuple{Float64,Float64}}(2.0, 2.0)),
                )
            end
        end
        @testset "type negative" begin
            @test fails() do  # these have different primals so should not be equal
                test_approx(
                    Tangent{Tuple{Float32,Float32}}(1.0f0, 2.0f0),
                    Tangent{Tuple{Float64,Float64}}(1.0, 2.0),
                )
            end
            @test fails() do
                test_approx((1.0, 2.0), Tangent{Tuple{Float64,Float64}}(1.0, 2.0))
            end
        end

        @testset "TestIterator" begin
            data = randn(3)
            iter1 = TestIterator(data, Base.HasLength(), Base.HasEltype())
            iter2 = TestIterator(data, Base.HasLength(), Base.EltypeUnknown())
            test_approx(iter2, iter1)

            iter3 = TestIterator(data .+ 1e-10, Base.HasLength(), Base.HasEltype())
            test_approx(iter3, iter1)

            iter_bad = TestIterator(data .+ 010, Base.HasLength(), Base.HasEltype())
            @test fails(() -> test_approx(iter_bad, iter1))
        end
    end
end
