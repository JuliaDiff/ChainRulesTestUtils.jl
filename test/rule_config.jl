# testing configs
abstract type MySpecialTrait end
struct MySpecialConfig <: RuleConfig{Union{MySpecialTrait}} end

@testset "rule_config.jl" begin
    @testset "custom rrule_f" begin
        only2x(x, y) = 2x
        custom(::RuleConfig, ::typeof(only2x), x, y) = only2x(x, y), Δ -> (NoTangent(), 2Δ, ZeroTangent())
        wrong1(::RuleConfig, ::typeof(only2x), x, y) = only2x(x, y), Δ -> (ZeroTangent(), 2Δ, ZeroTangent())
        wrong2(::RuleConfig, ::typeof(only2x), x, y) = only2x(x, y), Δ -> (NoTangent(), 2.1Δ, ZeroTangent())
        wrong3(::RuleConfig, ::typeof(only2x), x, y) = only2x(x, y), Δ -> (NoTangent(), 2Δ)

        test_rrule(only2x, 2.0, 3.0; rrule_f=custom, check_inferred=false)
        @test errors(() -> test_rrule(only2x, 2.0, 3.0; rrule_f=wrong1, check_inferred=false))
        @test fails(() -> test_rrule(only2x, 2.0, 3.0; rrule_f=wrong2, check_inferred=false))
        @test fails(() -> test_rrule(only2x, 2.0, 3.0; rrule_f=wrong3, check_inferred=false))
    end

    @testset "custom frule_f" begin
        mytuple(x, y) = return 2x, 1.0
        T = Tuple{Float64, Float64}
        custom(::RuleConfig, (Δf, Δx, Δy), ::typeof(mytuple), x, y) = mytuple(x, y), Tangent{T}(2Δx, ZeroTangent())
        wrong1(::RuleConfig, (Δf, Δx, Δy), ::typeof(mytuple), x, y) = mytuple(x, y), Tangent{T}(2.1Δx, ZeroTangent())
        wrong2(::RuleConfig, (Δf, Δx, Δy), ::typeof(mytuple), x, y) = mytuple(x, y), Tangent{T}(2Δx, 1.0)

        test_frule(mytuple, 2.0, 3.0; frule_f=custom, check_inferred=false)
        @test fails(() -> test_frule(mytuple, 2.0, 3.0; frule_f=wrong1, check_inferred=false))
        @test fails(() -> test_frule(mytuple, 2.0, 3.0; frule_f=wrong2, check_inferred=false))
    end

    @testset "custom_config" begin
        has_config(x) = 2x
        function ChainRulesCore.rrule(::MySpecialConfig, ::typeof(has_config), x)
            has_config_pullback(ȳ) = return (NoTangent(), 2ȳ)
            return has_config(x), has_config_pullback
        end

        has_trait(x) = 2x
        function ChainRulesCore.rrule(::RuleConfig{<:MySpecialTrait}, ::typeof(has_trait), x)
            has_trait_pullback(ȳ) = return (NoTangent(), 2ȳ)
            return has_trait(x), has_trait_pullback
        end

        # it works if the special config is provided
        test_rrule(MySpecialConfig(), has_config, rand())
        test_rrule(MySpecialConfig(), has_trait, rand())

        # but it doesn't work for the default config
        errors(() -> test_rrule(has_config, rand()), "no method matching rrule")
        errors(() -> test_rrule(has_trait, rand()), "no method matching rrule")
    end

    @testset "ADviaFDConfig direct" begin
        poly(x) = x^2 + 3.2x

        x = 2.1
        config = ChainRulesTestUtils.ADviaFDConfig()

        @testset "rrule" begin
            y, pb = rrule_via_ad(config, poly, x)
            @test y == poly(x)
            test_approx(pb(1.0), (NoTangent(), (2*x + 3.2) * 1.0))
            # and automatically
            test_rrule(config, poly, rand(); rrule_f=rrule_via_ad, check_inferred=false)
        end

        @testset "frule" begin
            ḟ, ẋ = (NoTangent(), rand())
            Ω, ΔΩ = frule_via_ad(config, (ḟ, ẋ), poly, x)
            @test Ω == poly(x)
            test_approx(ΔΩ, (2*x + 3.2) * ẋ)
            # and automatically
            test_frule(config, poly, x; frule_f=frule_via_ad, check_inferred=false)
        end

        # more functions
        simo(x) = (x, 2x, 3x)
        miso(x, y, z) = x+y
        test_rrule(config, simo, x; rrule_f=rrule_via_ad, check_inferred=false)
        test_rrule(config, miso, x, 2x, "s"; rrule_f=rrule_via_ad, check_inferred=false)

        test_frule(config, simo, x; frule_f=frule_via_ad, check_inferred=false)
        test_frule(config, miso, x, x, "s"; frule_f=frule_via_ad, check_inferred=false)
    end

    @testset "ADviaFDConfig in a rule" begin
        inner(x, y) = x^2 + 2*y + 3
        outer(f, x) = 2 * f(x, 3.2)

        function ChainRulesCore.rrule(config::RuleConfig{>:HasReverseMode}, outer, f, x)
            fx, pb_f = rrule_via_ad(config, f, x)
            outer_pb(ȳ) = (NoTangent(), pb_f(2 * ȳ)...)
            return outer(f, x), outer_pb
        end

        function ChainRulesCore.frule(config::RuleConfig{>:HasForwardsMode}, (ȯuter, ḟ, ẋ), outer, f, x)
            inner, inner_dot = frule_via_ad(config, f, x)
            return 2 * inner, 2 * inner_dot
        end

        config = ChainRulesTestUtils.ADviaFDConfig()
        test_rrule(config, outer, inner, rand(); rrule_f=rrule_via_ad, check_inferred=false)
        test_frule(config, outer, inner, rand(); frule_f=frule_via_ad, check_inferred=false)
    end
end
