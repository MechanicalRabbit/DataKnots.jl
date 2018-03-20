#
# Operations on tuple vectors.
#

"""
    tuple_of(q₁, q₂ … qₙ)

Combines the output of q₁, q₂ … qₙ into an n-tuple vector.
"""
tuple_of(qs...) =
    tuple_of(Symbol[], collect(qs))

tuple_of(lqs::Pair{Symbol}...) =
    tuple_of(collect(Symbol, first.(lqs)), collect(last.(lqs)))

tuple_of(lbls::Vector{Symbol}, qs::Vector) = Query(tuple_of, lbls, qs)

function tuple_of(rt::Runtime, input::AbstractVector, lbls, qs)
    len = length(input)
    cols = AbstractVector[q(rt, input) for q in qs]
    TupleVector(lbls, len, cols)
end


"""
    column(lbl)

Extracts the specified column of a tuple vector.
"""
column(lbl::Union{Int,Symbol}) = Query(column, lbl)

function column(rt::Runtime, input::AbstractVector, lbl)
    input isa SomeTupleVector || error("expected a tuple vector; got $input at\n$(column(lbl))")
    j = locate(input, lbl)
    j !== nothing || error("invalid column $lbl of $input at\n$(column(lbl))")
    column(input, j)
end


"""
    in_tuple(lbl, q)

Using q, transforms the specified column of a tuple vector.
"""
in_tuple(lbl::Union{Int,Symbol}, q) = Query(in_tuple, lbl, q)

function in_tuple(rt::Runtime, input::AbstractVector, lbl, q)
    input isa SomeTupleVector || error("expected a tuple vector; got $input at\n$(in_tuple(lbl, q))")
    j = locate(input, lbl)
    j !== nothing || error("invalid column $lbl of $input at\n$(in_tuple(lbl, q))")
    cols′ = copy(columns(input))
    cols′[j] = q(rt, cols′[j])
    TupleVector(labels(input), length(input), cols′)
end


"""
    flat_tuple(lbl)

Flattens a nested tuple vector.
"""
flat_tuple(lbl::Union{Int,Symbol}) = Query(flat_tuple, lbl)

function flat_tuple(rt::Runtime, input::AbstractVector, lbl)
    input isa SomeTupleVector || error("expected a tuple vector; got $input at\n$(flat_tuple(lbl))")
    j = locate(input, lbl)
    j !== nothing || error("invalid column $lbl of $input at\n$(flat_tuple(lbl))")
    nested = column(input, j)
    nested isa SomeTupleVector || error("expected a tuple vector; got $nested at\n$(flat_tuple(lbl))")
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

