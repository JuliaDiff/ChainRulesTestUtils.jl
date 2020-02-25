using ChainRulesCore
using ChainRulesTestUtils
using Random
using Test

@testset "ChainRulesTestUtils.jl" begin
    double(x) = 2x
    @scalar_rule(double(x), 2)
    test_scalar(double, 2)

    fst(x, y) = x
    ChainRulesCore.frule((_, dx, dy), ::typeof(fst), x, y) = (x, dx)

    function ChainRulesCore.rrule(::typeof(fst), x, y)
        function fst_pullback(Δx)
            return (NO_FIELDS, Δx, Zero())
        end
        return x, fst_pullback
    end

    frule_test(fst, (2, 4.0), (3, 5.0))
    rrule_test(fst, rand(), (2.0, 4.0), (3.0, 5.0))
end
