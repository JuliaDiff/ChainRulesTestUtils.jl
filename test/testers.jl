# For some reason if these aren't defined here, then they are interpreted as closures
futestkws(x; err = true) = err ? error() : x

fbtestkws(x, y; err = true) = err ? error() : x

sinconj(x) = sin(x)

primalapprox(x) = x

@testset "testers.jl" begin
    @testset "test_scalar" begin
        double(x) = 2x
        @scalar_rule(double(x), 2)
        test_scalar(double, 2.0)
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

    @testset "test derivative conjugated in pullback" begin
        ChainRulesCore.frule((_, Δx), ::typeof(sinconj), x) = (sin(x), cos(x) * Δx)

        # define rrule using ChainRulesCore's v0.9.0 convention, conjugating the derivative
        # in the rrule
        function ChainRulesCore.rrule(::typeof(sinconj), x)
            sinconj_pullback(ΔΩ) = (NO_FIELDS, conj(cos(x)) * ΔΩ)
            return sin(x), sinconj_pullback
        end

        rrule_test(sinconj, randn(ComplexF64), (randn(ComplexF64), randn(ComplexF64)))
        test_scalar(sinconj, randn(ComplexF64))
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

    @testset "single input, multiple output" begin
        simo(x) = (x, 2x)
        function ChainRulesCore.rrule(simo, x)
            simo_pullback((a, b)) = (NO_FIELDS, a .+ 2 .* b)
            return simo(x), simo_pullback
        end
        function ChainRulesCore.frule((_, ẋ), simo, x)
            y = simo(x)
            return y, Composite{typeof(y)}(ẋ, 2ẋ)
        end

        @testset "frule_test" begin
            frule_test(simo, (randn(), randn()))  # on scalar
            frule_test(simo, (randn(4), randn(4)))  # on array
        end
        @testset "rrule_test" begin
            # note: we are pulling back tuples (could use Composites here instead)
            rrule_test(simo, (randn(), rand()), (randn(), randn()))  # on scalar
            rrule_test(simo, (randn(4), rand(4)), (randn(4), randn(4))) # on array
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

    @testset "symbol input: fsymtest" begin
        fsymtest(x, s::Symbol) = x
        ChainRulesCore.frule((_, Δx, _), ::typeof(fsymtest), x, s) = (x, Δx)
        function ChainRulesCore.rrule(::typeof(fsymtest), x, s)
            function fsymtest_pullback(Δx)
                return NO_FIELDS, Δx, DoesNotExist()
            end
            return x, fsymtest_pullback
        end

        @testset "frule_test" begin
            frule_test(fsymtest, (randn(), randn()), (:x, nothing))
        end

        @testset "rrule_test" begin
            rrule_test(fsymtest, randn(), (randn(), randn()), (:x, nothing))
        end
    end

    @testset "unary with kwargs: futestkws(x; err)" begin
        function ChainRulesCore.frule((_, ẋ), ::typeof(futestkws), x; err = true)
            return futestkws(x; err = err), ẋ
        end
        function ChainRulesCore.rrule(::typeof(futestkws), x; err = true)
            function futestkws_pullback(Δx)
                return (NO_FIELDS, Δx)
            end
            return futestkws(x; err = err), futestkws_pullback
        end

        # we defined these functions at top of file to throw errors unless we pass `err=false`
        @test_throws ErrorException futestkws(randn())
        @test_throws ErrorException test_scalar(futestkws, randn())
        @test_throws ErrorException frule((nothing, randn()), futestkws, randn())
        @test_throws ErrorException rrule(futestkws, randn())

        @test_throws ErrorException futestkws(randn(4))
        @test_throws ErrorException frule((nothing, randn(4)), futestkws, randn(4))
        @test_throws ErrorException rrule(futestkws, randn(4))

        @testset "scalar_test" begin
            test_scalar(futestkws, randn(); fkwargs=(; err = false))
        end
        @testset "frule_test" begin
            frule_test(futestkws, (randn(), randn()); fkwargs=(; err = false))
            frule_test(futestkws, (randn(4), randn(4)); fkwargs=(; err = false))
        end
        @testset "rrule_test" begin
            rrule_test(futestkws, randn(), (randn(), randn()); fkwargs=(; err = false))
            rrule_test(futestkws, randn(4), (randn(4), randn(4)); fkwargs=(; err = false))
        end
    end

    @testset "binary with kwargs: fbtestkws(x, y; err)" begin
        function ChainRulesCore.frule((_, ẋ, _), ::typeof(fbtestkws), x, y; err = true)
            return fbtestkws(x, y; err = err), ẋ
        end
        function ChainRulesCore.rrule(::typeof(fbtestkws), x, y; err = true)
            function fbtestkws_pullback(Δx)
                return (NO_FIELDS, Δx, Zero())
            end
            return fbtestkws(x, y; err = err), fbtestkws_pullback
        end

        # we defined these functions at top of file to throw errors unless we pass `err=false`
        @test_throws ErrorException fbtestkws(randn(), randn())
        @test_throws ErrorException frule((nothing, randn(), nothing), fbtestkws, randn(), randn())
        @test_throws ErrorException rrule(fbtestkws, randn(), randn())

        @test_throws ErrorException fbtestkws(randn(4), randn(4))
        @test_throws ErrorException frule((nothing, randn(4), nothing), fbtestkws, randn(4), randn(4))
        @test_throws ErrorException rrule(fbtestkws, randn(4), randn(4))

        @testset "frule_test" begin
            frule_test(fbtestkws, (randn(), randn()), (randn(), randn()); fkwargs=(; err = false))
            frule_test(fbtestkws, (randn(4), randn(4)), (randn(4), randn(4)); fkwargs=(; err = false))
        end
        @testset "rrule_test" begin
            rrule_test(fbtestkws, randn(), (randn(), randn()), (randn(), randn()); fkwargs=(; err = false))
            rrule_test(fbtestkws, randn(4), (randn(4), randn(4)), (randn(4), randn(4)); fkwargs=(; err = false))
        end
    end

    @testset "primal can be only approximately equal" begin
        ChainRulesCore.frule((_, Δx), ::typeof(primalapprox), x) = (x + sqrt(eps(x)), Δx)

        function ChainRulesCore.rrule(::typeof(primalapprox), x)
            function primalapprox_pullback(Δx)
                return (NO_FIELDS, Δx)
            end
            return x + sqrt(eps(x)), primalapprox_pullback
        end

        frule_test(primalapprox, (randn(), randn()); atol = 1e-6)
        rrule_test(primalapprox, randn(), (randn(), randn()); atol = 1e-6)
    end
end
