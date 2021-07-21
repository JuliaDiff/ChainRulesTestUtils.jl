"""
    TestIterator{T,IS<:Base.IteratorSize,IE<:Base.IteratorEltype}

A configurable iterator for testing purposes.

    TestIterator(data, itersize, itereltype)
    TestIterator(data)

The iterator wraps another iterator `data`, such as an array, that must have at least as
many features implemented as the test iterator and have a `FiniteDifferences.to_vec`
overload. By default, the iterator it has the same features as `data`.

The optional methods `eltype`, `length`, and `size` are automatically defined and forwarded
to `data` if the type arguments indicate that they should be defined.
"""
struct TestIterator{T,IS,IE}
    data::T
end
function TestIterator(data, itersize::Base.IteratorSize, itereltype::Base.IteratorEltype)
    return TestIterator{typeof(data),typeof(itersize),typeof(itereltype)}(data)
end
TestIterator(data) = TestIterator(data, Base.IteratorSize(data), Base.IteratorEltype(data))

Base.iterate(iter::TestIterator) = iterate(iter.data)
Base.iterate(iter::TestIterator, state) = iterate(iter.data, state)

Base.IteratorSize(::Type{<:TestIterator{<:Any,IS}}) where {IS} = IS()

Base.IteratorEltype(::Type{<:TestIterator{<:Any,<:Any,IE}}) where {IE} = IE()

Base.eltype(::Type{<:TestIterator{T,<:Any,Base.HasEltype}}) where {T} = eltype(T)

Base.length(iter::TestIterator{<:Any,Base.HasLength}) = length(iter.data)
Base.length(iter::TestIterator{<:Any,<:Base.HasShape}) = length(iter.data)

Base.size(iter::TestIterator{<:Any,<:Base.HasShape}) = size(iter.data)

Base.:(==)(iter1::T, iter2::T) where {T<:TestIterator} = iter1.data == iter2.data

Base.isequal(iter1::T, iter2::T) where {T<:TestIterator} = isequal(iter1.data, iter2.data)

function Base.hash(iter::TestIterator{<:Any,IT,IS}) where {IT,IS}
    return mapreduce(hash, hash, (iter.data, IT, IS))
end

# To make it a valid differential: needs at very least `zero` and `+`
Base.zero(::Type{<:TestIterator}) = ZeroTangent()
function Base.:+(iter1::TestIterator{T,IS,IE}, iter2::TestIterator{T,IS,IE}) where {T,IS,IE}
    return TestIterator{T,IS,IE}(map(+, iter1.data, iter2.data))
end

# For testing purposes:

function rand_tangent(rng::AbstractRNG, x::TestIterator{<:Any,IS,IE}) where {IS,IE}
    ∂data = rand_tangent(rng, x.data)
    return TestIterator{typeof(∂data),IS,IE}(∂data)
end

function FiniteDifferences.to_vec(iter::TestIterator)
    iter_vec, back = to_vec(iter.data)
    function TestIterator_from_vec(v)
        return TestIterator(back(v), Base.IteratorSize(iter), Base.IteratorEltype(iter))
    end
    return iter_vec, TestIterator_from_vec
end
