using ChainRulesCore
using ChainRulesTestUtils
using Random
using Test

@testset "ChainRulesTestUtils.jl" begin
    include("to_vec.jl")

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

                # But these have different primals so should not be equal
                @test !(Composite{Tuple{Int, Int}}(1.0, 2.0) ≈ Composite{Tuple{Float64, Float64}}(1.0, 2.0))
            end
        end
    end


    @testset "test_scalar" begin
        double(x) = 2x
        @scalar_rule(double(x), 2)
        test_scalar(double, 2)
    end

    @testset "unary: identity(x)" begin
        function ChainRulesCore.frule((_, ẏ), ::typeof(identity), x)
            return x, ẏ
        end
        function ChainRulesCore.rrule(::typeof(identity), x)
            function identity_pullback(ȳ)
                return (NO_FIELDS, ȳ)
            end
            return x, identity_pullback
        end
        @testset "frule_test" begin
            frule_test(identity, (randn(), randn()))
            frule_test(identity, (randn(4), randn(4)))
        end
        @testset "rrule_test" begin
            rrule_test(identity, randn(), (randn(), randn()))
            rrule_test(identity, randn(4), (randn(4), randn(4)))
        end
    end

    @testset "binary: fst(x, y)" begin
        fst(x, y) = x
        ChainRulesCore.frule((_, dx, dy), ::typeof(fst), x, y) = (x, dx)
        function ChainRulesCore.rrule(::typeof(fst), x, y)
            function fst_pullback(Δx)
                return (NO_FIELDS, Δx, Zero())
            end
            return x, fst_pullback
        end
        @testset "frule_test" begin
            frule_test(fst, (2, 4.0), (3, 5.0))
            frule_test(fst, (randn(4), randn(4)), (randn(4), randn(4)))
        end
        @testset "rrule_test" begin
            rrule_test(fst, rand(), (2.0, 4.0), (3.0, 5.0))
            rrule_test(fst, randn(4), (randn(4), randn(4)), (randn(4), randn(4)))
        end
    end


    @testset "tuple input: first" begin
        ChainRulesCore.frule((_, dx), ::typeof(first), xs::Tuple) = (first(xs), first(dx))
        function ChainRulesCore.rrule(::typeof(first), x::Tuple)
            function first_pullback(Δx)
                return (NO_FIELDS, Composite{typeof(x)}(Δx, falses(length(x)-1)...))
            end
            return first(x), first_pullback
        end

        CTuple{N} = Composite{NTuple{N, Float64}}  # shorter for testing
        @testset "frule_test" begin
            frule_test(first, ((2.0, 3.0), CTuple{2}(4.0, 5.0)))
            frule_test(first, (Tuple(randn(4)), CTuple{4}(randn(4)...)))
        end
        @testset "rrule_test" begin
            rrule_test(first, 2.0, ((2.0, 3.0), CTuple{2}(4.0, 5.0)))
            rrule_test(first, randn(), (Tuple(randn(4)), CTuple{4}(randn(4)...)))
        end
    end
end
