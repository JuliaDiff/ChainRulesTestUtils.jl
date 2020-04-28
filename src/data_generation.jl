# Useful for LinearAlgebra tests
function generate_well_conditioned_matrix(rng, N)
    A = randn(rng, N, N)
    return A * A' + I
end

