"""
    _parameters(type)
Extracts the type-parameters of the `type`.
e.g. `_parameters(Foo{A, B, C}) == [A, B, C]`
"""
_parameters(sig::UnionAll) = _parameters(sig.body)
_parameters(sig::DataType) = sig.parameters
_parameters(sig::Union) = Base.uniontypes(sig)

"""
    test_method_tables_sensibility()

Checks that the method tables for `rrule` and `frule` are sensible.
This in future may carry out a number of checks, but presently just checks to make sure that
no rules have been added to the very general `DataType`, `Union` or `UnionAll` types.
This is easy to do when writing rules for constructors.
It happens if you writeg. `rrule(::typeof(Foo), x)` rather than `rrule(::Type{<:Foo}, x)`:
This would then actually define `rrule(::DataType, x)`. (or `UnionAll` if `Foo`
was parametric, or `Union` if `Foo` was a type alias for a `Union`)
"""
function test_method_tables_sensibility()
    @testset "Make sure methods haven't been added to DataType/UnionAll/Union" begin
        # if someone wrote e.g. `rrule(::typeof(Foo), x)` rather than
        # `rrule(::Type{<:Foo}, x)` then that would actually define `rrule(::DataType, x)`
        # which would be bad. This test checks for that and fails if such a method exists.
        for method in methods(rrule)
            function_type = if method.sig <: Tuple{Any, RuleConfig, Type, Vararg}
                _parameters(method.sig)[3]
            elseif method.sig <: Tuple{Any, Type, Vararg}
                _parameters(method.sig)[2]
            else
                nothing
            end
            
            if function_type ∈ (DataType, UnionAll Union)
                @error "Bad constructor rrule. typeof(T)` not `Type{T}`" method
                @test false
            end
        end

        # frule
        for method in methods(frule)
            function_type = if method.sig <: Tuple{Any, RuleConfig, Any, Type, Vararg}
                _parameters(method.sig)[4]
            elseif method.sig <: Tuple{Any, Any, Type, Vararg}
                @show _parameters(method.sig)[3]
            else
                nothing
            end
            
            if function_type ∈ (DataType, UnionAll Union)
                @error "Bad constructor frule. typeof(T)` not `Type{T}`" method
                @test false
            end
        end
end
