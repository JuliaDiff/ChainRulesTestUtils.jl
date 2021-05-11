@testset "TestIterator" begin
    @testset "Constructors" begin
        data = randn(3)
        iter = TestIterator(data)
        @test iter isa TestIterator{
            typeof(data),
            typeof(Base.IteratorSize(data)),
            typeof(Base.IteratorEltype(data)),
        }
        @test iter.data === data

        data = randn(2, 3, 4)
        iter = TestIterator(data)
        @test iter isa TestIterator{
            typeof(data),
            typeof(Base.IteratorSize(data)),
            typeof(Base.IteratorEltype(data)),
        }
        @test iter.data === data

        data = randn(2, 3, 4)
        iter = TestIterator(data, Base.SizeUnknown(), Base.EltypeUnknown())
        @test iter isa TestIterator{typeof(data),Base.SizeUnknown,Base.EltypeUnknown}
    end

    @testset "iterate" begin
        data = randn(3)
        iter = TestIterator(data)

        @test iterate(iter) === iterate(data)
        _, state = iterate(data)
        @test iterate(iter, state) === iterate(data, state)
    end

    @testset "optional interface methods" begin
        data = randn(2, 3, 4)
        iter = TestIterator(data)
        @test eltype(iter) === eltype(data)
        @test length(iter) === length(data)
        @test size(iter) === size(data)

        iter = TestIterator(data, Base.HasLength(), Base.HasEltype())
        @test length(iter) === length(data)
        @test_throws MethodError size(iter)
        @test eltype(iter) === eltype(iter)

        iter = TestIterator(data, Base.SizeUnknown(), Base.EltypeUnknown())
        @test_throws MethodError length(iter)
        @test eltype(iter) === Any
    end

    @testset "==" begin
        data = randn(2, 3, 4)
        iter1 = TestIterator(data, Base.HasLength(), Base.HasEltype())
        iter2 = TestIterator(data, Base.HasLength(), Base.EltypeUnknown())
        @test iter2 != iter1

        iter3 = TestIterator(copy(data), Base.HasLength(), Base.HasEltype())
        @test iter3 == iter1
    end

    @testset "isequal" begin
        data = randn(2, 3, 4)
        iter1 = TestIterator(data, Base.HasLength(), Base.HasEltype())
        iter2 = TestIterator(data, Base.HasLength(), Base.EltypeUnknown())
        @test !isequal(iter2, iter1)

        iter3 = TestIterator(copy(data), Base.HasLength(), Base.HasEltype())
        @test isequal(iter3, iter1)
    end

    @testset "hash" begin
        data = randn(2, 3, 4)
        iter1 = TestIterator(data, Base.HasLength(), Base.HasEltype())
        iter2 = TestIterator(data, Base.HasLength(), Base.EltypeUnknown())
        @test hash(iter2) != hash(iter1)

        iter3 = TestIterator(copy(data), Base.HasLength(), Base.HasEltype())
        @test hash(iter3) == hash(iter1)
    end

    @testset "to_vec" begin
        data = randn(2, 3, 4)
        iter = TestIterator(data, Base.SizeUnknown(), Base.EltypeUnknown())
        v, back = ChainRulesTestUtils.to_vec(iter)
        @test v isa AbstractVector{eltype(data)}
        @test collect(v) == collect(vec(data))
        iter2 = back(v)
        @test iter2 == iter
    end

    @testset "rand_tangent" begin
        data = randn(2, 3, 4)
        iter = TestIterator(data, Base.SizeUnknown(), Base.EltypeUnknown())
        ∂iter = FiniteDifferences.rand_tangent(iter)
        @test ∂iter isa typeof(iter)
        @test size(∂iter.data) == size(iter.data)
        @test eltype(∂iter.data) === eltype(iter.data)
    end
end
