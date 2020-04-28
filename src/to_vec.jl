function FiniteDifferences.to_vec(x::Composite{P, T}) where{P, T<:Tuple}
    x_tuple = convert(Tuple, x)
    x_vec, back_tuple = FiniteDifferences.to_vec(x_tuple)
    function CompositeTuple_from_vec(y_vec)
        y_tuple = back_tuple(y_vec)
        return Composite{P, typeof(y_tuple)}(y_tuple)
    end
    return x_vec, CompositeTuple_from_vec
end
