using Random

# Useful for LinearAlgebra tests
function generate_well_conditioned_matrix(rng, N)
    A = randn(rng, N, N)
    return A * A' + I
end

generate_well_conditioned_matrix(N) = generate_well_conditioned_matrix(Random.GLOBAL_RNG, N)