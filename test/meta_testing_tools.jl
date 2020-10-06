# This is tools for testing ChainRulesTestUtils itself
# if they were less nasty in implementation we might consider moving them to a package
# MetaTesting.jl

"""
    metatest_get_failures(f)

`f` should be a function that takes no argument, and calls some code that used `@test`.
Invoking it via `metatest_get_failures(f)` will prevent those `@test` being added to the
current testset, and will return a collection of all nonpassing test results.
"""
function metatest_get_failures(f)
    redirect_stdout(stdout) do
        failures = []
        @testset "dummy" begin
            f()
            ts = Test.get_testset()
            failures = _extract_failures(ts)
            # Prevent the failure being recorded in parent testset.
            empty!(ts.results)
            ts.anynonpass = false
        end
        return failures
   end
end

"extracts as flat collection of failures from a (potential nested) testset"
_extract_failures(x::Test.Result) = [x,]
_extract_failures(x::Test.Pass) = Test.Result[]
_extract_failures(ts::Test.DefaultTestSet) = _extract_failures(ts.results)
function _extract_failures(xs::Vector)
    if isempty(xs)
        return Test.Result[]
    else
        return mapreduce(_extract_failures, vcat, xs)
    end
end

#Meta Meta tests
@testset "meta_testing_tools.jl" begin
    @testset "metatest_get_failures" begin
        @testset "No Tests" begin
            fails = metatest_get_failures(()->nothing)
            @test length(fails) === 0
        end

        @testset "No Failures" begin
            fails = metatest_get_failures(()->@test true)
            @test length(fails) === 0
        end


        @testset "Single Test" begin
            fails = metatest_get_failures(()->@test false)
            @test length(fails) === 1
            @test fails[1].orig_expr == false
        end

        @testset "Single Testset" begin
            fails = metatest_get_failures() do
                @testset "inner" begin
                    @test false == true
                    @test true == false
                end
            end
            @test length(fails) === 2
            @test fails[1].orig_expr == :(false==true)
            @test fails[2].orig_expr == :(true==false)
        end
    end
end
