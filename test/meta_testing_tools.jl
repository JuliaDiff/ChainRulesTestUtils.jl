# This is tools for testing ChainRulesTestUtils itself
# if they were less nasty in implementation we might consider moving them to a package
# MetaTesting.jl

# need to bring this into scope explictly so can use in @testset nonpassing_results
using Test: DefaultTestSet

"""
    results(f)

`f` should be a function that takes no argument, and calls some code that used `@test`.
Invoking it via `results(f)` will prevent those `@test` being added to the current testset,
and will instead return a (flat) collection of all the test results.
"""
function results(f)
    mute() do
        res = []
        # Specify testset type incase parent testset is some other typer
        @testset DefaultTestSet "results internal" begin
            f()
            ts = Test.get_testset()  # this is the current testset "nonpassing internal"
            res = _flatten_results(ts)
            # Prevent the failure being recorded in parent testset.
            empty!(ts.results)
            ts.anynonpass = false
        end
        # Note: we allow the "results internal" testset to still be pushed as an empty
        # passing testset in its parent testset. We could remove that if we wanted
        return res
    end
end

"""
    mute(f)

Calls `f()` silencing stdout.
"""
function mute(f)
    # TODO: once we are on Julia 1.6 this can be change to just use
    # `redirect_stdout(devnull)` See: https://github.com/JuliaLang/julia/pull/36146
    mktemp() do path, tempio
        redirect_stdout(tempio) do
            f()
        end
    end
end

_flatten_results(x::Test.Result) = [x,]
_flatten_results(ts::Test.DefaultTestSet) = _flatten_results(ts.results)
function _flatten_results(xs::Vector)
    if isempty(xs)
        return Test.Result[]
    else
        return mapreduce(_flatten_results, vcat, xs)
    end
end

"""
    fails(f)

`f` should be a function that takes no argument, and calls some code that used `@test`.
`fails(f)` returns true if at least 1 `@test` fails.
If a test errors then it will display that error and throw an error of its own.
"""
function fails(f)
    did_fail = false
    for result in results(f)
        did_fail |= result isa Test.Fail
        if result isa Test.Error
            show(result)  # Log a error message, with original backtrace
            # Sadly we can't throw the original exception as it is only stored as a String
            error("Error occurred during `fails`")
        end
    end
    return did_fail
end

"""
    passes(f)

`f` should be a function that takes no argument, and calls some code that used `@test`.
`passes(f)` returns true if at least 1 `@test` passes and none error or fail.
If a test errors then it will display that error and throw an error of its own.
If a test fails then it will display that failure and return false
(Tests that are marked as broken are ignored).
"""
function passes(f)
    did_pass = false
    for result in results(f)
        did_pass |= result isa Test.Pass
        if result isa Test.Fail
            show(result)  # display failure
            return false
        end
        if result isa Test.Error
            show(result)  # Log a error message, with original backtrace
            # Sadly we can't throw the original exception as it is only stored as a String
            error("Error occurred during `passes`")
        end
    end
    return did_pass
end


#Meta Meta tests
@testset "meta_testing_tools.jl" begin
    @testset "results" begin
        @testset "No Tests" begin
            res = results(()->nothing)
            @test length(res) === 0
        end

        @testset "Single Test Pass" begin
            res = results(()->@test true)
            @test length(res) === 1
            @test res[1].orig_expr == true
        end

        @testset "Single Test Fails" begin
            res = results(()->@test false)
            @test length(res) === 1
            @test res[1].orig_expr == false
        end

        @testset "Single Testset" begin
            res = results() do
                @testset "inner" begin
                    @test false == true
                    @test true == true
                    @test true == false
                end
            end
            @test length(res) === 3
            @test res[1].orig_expr == :(false==true)
            @test res[2].orig_expr == :(true==true)
            @test res[3].orig_expr == :(true==false)
        end
    end

    @testset "fails" begin
        @test !fails(()->@test true)
        @test fails(()->@test false)
        @test !fails(()->@test_broken false)

        @test fails() do
            @testset "eg" begin
                @test true
                @test false
                @test true
            end
        end

        @test_throws Exception mute() do  # mute it so we don't see the reprinted error.
            fails(()->@test error("Bad"))
        end
    end

    @testset "passes" begin
        @test passes(()->@test true)
        @test !passes(()->@test false)
        @test !passes(()->@test_broken false)

        @test passes() do
            @testset "eg" begin
                @test true
                @test_broken false
                @test true
            end
        end

        @test !(passes() do
            @testset "eg" begin
                @test true
                @test false
                @test true
            end
        end)

        @test_throws Exception mute() do  # mute it so we don't see the reprinted error.
            passes(()->@test error("Bad"))
        end
    end
end
