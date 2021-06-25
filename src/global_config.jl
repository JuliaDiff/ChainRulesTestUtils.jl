const _fdm = central_fdm(5, 1; max_range=1e-2)
const TEST_INFERRED = Ref(true)
const TRANSFORMS_TO_ALT_TANGENTS = Function[] # e.g. [x -> @thunk(x), _ -> ZeroTangent(), x -> rebasis(x)]

"""
    enable_tangent_transform!(Thunk)

Adds a alt-tangent tranform to the list of default `tangent_transforms` for
[`test_frule`](@ref) and [`test_rrule`](@ref) to test.
This list of defaults is overwritten by the `tangent_transforms` keyword argument.

!!! info "Transitional Feature"
    ChainRulesCore v1.0 will require that all well-behaved rules work for a variety of
    tangent representations. In turn, the corresponding release of ChainRulesTestUtils will 
    test all the different tangent representations by default.
    At that stage `enable_tangent_transform!(Thunk)` will have no effect, as it will already 
    be enabled.
    We provide this configuration as a transitional feature to help migrate your packages
    one feature at a time, prior to the breaking release of ChainRulesTestUtils that will
    enforce it.  
"""
function enable_tangent_transform!(::Type{Thunk})
    push!(TRANSFORMS_TO_ALT_TANGENTS, x->@thunk(x))
    unique!(TRANSFORMS_TO_ALT_TANGENTS)
end

"sets up TEST_INFERRED based ion enviroment variables"
function init_test_inferred_setting!()
    TEST_INFERRED[] = if haskey(ENV, "CHAINRULES_TEST_INFERRED")
        parse(Bool, "CHAINRULES_TEST_INFERRED")
    else
        !parse(Bool, get(ENV, "JULIA_PKGEVAL", "false"))
    end

    !TEST_INFERRED[] && @warn "inference tests have been disabled"
end
