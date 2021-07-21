# Useful for LinearAlgebra tests
function generate_well_conditioned_matrix(rng::AbstractRNG, T, N)
    A = randn(rng, T, N, N)
    return A * A' + I
end

function generate_well_conditioned_matrix(rng::AbstractRNG, N)
    return generate_well_conditioned_matrix(rng, Float64, N)
end

generate_well_conditioned_matrix(N) = generate_well_conditioned_matrix(Random.GLOBAL_RNG, N)

function generate_well_conditioned_matrix(T, N)
    return generate_well_conditioned_matrix(Random.GLOBAL_RNG, T, N)
end
