const _fdm = central_fdm(5, 1; max_range=1e-2)
const TEST_INFERRED = Ref(true)
const TRANSFORMS_TO_ALT_TANGENTS = Function[] # e.g. [x -> @thunk(x), _ -> ZeroTangent(), x -> rebasis(x)]



"sets up TEST_INFERRED based ion enviroment variables"
function init_test_inferred_setting!()
    TEST_INFERRED[] = if haskey(ENV, "CHAINRULES_TEST_INFERRED")
        parse(Bool, "CHAINRULES_TEST_INFERRED")
    else
        !parse(Bool, get(ENV, "JULIA_PKGEVAL", "false"))
    end

    !TEST_INFERRED[] && @warn "inference tests have been disabled"
end
