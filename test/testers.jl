# For some reason if these aren't defined here, then they are interpreted as closures
futestkws(x; err = true) = err ? error("futestkws_err") : x

fbtestkws(x, y; err = true) = err ? error("fbtestkws_err") : x

sinconj(x) = sin(x)

primalapprox(x) = x

f_inferrable(x) = x
f_noninferrable_frule(x) = x
f_noninferrable_rrule(x) = x
f_noninferrable_pullback(x) = x
f_noninferrable_thunk(x, y) = x + y
f_inferrable_pullback_only(x) = x > 0 ? Float64(x) : Float32(x)


function finplace!(x; y = [1])
    y[1] = 2
    x .*= y[1]
    return x
end

@testset "testers.jl" begin
    @testset "test_scalar" begin
        @testset "Ensure correct rules succeed" begin
            double(x) = 2x
            @scalar_rule(double(x), 2)
            test_scalar(double, 2.1)
        end
        @testset "Ensure incorrect rules caught" begin
            alt_double(x) = 2x
            @scalar_rule(alt_double(x), 3)  # this is wrong, on purpose
            @test fails(()->test_scalar(alt_double, 2.1))
        end
    end

    @testset "unary: identity(x)" begin
        function ChainRulesCore.frule((_, ẏ), ::typeof(identity), x)
            return x, ẏ
        end
        function ChainRulesCore.rrule(::typeof(identity), x)
            function identity_pullback(ȳ)
                return (NO_FIELDS, ȳ)
            end
            return x, identity_pullback
        end
        @testset "test_frule" begin
            test_frule(identity, randn())
            test_frule(identity, randn(4))
        end
        @testset "test_rrule" begin
            test_rrule(identity, randn())
            test_rrule(identity, randn(4))
        end
    end

    @testset "Inplace accumulation: identity on Array" begin
        @testset "Correct definitions" begin
            local inplace_used
            function ChainRulesCore.frule((_, ẋ), ::typeof(identity), x::Array)
                ẏ = InplaceableThunk(@thunk(ẋ), ȧ -> (inplace_used=true; ȧ .+= ẋ))
                return identity(x), ẏ
            end
            function ChainRulesCore.rrule(::typeof(identity), x::Array)
                function identity_pullback(ȳ)
                    x̄_ret = InplaceableThunk(@thunk(ȳ), ā -> (inplace_used=true; ā .+= ȳ))
                    return (NO_FIELDS, x̄_ret)
                end
                return identity(x), identity_pullback
            end

            inplace_used = false
            test_frule(identity, randn(4))
            @test inplace_used  # make sure we are using, and thus testing the add!

            inplace_used = false
            test_rrule(identity, randn(4))
            @test inplace_used  # make sure we are using, and thus testing the add!
        end

        @testset "Incorrect in-place definitions" begin
            my_identity(value) = value  # we will define bad rules on this
            function ChainRulesCore.frule((_, ẋ), ::typeof(my_identity), x::Array)
                # only the in-place part is incorrect
                ẏ = InplaceableThunk(@thunk(ẋ), ȧ -> ȧ .+= 200 .* ẋ)
                return my_identity(x), ẏ
            end
            function ChainRulesCore.rrule(::typeof(my_identity), x::Array)
                x_dims = size(x)
                function my_identity_pullback(ȳ)
                    # only the in-place part is incorrect
                    x̄_ret = InplaceableThunk(@thunk(ȳ), ā -> ā .+= 200 .* ȳ)
                    return (NO_FIELDS, x̄_ret)
                end
                return my_identity(x), my_identity_pullback
            end
            @test fails(()->test_frule(my_identity, randn(4)))
            @test fails(()->test_rrule(my_identity, randn(4)))
        end
    end

    @testset "check rules are inferrable" begin
        @testset "check inferred" begin
            ChainRulesCore.frule((_, Δx), ::typeof(f_inferrable), x) = (x, Δx)
            function ChainRulesCore.rrule(::typeof(f_inferrable), x)
                f_inferrable_pullback(Δy) = (NO_FIELDS, Δy)
                return x, f_inferrable_pullback
            end

            test_frule(f_inferrable, 2.0; check_inferred = false)
            test_frule(f_inferrable, 2.0)
            test_rrule(f_inferrable, 2.0; check_inferred = false)
            test_rrule(f_inferrable, 2.0)
            test_scalar(f_inferrable, 2.0)
            test_scalar(f_inferrable, 2.0; check_inferred = false)
        end

        @testset "check not inferred in frule" begin
            function ChainRulesCore.frule((_, Δx), ::typeof(f_noninferrable_frule), x)
                return (x, x > 0 ? Float64(Δx) : Float32(Δx))
            end
            function ChainRulesCore.rrule(::typeof(f_noninferrable_frule), x)
                f_noninferrable_frule_pullback(Δy) = (NO_FIELDS, Δy)
                return x, f_noninferrable_frule_pullback
            end

            test_frule(f_noninferrable_frule, 2.0; check_inferred = false)
            @test errors(
                ()->test_frule(f_noninferrable_frule, 2.0),
                "does not match inferred return type"
            )

            test_scalar(f_noninferrable_frule, 2.0; check_inferred = false)
            @test errors(
                ()->test_scalar(f_noninferrable_frule, 2.0),
                "does not match inferred return type"
            )
        end

        @testset "check not inferred in rrule" begin
            ChainRulesCore.frule((_, Δx), ::typeof(f_noninferrable_rrule), x) = (x, Δx)
            function ChainRulesCore.rrule(::typeof(f_noninferrable_rrule), x)
                if x > 0
                    f_noninferrable_rrule_pullback(Δy) = (NO_FIELDS, Δy)
                    return x, f_noninferrable_rrule_pullback
                else
                    return x, _ -> (NO_FIELDS, Δy) # this is not hit by the used point
                end
            end

            test_rrule(f_noninferrable_rrule, 2.0; check_inferred = false)
            @test errors(
                ()->test_rrule(f_noninferrable_rrule, 2.0),
                "does not match inferred return type"
            )

            test_scalar(f_noninferrable_rrule, 2.0; check_inferred = false)
            @test errors(
                ()->test_scalar(f_noninferrable_rrule, 2.0),
                "does not match inferred return type"
            )
        end

        @testset "check not inferred in pullback" begin
            function ChainRulesCore.rrule(::typeof(f_noninferrable_pullback), x)
                f_noninferrable_pullback_pullback(Δy) = (NO_FIELDS, x > 0 ? Float64(Δy) : Float32(Δy))
                return x, f_noninferrable_pullback_pullback
            end
            test_rrule(f_noninferrable_pullback, 2.0; check_inferred = false)
            @test errors(
                ()->test_rrule(f_noninferrable_pullback, 2.0),
                "does not match inferred return type"
            )
        end

        @testset "check not inferred in thunk" begin
            function ChainRulesCore.rrule(::typeof(f_noninferrable_thunk), x, y)
                function f_noninferrable_thunk_pullback(Δz)
                    ∂x = @thunk(x > 0 ? Float64(Δz) : Float32(Δz))
                    return (NO_FIELDS, ∂x, Δz)
                end
                return x + y, f_noninferrable_thunk_pullback
            end
            test_rrule(f_noninferrable_thunk, 2.0, 3.0; check_inferred = false)
            @test errors(
                ()->test_rrule(f_noninferrable_thunk, 2.0, 3.0),
                "does not match inferred return type"
            )
        end

        @testset "check non-inferrable primal still passes if pullback inferrable" begin
            function ChainRulesCore.frule((_, Δx), ::typeof(f_inferrable_pullback_only), x)
                return (x > 0 ? Float64(x) : Float32(x), x > 0 ? Float64(Δx) : Float32(Δx))
            end
            function ChainRulesCore.rrule(::typeof(f_inferrable_pullback_only), x)
                f_inferrable_pullback_only_pullback(Δy) = (NO_FIELDS, oftype(x, Δy))
                return x > 0 ? Float64(x) : Float32(x), f_inferrable_pullback_only_pullback
            end
            test_frule(f_inferrable_pullback_only, 2.0; check_inferred = true)
            test_rrule(f_inferrable_pullback_only, 2.0; check_inferred = true)
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

        test_rrule(sinconj, randn(ComplexF64))
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
        @testset "test_frule" begin
            test_frule(fst, 2.0, 3.0)
            test_frule(fst, randn(4), randn(4))
        end
        @testset "test_rrule" begin
            test_rrule(fst, 2.0, 4.0)
            test_rrule(fst, randn(4), randn(4))
        end
    end

    @testset "single input, multiple output" begin
        simo(x) = (x, 2x)
        function ChainRulesCore.rrule(simo, x)
            simo_pullback((a, b)) = (NO_FIELDS, a .+ 2 .* b)
            return simo(x), simo_pullback
        end
        function ChainRulesCore.frule((_, ẋ), simo, x)
            y = simo(x)
            return y, Composite{typeof(y)}(ẋ, 2ẋ)
        end

        @testset "test_frule" begin
            test_frule(simo, 1.5)  # on scalar
            test_frule(simo, randn(4))  # on array
        end
        @testset "test_rrule" begin
            test_rrule(simo, 3.0)  # on scalar
            test_rrule(simo, randn(4))  # on array
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

        #CTuple{N} = Composite{NTuple{N, Float64}}  # shorter for testing
        @testset "test_frule" begin
            test_frule(first, (2.0, 3.0))
            test_frule(first, Tuple(randn(4)))
        end
        @testset "test_rrule" begin
            test_rrule(first, (2.0, 3.0); check_inferred = false)
            test_rrule(first, Tuple(randn(4)); check_inferred = false)
        end
    end

    @testset "tuple output (backing type of Composite =/= natural differential)" begin
        tuple_out(x) = return (x, 1.0) # i.e. (x, 1.0) and not (x, x)
        function ChainRulesCore.frule((_, dx), ::typeof(tuple_out), x)
            Ω = tuple_out(x)
            ∂Ω = Composite{typeof(Ω)}(dx, Zero())
            return Ω, ∂Ω
        end
        test_frule(tuple_out, 2.0)
    end

    @testset "ignoring arguments" begin
        fsymtest(x, s::Symbol) = x
        ChainRulesCore.frule((_, Δx, _), ::typeof(fsymtest), x, s) = (x, Δx)
        function ChainRulesCore.rrule(::typeof(fsymtest), x, s)
            function fsymtest_pullback(Δx)
                return NO_FIELDS, Δx, DoesNotExist()
            end
            return x, fsymtest_pullback
        end

        @testset "test_frule" begin
            test_frule(fsymtest, 2.5, :x ⊢ nothing)
        end

        @testset "test_rrule" begin
            test_rrule(fsymtest, 2.5, :x ⊢ nothing)
        end
    end

    @testset "unary with kwargs: futestkws(x; err)" begin
        function ChainRulesCore.frule((_, ẋ), ::typeof(futestkws), x; err = true)
            return futestkws(x; err = err), ẋ
        end
        function ChainRulesCore.rrule(::typeof(futestkws), x; err = true)
            function futestkws_pullback(Δx)
                return (NO_FIELDS, Δx)
            end
            return futestkws(x; err = err), futestkws_pullback
        end

        # we defined these functions at top of file to throw errors unless we pass `err=false`
        @test_throws ErrorException futestkws(randn())
        @test errors(()->test_scalar(futestkws, randn()), "futestkws_err")
        @test_throws ErrorException frule((nothing, randn()), futestkws, randn())
        @test_throws ErrorException rrule(futestkws, randn())

        @test_throws ErrorException futestkws(randn(4))
        @test_throws ErrorException frule((nothing, randn(4)), futestkws, randn(4))
        @test_throws ErrorException rrule(futestkws, randn(4))

        @testset "scalar_test" begin
            test_scalar(futestkws, 2.5; fkwargs=(; err = false))
        end
        @testset "test_frule" begin
            test_frule(futestkws, 2.5; fkwargs=(; err = false))
            test_frule(futestkws, 2.5; fkwargs=(; err = false))
        end
        @testset "test_rrule" begin
            test_rrule(futestkws, 2.5; fkwargs=(; err = false))
            test_rrule(futestkws, 2.5; fkwargs=(; err = false))
        end
    end

    @testset "binary with kwargs: fbtestkws(x, y; err)" begin
        function ChainRulesCore.frule((_, ẋ, _), ::typeof(fbtestkws), x, y; err = true)
            return fbtestkws(x, y; err = err), ẋ
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

        @testset "test_frule" begin
            test_frule(fbtestkws, 2.5, 3.0; fkwargs=(; err = false))
            test_frule(fbtestkws, randn(4), randn(4); fkwargs=(; err = false))
        end
        @testset "test_rrule" begin
            test_rrule(fbtestkws, 2.5, 3.0; fkwargs=(; err = false))
            test_rrule(fbtestkws, randn(4), randn(4); fkwargs=(; err = false))
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

        test_frule(primalapprox, 2.5; atol = 1e-6)
        test_rrule(primalapprox, 2.5; atol = 1e-6)
    end

    @testset "frule with mutation" begin
        function ChainRulesCore.frule((_, ẋ), ::typeof(finplace!), x; y = [1])
            y[1] *= 2
            x .*= y[1]
            ẋ .*= 2 # hardcoded to match y defined below
            return x, ẋ
        end

        # these pass in tangents explictly so that we can check them after
        x = randn(3)
        ẋ = [4.0, 5.0, 6.0]
        xcopy, ẋcopy = copy(x), copy(ẋ)
        y = [1, 2]
        test_frule(finplace!, x⊢ẋ; fkwargs=(y = y,))
        @test x == xcopy
        @test ẋ == ẋcopy
        @test y == [1, 2]
    end

    @testset "TestIterator input" begin
        function iterfun(iter)
            state = iterate(iter)
            state === nothing && error()
            (x, i) = state
            s = x^2
            while true
                state = iterate(iter, i)
                state === nothing && break
                (x, i) = state
                s += x^2
            end
            return s
        end

        function ChainRulesCore.frule((_, Δiter), ::typeof(iterfun), iter)
            iter_Δiter = zip(iter, Δiter)
            state = iterate(iter_Δiter)
            state === nothing && error()
            # for some reason the following line errors if the frule is defined within a testset
            ((x, Δx), i) = state
            return iterfun(iter), sum(2 .* iter.data .* Δiter.data)
            s = x^2
            ∂s = 2 * x * Δx
            while true
                state = iterate(iter_Δiter, i)
                state === nothing && break
                ((x, Δx), i) = state
                s += x^2
                ∂s += 2 * x * Δx
            end
            return s, ∂s
        end

        function ChainRulesCore.rrule(::typeof(iterfun), iter::TestIterator)
            function iterfun_pullback(Δs)
                data = iter.data
                ∂data = (2 * Δs) .* conj.(data)
                ∂iter = TestIterator(
                    ∂data,
                    Base.IteratorSize(iter),
                    Base.IteratorEltype(iter),
                )
                return (NO_FIELDS, ∂iter)
            end
            return iterfun(iter), iterfun_pullback
        end

        @testset "Testing iterator function" begin
            # This needs to be in a separate testset to stop the `x` being shared with `iterfun`
            x = TestIterator(randn(2, 3), Base.SizeUnknown(), Base.EltypeUnknown())
            test_frule(iterfun, x)
            test_rrule(iterfun, x)
        end
    end

    @testset "unhappy path" begin
        @testset "primal wrong" begin
            my_identity1(x) = x
            function ChainRulesCore.frule((_, ẏ), ::typeof(my_identity1), x)
                return 2.5 * x, ẏ
            end
            function ChainRulesCore.rrule(::typeof(my_identity1), x)
                function identity_pullback(ȳ)
                    return (NO_FIELDS, ȳ)
                end
                return 2.5 * x, identity_pullback
            end

            @test fails(()->test_frule(my_identity1, 2.2))
            @test fails(()->test_rrule(my_identity1, 2.2))
        end

        @testset "derivative wrong" begin
            my_identity2(x) = x
            function ChainRulesCore.frule((_, ẏ), ::typeof(my_identity2), x)
                return x, 2.7 * ẏ
            end
            function ChainRulesCore.rrule(::typeof(my_identity2), x)
                function identity_pullback(ȳ)
                    return (NO_FIELDS, 31.8 * ȳ)
                end
                return x, identity_pullback
            end

            @test fails(()->test_frule(my_identity2, 2.2))
            @test fails(()->test_rrule(my_identity2, 2.2))
        end
    end


    @testset "Tuple primal that is not equal to differential backing" begin
        # https://github.com/JuliaMath/SpecialFunctions.jl/issues/288
        forwards_trouble(x) = (1, 2.0*x)
        @scalar_rule(forwards_trouble(v), Zero(), 2.0)
        test_frule(forwards_trouble, 2.5)

        rev_trouble((x,y)) = y
        function ChainRulesCore.rrule(::typeof(rev_trouble), (x,y)::P) where P
            rev_trouble_pullback(ȳ) = (NO_FIELDS, Composite{P}(Zero(), ȳ))
            return y, rev_trouble_pullback
        end
        test_rrule(rev_trouble, (3, 3.0) ⊢ Composite{Tuple{Int, Float64}}(Zero(), 1.0))
    end
end
