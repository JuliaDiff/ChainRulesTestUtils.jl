# This is tools for testing ChainRulesTestUtils itself
# if they were less nasty in implementation we might consider moving them to a package
# MetaTesting.jl

struct NonPassingTestset <: Test.AbstractTestSet
    description::String
    results::Vector{Any}
end
NonPassingTestset(desc) = NonPassingTestset(desc, [])

# Records nothing, and throws an error immediately whenever a Fail or
# Error occurs. Takes no action in the event of a Pass or Broken result
Test.record(ts::NonPassingTestset, t) = (@show push!(ts.results, t); t)

function Test.finish(ts::NonPassingTestset)
    if Test.get_testset_depth() != 0
        # Attach this test set to the parent test set *if* it is also a NonPassingTestset
        # Otherwise don't as we don't want to push the errors and failures further up.
        parent_ts = Test.get_testset()
        parent_ts isa NonPassingTestset && Test.record(parent_ts, ts)
        return ts
    end
    return ts
end


"""
    nonpassing_results(f)

`f` should be a function that takes no argument, and calls some code that used `@test`.
Invoking it via `nonpassing_results(f)` will prevent those `@test` being added to the
current testset, and will return a collection of all nonpassing test results.
"""
function nonpassing_results(f)
    mute() do
        try
            # Specify testset type to hijack system
            ts = @testset NonPassingTestset "nonpassing internal" begin
                f()
            end
            return _extract_nonpasses(ts)
        catch err
            # errors thrown in tests can cause it to error upwards, but the exception thrown
            # has exactly the info we need
            err isa Test.TestSetException || rethrow()
            return err.errors_and_fails
        end
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
_extract_nonpasses(ts::NonPassingTestset) = _extract_nonpasses(ts.results)
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
            # Sadly we can't throw the original exception as it is only stored as a String
            error("Error occurred during `fails`")
        end
    end
    return did_fail
end

"""
    errors(f, msg_pattern="")


`errors(f, msg_pattern)` returns true if at least 1 error is recorded into a testset,
    with a failure matching the given pattern.

`f` should be a function that takes no argument, and calls some code that uses `@testset`.
`msg_pattern` is a regex or a string, that should be contained in the error message.
If nothing is passed then it default to the empty string, which matches any error message.

If a test fails (rather than passing or erroring) then `errors` will throw an error.
"""
function errors(f, msg_pattern="")
    results = nonpassing_results(f)

    for result in results
        result isa Test.Fail && error("Test actually failed (nor errored): \n $result")
        result isa Test.Error && occursin(msg_pattern, result.value) && return true
    end
    return false  # no matching error occured
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
            @test fails[1].orig_expr == :(false==true)
            @test fails[2].orig_expr == :(true==false)
        end


        @testset "Single Error" begin
            bads = nonpassing_results(()->error("noo"))
            @test length(bads) === 1
            @test bads[1] isa Test.Error
        end

        @testset "Single Test Erroring" begin
            bads = nonpassing_results(()->@test error("nooo"))
            @test length(bads) === 1
            @test bads[1] isa Test.Error
        end

        @testset "Single Testset Erroring" begin
            bads = nonpassing_results() do
                @testset "inner" begin
                    error("noo")
                end
            end
            @test length(bads) === 1
            @test bads[1] isa Test.Error
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


    @testset "errors" begin
        @test !errors(()->@test true)
        @test errors(()->error("nooo"))
        @test errors(()->error("nooo"), "noo")
        @test !errors(()->error("nooo"), "ok")

        @test errors() do
            @testset "eg" begin
                @test true
                error("nooo")
                @test true
            end
        end

        @test_throws Exception mute() do  # mute it so we don't see the reprinted error.
            errors(()->@test false)
        end
    end
end
