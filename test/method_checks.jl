struct BadConstructor
    x
end

if VERSION >= v"1.3"
    # we only test in Julia 1.3 or later so we can delete the bad method
    @testset "test_method_signature.jl" begin
        test_method_signature = ChainRulesTestUtils.test_method_signature
        
        ChainRulesCore.rrule(::typeof(BadConstructor), x) = nothing
        m = Base.which(rrule, (DataType, Any))
        @test fails(()->test_method_signature(rrule, m))       
        Base.delete_method(m)

        ChainRulesCore.rrule(::RuleConfig, ::typeof(BadConstructor), x) = nothing
        m = Base.which(rrule, (RuleConfig, DataType, Any))
        @test fails(()->test_method_signature(rrule, m))       
        Base.delete_method(m)

        ChainRulesCore.frule(::Any, ::typeof(BadConstructor), x) = nothing
        m = Base.which(frule, (Any, DataType, Any))
        @test fails(()->test_method_signature(frule, m))       
        Base.delete_method(m)

        ChainRulesCore.frule(::RuleConfig, ::Any, ::typeof(BadConstructor), x) = nothing
        m = Base.which(frule, (RuleConfig, Any, DataType, Any))
        @test fails(()->test_method_signature(frule, m))       
        Base.delete_method(m)
    end
end