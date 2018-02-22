#
# Operations on tuple vectors.
#

"""
    tuple_of(q₁, q₂ … qₙ)

Combines the output of q₁, q₂ … qₙ into an n-tuple vector.
"""
tuple_of(qs...) =
    tuple_of(Symbol[], qs...)

tuple_of(lqs::Pair{Symbol}...) =
    tuple_of(collect(Symbol, first.(lqs)), last.(lqs)...)

tuple_of(lbls::Vector{Symbol}, qs...) =
    Query(tuple_of, lbls, qs...) do env, input
        len = length(input)
        cols = AbstractVector[q(env, input) for q in qs]
        TupleVector(lbls, len, cols)
    end


"""
    column(lbl)

Extracts the specified column of a tuple vector.
"""
column(lbl::Union{Int,Symbol}) =
    Query(column, lbl) do env, input
        input isa SomeTupleVector || error("expected a tuple vector; got $input")
        j = locate(input, lbl)
        j !== nothing || error("invalid column $lbl of $input")
        column(input, j)
    end


"""
    in_tuple(lbl, q)

Using q, transforms the specified column of a tuple vector.
"""
in_tuple(lbl::Union{Int,Symbol}, q) =
    Query(in_tuple, lbl, q) do env, input
        input isa SomeTupleVector || error("expected a tuple vector; got $input")
        j = locate(input, lbl)
        j !== nothing || error("invalid column $lbl of $input")
        cols′ = copy(columns(input))
        cols′[j] = q(env, cols′[j])
        TupleVector(labels(input), length(input), cols′)
    end


"""
    flat_tuple(lbl)

Flattens a nested tuple vector.
"""
flat_tuple(lbl::Union{Int,Symbol}) =
    Query(flat_tuple, lbl) do env, input
        input isa SomeTupleVector || error("expected a tuple vector; got $input")
        j = locate(input, lbl)
        j !== nothing || error("invalid column $lbl of $input")
        nested = column(input, j)
        nested isa SomeTupleVector || error("expected a tuple vector; got $nested")
        lbls = labels(input)
        cols = columns(input)
        nested_lbls = labels(nested)
        nested_cols = columns(nested)
        lbls′ =
            if !isempty(lbls) && (!isempty(nested_lbls) || isempty(nested_cols))
                [lbls[1:j-1]; nested_lbls; lbls[j+1:end]]
            else
                Symbol[]
            end
        cols′ = [cols[1:j-1]; nested_cols; cols[j+1:end]]
        TupleVector(lbls′, length(input), cols′)
    end

