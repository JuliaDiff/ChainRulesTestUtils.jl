# Test struct for `rand_tangent` and `difference`.
struct Bar
    a::Float64
    b::Int
    c::Any
 end
@testset "rand_tangent" begin
    rng = MersenneTwister(123456)

    @testset "Primal: $(typeof(x)), Tangent: $T_tangent" for (x, T_tangent) in [

        # Things without sensible tangents.
        ("hi", NoTangent),
        ('a', NoTangent),
        (:a, NoTangent),
        (true, NoTangent),
        (4, NoTangent),
        (FiniteDifferences, NoTangent),  # Module object
        # Types (not instances of type)
        (Bar, NoTangent),  
        (Union{Int, Bar}, NoTangent),
        (Union{Int, Bar}, NoTangent),
        (Vector, NoTangent),
        (Vector{Float64}, NoTangent),
        (Integer, NoTangent),
        (Type{<:Real}, NoTangent),

        # Numbers.
        (5.0, Float64),
        (5.0 + 0.4im, Complex{Float64}),
        (big(5.0), BigFloat),

        # StridedArrays.
        (fill(randn(Float32)), Array{Float32, 0}),
        (fill(randn(Float64)), Array{Float64, 0}),
        (randn(Float32, 3), Vector{Float32}),
        (randn(Complex{Float64}, 2), Vector{Complex{Float64}}),
        (randn(5, 4), Matrix{Float64}),
        (randn(Complex{Float32}, 5, 4), Matrix{Complex{Float32}}),
        ([randn(5, 4), 4.0], Vector{Any}),

        # Co-Arrays
        (randn(5)', Adjoint{Float64, Vector{Float64}}),  # row-vector: special
        (randn(5, 4)', Matrix{Float64}),                 # matrix: generic dense
        
        (transpose(randn(5)), Transpose{Float64, Vector{Float64}}),  # row-vector: special
        (transpose(randn(5, 4)), Matrix{Float64}),                   # matrix: generic dense
        
        # AbstactArrays of non-perturbable types
        (1:10, NoTangent),
        (1:2:10, NoTangent),
        ([false, true], NoTangent),

        # Tuples.
        ((4.0, ), Tangent{Tuple{Float64}}),
        ((5.0, randn(3)), Tangent{Tuple{Float64, Vector{Float64}}}),
        ((false, true), NoTangent),
        (Tuple{}(), NoTangent),

        # NamedTuples.
        ((a=4.0, ), Tangent{NamedTuple{(:a,), Tuple{Float64}}}),
        ((a=5.0, b=1), Tangent{NamedTuple{(:a, :b), Tuple{Float64, Int}}}),
        ((a=false, b=true), NoTangent),
        ((;), NoTangent),

        # structs.
        (Bar(5.0, 4, rand(rng, 3)), Tangent{Bar}),
        (Bar(4.0, 3, Bar(5.0, 2, 4)), Tangent{Bar}),
        (sin, NoTangent),
        # all fields NoTangent implies NoTangent
        (Pair(:a, "b"), NoTangent),
        (CartesianIndex(2, 3), NoTangent),

        # LinearAlgebra types
        (
            UpperTriangular(randn(3, 3)),
            UpperTriangular{Float64, Matrix{Float64}},
        ),
        (
            Diagonal(randn(2)),
            Diagonal{Float64, Vector{Float64}},
        ),
        (
            Symmetric(randn(2, 2)),
            Symmetric{Float64, Matrix{Float64}},
        ),
        (
            Hermitian(randn(ComplexF64, 1, 1)),
            Hermitian{ComplexF64, Matrix{ComplexF64}},
        ),
        
        # SparseArrays
        (sprand(5, 4, 0.3), SparseMatrixCSC{Float64, Int64}),
        (sprand(5, 4, 0.3)', SparseMatrixCSC{Float64, Int64}),
        (sprand(ComplexF64, 5, 4, 0.3), SparseMatrixCSC{ComplexF64, Int64}),
        (sprand(ComplexF64, 5, 4, 0.3)', SparseMatrixCSC{ComplexF64, Int64}),
    ]
        @test rand_tangent(rng, x) isa T_tangent
        @test rand_tangent(x) isa T_tangent
    end

    @testset "erroring cases" begin
        # Ensure struct fallback errors for non-struct types.
        @test_throws ArgumentError invoke(rand_tangent, Tuple{AbstractRNG, Any}, rng, 5.0)
    end

    @testset "compsition of addition" begin
        x = Bar(1.5, 2, Bar(1.1, 3, [1.7, 1.4, 0.9]))
        @test x + rand_tangent(x) isa typeof(x)
        @test x + (rand_tangent(x) + rand_tangent(x)) isa typeof(x)
    end

    # Julia 1.6 changed to using Ryu printing algorithm and seems better at printing short
    VERSION >= v"1.6" && @testset "niceness of printing" begin
        rng = MersenneTwister(1)
        for i in 1:50
            @test length(string(rand_tangent(rng, 1.0))) <= 6
            @test length(string(rand_tangent(rng, 1.0 + 1.0im))) <= 12
            @test length(string(rand_tangent(rng, 1f0))) <= 9
            @test length(string(rand_tangent(rng, big"1.0"))) <= 9
        end
    end
end

