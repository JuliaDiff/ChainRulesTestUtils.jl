struct BadConstructor
    x
end

if VERSION >= v"1.3"
    @testset "global_checks.jl" begin
        test_method_tables_sensibility()
        ChainRulesCore.rrule(::typeof(BadConstructor), x) = nothing
        @test fails(test_method_tables_sensibility)
        Base.delete_method(Base.which(rrule, (DataType, Any)))
        test_method_tables_sensibility()  # make sure delete worked

        ChainRulesCore.rrule(::RuleConfig, ::typeof(BadConstructor), x) = nothing
        @test fails(test_method_tables_sensibility)
        Base.delete_method(Base.which(rrule, (RuleConfig, DataType, Any)))
        test_method_tables_sensibility()  # make sure delete worked



        ChainRulesCore.frule(::Any, ::typeof(BadConstructor), x) = nothing
        @test fails(test_method_tables_sensibility)
        Base.delete_method(Base.which(frule, (Any, DataType, Any)))
        test_method_tables_sensibility()  # make sure delete worked

        ChainRulesCore.frule(::RuleConfig, ::Any, ::typeof(BadConstructor), x) = nothing
        @test fails(test_method_tables_sensibility)
        Base.delete_method(Base.which(frule, (RuleConfig, Any, DataType, Any)))
        test_method_tables_sensibility()  # make sure delete worked
    end
else # pre 1.3, so no `delete_method` so just test happy path
    @testset "global_checks.jl" begin
        test_method_tables_sensibility()
    end
end