# This is tools for testing ChainRulesTestUtils itself
# if they were less nasty in implementation we might consider moving them to a package
# MetaTesting.jl

# need to bring this into scope explictly so can use in @testset nonpassing_results
using Test: DefaultTestSet

"""
    nonpassing_results(f)

`f` should be a function that takes no argument, and calls some code that used `@test`.
Invoking it via `nonpassing_results(f)` will prevent those `@test` being added to the
current testset, and will return a collection of all nonpassing test results.
"""
function nonpassing_results(f)
    mute() do
        nonpasses = []
        # Specify testset type incase parent testset is some other typer
        @testset DefaultTestSet "nonpassing internal" begin
            f()
            ts = Test.get_testset()  # this is the current testset "nonpassing internal"
            nonpasses = _extract_nonpasses(ts)
            # Prevent the failure being recorded in parent testset.
            empty!(ts.results)
            ts.anynonpass = false
        end
        # Note: we allow the "nonpassing internal" testset to still be pushed as an empty
        # passing testset in its parent testset. We could remove that if we wanted
        return nonpasses
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

"extracts as flat collection of failures from a (potential nested) testset"
_extract_nonpasses(x::Test.Result) = [x,]
_extract_nonpasses(x::Test.Pass) = Test.Result[]
_extract_nonpasses(ts::Test.DefaultTestSet) = _extract_nonpasses(ts.results)
function _extract_nonpasses(xs::Vector)
    if isempty(xs)
        return Test.Result[]
    else
        return mapreduce(_extract_nonpasses, vcat, xs)
    end
end

"""
    fails(f)

`f` should be a function that takes no argument, and calls some code that used `@test`.
`fails(f)` returns true if at least 1 `@test` fails.
If a test errors then it will display that error and throw an error of its own.
"""
function fails(f)
    results = nonpassing_results(f)
    did_fail = false
    for result in results
        did_fail |= result isa Test.Fail
        if result isa Test.Error
            # Log a error message, with original backtrace
            show(result)
            # Sadly we can't throw the original exception as it is only stored as a String
            error("Error occurred during `fails`")
        end
    end
    return did_fail
end

#Meta Meta tests
@testset "meta_testing_tools.jl" begin
    @testset "Checking for non-passes" begin
        @testset "No Tests" begin
            fails = nonpassing_results(()->nothing)
            @test length(fails) === 0
        end

        @testset "No Failures" begin
            fails = nonpassing_results(()->@test true)
            @test length(fails) === 0
        end


        @testset "Single Test" begin
            fails = nonpassing_results(()->@test false)
            @test length(fails) === 1
            @test fails[1].orig_expr == false
        end

        @testset "Single Testset" begin
            fails = nonpassing_results() do
                @testset "inner" begin
                    @test false == true
                    @test true == false
                end
            end
            @test length(fails) === 2
            

            # Newer versions of Julia return a `String`, not an `Expr`. 
            # Always calling  `string` on it gives gives consistency regardless of version.
            # https://github.com/JuliaLang/julia/pull/37809
            @test string(fails[1].orig_expr) == "false == true"
            @test string(fails[2].orig_expr) == "true == false"
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
end
