var documenterSearchIndex = {"docs":
[{"location":"api.html#API-Documentation","page":"API","title":"API Documentation","text":"","category":"section"},{"location":"api.html","page":"API","title":"API","text":"Modules = [ChainRulesTestUtils]\nPrivate = false","category":"page"},{"location":"api.html#ChainRulesTestUtils.:⊢","page":"API","title":"ChainRulesTestUtils.:⊢","text":"primal ⊢ tangent\n\nInfix shorthand method to construct a PrimalAndTangent. Enter via \\vdash + tab on supporting editors.\n\n\n\n\n\n","category":"type"},{"location":"api.html#ChainRulesTestUtils.TestIterator","page":"API","title":"ChainRulesTestUtils.TestIterator","text":"TestIterator{T,IS<:Base.IteratorSize,IE<:Base.IteratorEltype}\n\nA configurable iterator for testing purposes.\n\nTestIterator(data, itersize, itereltype)\nTestIterator(data)\n\nThe iterator wraps another iterator data, such as an array, that must have at least as many features implemented as the test iterator and have a FiniteDifferences.to_vec overload. By default, the iterator it has the same features as data.\n\nThe optional methods eltype, length, and size are automatically defined and forwarded to data if the type arguments indicate that they should be defined.\n\n\n\n\n\n","category":"type"},{"location":"api.html#ChainRulesTestUtils.rand_tangent-Tuple{Any}","page":"API","title":"ChainRulesTestUtils.rand_tangent","text":"rand_tangent([rng::AbstractRNG,] x)\n\nReturns a arbitary tangent vector appropriate for the primal value x. Note that despite the name, no promises on the statistical randomness are made. Rather it is an arbitary value, that is generated using the rng.\n\n\n\n\n\n","category":"method"},{"location":"api.html#ChainRulesTestUtils.test_approx","page":"API","title":"ChainRulesTestUtils.test_approx","text":"test_approx(actual, expected, [msg]; kwargs...)\n\n@test's  that actual ≈ expected, but breaks up data such that human readable results are shown on failures. Understands things like unthunking ChainRuleCore.Thunks, etc.\n\nIf provided msg is printed on a failure. Often additional items are appended to msg to give bread-crumbs into nested structures.\n\nAll keyword arguments are passed to isapprox.\n\n\n\n\n\n","category":"function"},{"location":"api.html#ChainRulesTestUtils.test_frule-Tuple","page":"API","title":"ChainRulesTestUtils.test_frule","text":"test_frule([config::RuleConfig,] f, args..; kwargs...)\n\nArguments\n\nconfig: defaults to ChainRulesTestUtils.ADviaRuleConfig.\nf: function for which the frule should be tested. Its tangent can be provided using f ⊢ ḟ. (You can enter ⊢ via \\vdash + tab in the Julia REPL and supporting editors.)\nargs...: either the primal args x, or primals and their tangents: x ⊢ ẋ\nx: input at which to evaluate f (should generally be set to an arbitrary point in the domain).\nẋ: differential w.r.t. x; will be generated automatically if not provided.\nNon-differentiable arguments, such as indices, should have ẋ set as NoTangent().\n\nKeyword Arguments\n\noutput_tangent: tangent against which to test accumulation of derivatives. Should be a differential for the output of f. Is set automatically if not provided.\nfdm::FiniteDifferenceMethod: the finite differencing method to use.\nfrule_f=frule: function with an frule-like API that is tested (defaults to frule). Used for testing gradients from AD systems.\nIf check_inferred=true, then the inferrability (type-stability) of the frule is checked, as long as f is itself inferrable.\nfkwargs are passed to f as keyword arguments.\nAll remaining keyword arguments are passed to isapprox.\n\n\n\n\n\n","category":"method"},{"location":"api.html#ChainRulesTestUtils.test_rrule-Tuple","page":"API","title":"ChainRulesTestUtils.test_rrule","text":"test_rrule([config::RuleConfig,] f, args...; kwargs...)\n\nArguments\n\nconfig: defaults to ChainRulesTestUtils.ADviaRuleConfig.\nf: function for which the rrule should be tested. Its tangent can be provided using f ⊢ f̄. (You can enter ⊢ via \\vdash + tab in the Julia REPL and supporting editors.)\nargs...: either the primal args x, or primals and their tangents: x ⊢ x̄\nx: input at which to evaluate f (should generally be set to an arbitrary point in the domain).\nx̄: currently accumulated cotangent; will be generated automatically if not provided.\nNon-differentiable arguments, such as indices, should have x̄ set as NoTangent().\n\nKeyword Arguments\n\noutput_tangent: the seed to propagate backward for testing (technically a cotangent). should be a differential for the output of f. Is set automatically if not provided.\ncheck_thunked_output_tangent=true: also checks that passing a thunked version of the   output tangent to the pullback returns the same result.\nfdm::FiniteDifferenceMethod: the finite differencing method to use.\nrrule_f=rrule: function with an rrule-like API that is tested (defaults to rrule). Used for testing gradients from AD systems.\nIf check_inferred=true, then the inferrability (type-stability) of the rrule is checked — if f is itself inferrable — along with the inferrability of the pullback it returns.\nfkwargs are passed to f as keyword arguments.\nAll remaining keyword arguments are passed to isapprox.\n\n\n\n\n\n","category":"method"},{"location":"api.html#ChainRulesTestUtils.test_scalar-Tuple{Any, Any}","page":"API","title":"ChainRulesTestUtils.test_scalar","text":"test_scalar(f, z; rtol=1e-9, atol=1e-9, fdm=central_fdm(5, 1), fkwargs=NamedTuple(), check_inferred=true, kwargs...)\n\nGiven a function f with scalar input and scalar output, perform finite differencing checks, at input point z to confirm that there are correct frule and rrules provided.\n\nArguments\n\nf: function for which the frule and rrule should be tested.\nz: input at which to evaluate f (should generally be set to an arbitrary point in the domain).\n\nKeyword Arguments\n\nfdm: the finite differencing method to use.\nfkwargs are passed to f as keyword arguments.\nIf check_inferred=true, then the inferrability (type-stability) of the frule and rrule are checked.\nAll remaining keyword arguments are passed to isapprox.\n\n\n\n\n\n","category":"method"},{"location":"api.html#ChainRulesTestUtils.@maybe_inferred-Tuple","page":"API","title":"ChainRulesTestUtils.@maybe_inferred","text":"@maybe_inferred [Type] f(...)\n\nLike @inferred, but does not check the return type if tests are run as part of PkgEval or if the environment variable CHAINRULES_TEST_INFERRED is set to false.\n\n\n\n\n\n","category":"macro"},{"location":"index.html#ChainRulesTestUtils","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"(Image: CI) (Image: Code Style: Blue)","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"ChainRulesTestUtils.jl helps you test ChainRulesCore.frule and ChainRulesCore.rrule methods, when adding rules for your functions in your own packages. For information about ChainRules, including how to write rules, refer to the general ChainRules Documentation: (Image: ) (Image: )","category":"page"},{"location":"index.html#Canonical-example-of-testing-frule-and-rrule","page":"ChainRulesTestUtils","title":"Canonical example of testing frule and rrule","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"Let's suppose a custom transformation has been defined","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"function two2three(x1::Float64, x2::Float64)\n    return 1.0, 2.0*x1, 3.0*x2\nend\n\n# output\ntwo2three (generic function with 1 method)","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"along with the frule","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"using ChainRulesCore\n\nfunction ChainRulesCore.frule((Δf, Δx1, Δx2), ::typeof(two2three), x1, x2)\n    y = two2three(x1, x2)\n    ∂y = Tangent{Tuple{Float64, Float64, Float64}}(ZeroTangent(), 2.0*Δx1, 3.0*Δx2)\n    return y, ∂y\nend\n# output\n","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"and rrule","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"function ChainRulesCore.rrule(::typeof(two2three), x1, x2)\n    y = two2three(x1, x2)\n    function two2three_pullback(Ȳ)\n        return (NoTangent(), 2.0*Ȳ[2], 3.0*Ȳ[3])\n    end\n    return y, two2three_pullback\nend\n# output\n","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"The test_frule/test_rrule helper function compares the frule/rrule outputs to the gradients obtained by finite differencing. They can be used for any type and number of inputs and outputs.","category":"page"},{"location":"index.html#Testing-the-frule","page":"ChainRulesTestUtils","title":"Testing the frule","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"test_frule takes in the function f and the primal input x. The call will test the frule for function f at the point x in the domain. Keep this in mind when testing discontinuous rules for functions like ReLU, which should ideally be tested at both x being above and below zero.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"julia> using ChainRulesTestUtils;\n\njulia> test_frule(two2three, 3.33, -7.77);\nTest Summary:                            | Pass  Total\ntest_frule: two2three on Float64,Float64 |    6      6\n","category":"page"},{"location":"index.html#Testing-the-rrule","page":"ChainRulesTestUtils","title":"Testing the rrule","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"test_rrule takes in the function f, and primal inputsr x. The call will test the rrule for function f at the point x, and similarly to frule some rules should be tested at multiple points in the domain.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"julia> test_rrule(two2three, 3.33, -7.77);\nTest Summary:                            | Pass  Total\ntest_rrule: two2three on Float64,Float64 |    9      9\n","category":"page"},{"location":"index.html#Scalar-example","page":"ChainRulesTestUtils","title":"Scalar example","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"For functions with a single argument and a single output, such as e.g. ReLU,","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"function relu(x::Real)\n    return max(0, x)\nend\n\n# output\nrelu (generic function with 1 method)","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"with the frule and rrule defined with the help of @scalar_rule macro","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"@scalar_rule relu(x::Real) x <= 0 ? zero(x) : one(x)\n\n# output\n","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"test_scalar function is provided to test both the frule and the rrule with a single call.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"julia> test_scalar(relu, 0.5);\nTest Summary:            | Pass  Total\ntest_scalar: relu at 0.5 |   11     11\n\n\njulia> test_scalar(relu, -0.5);\nTest Summary:             | Pass  Total\ntest_scalar: relu at -0.5 |   11     11\n","category":"page"},{"location":"index.html#Testing-constructors-and-functors-(callable-objects)","page":"ChainRulesTestUtils","title":"Testing constructors and functors (callable objects)","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"Testing constructor and functors works as you would expect. For struct Foo","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"struct Foo\n    a::Float64\nend\n(f::Foo)(x) = return f.a + x\nBase.length(::Foo) = 1\nBase.iterate(f::Foo) = iterate(f.a)\nBase.iterate(f::Foo, state) = iterate(f.a, state)","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"the f/rrules can be tested by","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"test_rrule(Foo, rand()) # constructor\n\nfoo = Foo(rand())\ntest_rrule(foo, rand()) # functor\n\n# it is also possible to provide tangents for `foo` explicitly\ntest_frule(foo ⊢ Tangent{Foo}(;a=rand()), rand())","category":"page"},{"location":"index.html#Specifying-Tangents","page":"ChainRulesTestUtils","title":"Specifying Tangents","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"test_frule and test_rrule allow you to specify the tangents used for testing. By default, tangents will be automatically generated via FiniteDifferences.rand_tangent. To explicitly specify a tangent, pass in x ⊢ Δx, where x is the primal and Δx is the tangent, in the place of the primal inputs. (You can enter ⊢ via \\vdash + tab in the Julia REPL and supporting editors.) A special case of this is that if you specify it as x ⊢ NoTangent() then finite differencing will not be used on that input. Similarly, by setting the output_tangent keyword argument, you can specify the tangent for the primal output.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"This can be useful when the default provided FiniteDifferences.rand_tangent doesn't produce the desired tangent for your type. For example, the default tangent for an Int is NoTangent(), which is correct e.g. when the Int represents a discrete integer like in indexing. But if you are testing something where the Int is actually a special case of a real number, then you would want to specify the tangent as a Float64.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"Care must be taken when manually specifying tangents. In particular, when specifying the input tangents to test_frule and the output tangent to test_rrule. As these tangents are used to seed the derivative computation. Inserting inappropriate zeros can thus hide errors.","category":"page"},{"location":"index.html#Testing-higher-order-functions","page":"ChainRulesTestUtils","title":"Testing higher order functions","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"Higher order functions, such as map, take a function (or a functor) f as an argument. f/rrules for these functions call back into AD to compute the f/rrule of f. To test these functions, we use a dummy AD system, which simply calls the appropriate rule for f directly. For this reason, when testing map(f, collection), the rules for f need to be defined. The RuleConfig for this dummy AD system is the default one, and does not need to be provided.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"test_rrule(map, x->2x [1, 2, 3.]) # fails, because there is no rrule for x->2x\n\nmydouble(x) = 2x\nfunction ChainRulesCore.rrule(::typeof(mydouble), x)\n    mydouble_pullback(ȳ) = (NoTangent(), ȳ)\n    return mydouble(x), mydouble_pullback\nend\ntest_rrule(map, mydouble, [1, 2, 3.]) # works","category":"page"},{"location":"index.html#Testing-AD-systems","page":"ChainRulesTestUtils","title":"Testing AD systems","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"The gradients computed by AD systems can be also be tested using test_rrule. To do that, one needs to provide an rrule_f/frule_f keyword argument, as well as the RuleConfig used by the AD system. rrule_f is a function that wraps the gradient computation by an AD system in the same API as the rrule. RuleConfig is an object that determines which sets of rules are defined for an AD system. For example, let's say we have a complicated function","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"function complicated(x, y)\n    return do(x + y) + some(x) * hard(y) + maths(x * y)\nend","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"that we do not know an rrule for, and we want to check whether the gradients provided by the AD system are correct.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"To test gradients computed by the AD system you need to provide a rrule_f function that acts like calling rrule but use AD rather than a defined rule. This has the exact same semantics as is required to overload ChainRulesCore.rrule_via_ad, thus almost all systems doing so should just overload that, and pass in that and the config, and then trigger test_rrule(MyADConfig, f, xs; rrule_f = ChainRulesCore.rrule_via_ad). See more info on rrule_via_ad and the rule configs in the ChainRules documentation. For some AD systems (e.g. Zygote) rrule_via_ad already exists. If it does not exist, see How to write rrule_via_ad function section below.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"We use the test_rrule function to test the gradients using the config used by the AD system","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"config = MyAD.CustomRuleConfig()\ntest_rrule(config, complicated, 2.3, 6.1; rrule_f=rrule_via_ad)","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"by providing the rule config and specifying the rrule_via_ad as the rrule_f keyword argument.","category":"page"},{"location":"index.html#How-to-write-rrule_via_ad-function","page":"ChainRulesTestUtils","title":"How to write rrule_via_ad function","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"rrule_via_ad will use the AD system to compute gradients and will package them in the rrule-like API.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"Let's say the AD package uses some custom differential types and does not provide a gradient w.r.t. the function itself. In order to make the pullback compatible with the rrule API we need to add a NoTangent() to represent the differential w.r.t. the function itself. We also need to transform the ChainRules differential types to the custom types (cr2custom) before feeding the Δ to the AD-generated pullback, and back to ChainRules differential types when returning from the rrule (custom2cr).","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"function rrule_via_ad(config::MyAD.CustomRuleConfig, f::Function, args...)\n    y, ad_pullback = MyAD.pullback(f, args...)\n    function rrulelike_pullback(Δ)\n        diffs = custom2cr(ad_pullback(cr2custom(Δ)))\n        return NoTangent(), diffs...\n    end\n        \n    return y, rrulelike_pullback\nend\n\ncustom2cr(differential) = ...\ncr2custom(differential) = ...","category":"page"},{"location":"index.html#Custom-finite-differencing","page":"ChainRulesTestUtils","title":"Custom finite differencing","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"If a package is using a custom finite differencing method of testing the frules and rrules, test_approx function provides a convenient way of comparing various types of differentials.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"It is effectively (a, b) -> @test isapprox(a, b), but it preprocesses thunks and ChainRules differential types ZeroTangent(), NoTangent(), and Tangent, such that the error messages are helpful.","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"For example,","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"test_approx((@thunk 2*2.0), 4.1)","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"shows both the expression and the evaluated thunks","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"   Expression: isapprox(actual, expected; kwargs...)\n   Evaluated: isapprox(4.0, 4.1)\nERROR: There was an error during testing","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"compared to","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"julia> @test isapprox(@thunk 2*2.0, 4.0)\nTest Failed at REPL[52]:1\n  Expression: isapprox(#= REPL[52]:1 =# @thunk((2 * 2.0, 4.0)))\n   Evaluated: isapprox(Thunk(var\"#24#25\"()))\nERROR: There was an error during testing","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"which should have passed the test.","category":"page"},{"location":"index.html#Inference-tests","page":"ChainRulesTestUtils","title":"Inference tests","text":"","category":"section"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"By default, all functions for testing rules check whether the output type (as well as that of the pullback for rrules) can be completely inferred, such that everything is type stable:","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"julia> function ChainRulesCore.rrule(::typeof(abs), x)\n           abs_pullback(Δ) = (NoTangent(), x >= 0 ? Δ : big(-1.0) * Δ)\n           return abs(x), abs_pullback\n       end\n\njulia> test_rrule(abs, 1.)\ntest_rrule: abs on Float64: Error During Test at /home/runner/work/ChainRulesTestUtils.jl/ChainRulesTestUtils.jl/src/testers.jl:170\n  Got exception outside of a @test\n  return type Tuple{ChainRulesCore.NoTangent, Float64} does not match inferred return type Tuple{ChainRulesCore.NoTangent, Union{Float64, BigFloat}}\n[...]","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"This can be disabled on a per-rule basis using the check_inferred keyword argument:","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"julia> test_rrule(abs, 1.; check_inferred=false)\nTest Summary:              | Pass  Total\ntest_rrule: abs on Float64 |    5      5\nTest.DefaultTestSet(\"test_rrule: abs on Float64\", Any[], 5, false, false)","category":"page"},{"location":"index.html","page":"ChainRulesTestUtils","title":"ChainRulesTestUtils","text":"This behavior can also be overridden globally by setting the environment variable CHAINRULES_TEST_INFERRED before ChainRulesTestUtils is loaded or by changing ChainRulesTestUtils.TEST_INFERRED[] from inside Julia. ChainRulesTestUtils can detect whether a test is run as part of PkgEval and in this case disables inference tests automatically. Packages can use @maybe_inferred to get the same behavior for other inference tests.","category":"page"}]
}
