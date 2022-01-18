struct BadConstructor
    x
end

@testset "global_checks.jl" begin
    test_method_tables_sensibility()

    ChainRulesCore.rrule(::typeof(BadConstructor), x) = nothing
    @test fails(test_method_tables_sensibility)
    Base.delete_method(Base.which(Tuple{typeof(rrule), DataType, Any}))
    test_method_tables_sensibility()  # make sure delete worked

    ChainRulesCore.rrule(::RuleConfig, ::typeof(BadConstructor), x) = nothing
    @test fails(test_method_tables_sensibility)
    Base.delete_method(Base.which(Tuple{typeof(rrule), RuleConfig, DataType, Any}))
    test_method_tables_sensibility()  # make sure delete worked



    ChainRulesCore.frule(::Any, ::typeof(BadConstructor), x) = nothing
    @test fails(test_method_tables_sensibility)
    Base.delete_method(Base.which(Tuple{typeof(frule), Any, DataType, Any}))
    test_method_tables_sensibility()  # make sure delete worked

    ChainRulesCore.frule(::RuleConfig, ::Any, ::typeof(BadConstructor), x) = nothing
    @test fails(test_method_tables_sensibility)
    Base.delete_method(Base.which(Tuple{typeof(frule), RuleConfig, Any, DataType, Any}))
    test_method_tables_sensibility()  # make sure delete worked
end