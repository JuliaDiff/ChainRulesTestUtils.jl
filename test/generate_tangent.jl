using ChainRulesTestUtils: rand_tangent

@testset "generate_tangent" begin
    rng = MersenneTwister(123456)

    # Numbers
    @test rand_tangent(rng, 4) isa Zero

    @test rand_tangent(rng, 5.0) isa Float64
    @test rand_tangent(rng, 5.0 + 0.4im) isa Complex{Float64}

    # StridedArrays
    @test rand_tangent(rng, randn(Float32, 3)) isa Vector{Float32}
    @test rand_tangent(rng, randn(Complex{Float64}, 2)) isa Vector{Complex{Float64}}

    @test rand_tangent(rng, randn(5, 4)) isa Matrix{Float64}
    @test rand_tangent(rng, randn(Complex{Float32}, 5, 4)) isa Matrix{Complex{Float32}}

    @test rand_tangent(rng, [randn(5, 4), 4.0])[1] isa Matrix{Float64}
    @test rand_tangent(rng, [randn(5, 4), 4.0])[2] isa Float64

    # Tuples
    @test rand_tangent(rng, (4.0, )) isa Composite{Tuple{Float64}}
    @test rand_tangent(rng, (5.0, randn(3))) isa Composite{Tuple{Float64, Vector{Float64}}}

    # NamedTuples
    @test rand_tangent(rng, (a=4.0, )) isa Composite{NamedTuple{(:a,), Tuple{Float64}}}
    @test rand_tangent(rng, (a=5.0, b=1)) isa
        Composite{NamedTuple{(:a, :b), Tuple{Float64, Int}}}
end
