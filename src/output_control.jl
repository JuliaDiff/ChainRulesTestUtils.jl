# Test.get_test_result generates code that uses the following so we must import them
using Test: Returned, Threw, eval_test

@static if VERSION >= v"1.13.0-DEV.300"
    # https://github.com/JuliaLang/julia/commit/d934b032ea5bf63b353371ad285605128c735873
    # used by `Test.do_test` in `macro test_msg`
    using Test: eval_test_comparison, eval_test_function
end

"A cunning hack to carry extra message along with the original expression in a test"
struct ExprAndMsg
    ex
    msg
end

"""
    @test_msg msg condion kws...

This is per `Test.@test condion kws...` except that if it fails it also prints the `msg`.
If `msg==""` then this is just like `@test`, nothing is printed

### Examles
```julia
julia> @test_msg "It is required that the total is under 10" sum(1:1000) < 10;
Test Failed at REPL[1]:1
  Expression: sum(1:1000) < 10
  Problem: It is required that the total is under 10
   Evaluated: 500500 < 10
ERROR: There was an error during testing


julia> @test_msg "It is required that the total is under 10" error("not working at all");
Error During Test at REPL[2]:1
  Test threw exception
  Expression: error("not working at all")
  Problem: It is required that the total is under 10
  "not working at all"
  Stacktrace:

julia> a = "";

julia> @test_msg a sum(1:1000) < 10;
  Test Failed at REPL[153]:1
    Expression: sum(1:1000) < 10
     Evaluated: 500500 < 10
  ERROR: There was an error during testing
```
"""
macro test_msg(msg, ex, kws...)
    # This code is basically a evil hack that accesses the internals of the Test stdlib.
    # Code below is based on the `@test` macro definition as it was in Julia 1.6.
    # https://github.com/JuliaLang/julia/blob/v1.6.1/stdlib/Test/src/Test.jl#L371-L376
    Test.test_expr!("@test_msg msg", ex, kws...)

    result = Test.get_test_result(ex, __source__)
    return :(Test.do_test($result, $ExprAndMsg($(string(ex)), $(esc(msg)))))
end

function Base.print(io::IO, x::ExprAndMsg)
    print(io, x.ex)
    !isempty(x.msg) && print(io, "\n  Problem: ", x.msg)
end


### helpers for printing in log messages etc
_string_typeof(x) = string(typeof(x))
_string_typeof(xs::Tuple) = join(_string_typeof.(xs), ",")
_string_typeof(x::PrimalAndTangent) = _string_typeof(primal(x))  # only show primal
