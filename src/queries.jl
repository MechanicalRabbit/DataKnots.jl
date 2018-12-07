#
# Backend algebra.
#

using Base: OneTo
import Base:
    show,
    showerror

using Base.Cartesian

# Query interface.

"""
    Runtime(refs)

Runtime state for query evaluation.
"""
mutable struct Runtime
end

"""
    Query(op, args...)

A query represents a vectorized data transformation.

Parameter `op` is a function that performs the transformation.
It is invoked with the following arguments:

    op(rt::Runtime, input::AbstractVector, args...)

It must return the output vector of the same length as the input vector.
"""
struct Query
    op
    args::Vector{Any}
    sig::Signature
    src::Any
end

let NO_SIG = Signature()

    global Query

    Query(op, args...) =
        Query(op, collect(Any, args), NO_SIG, nothing)
end

"""
    designate(::Query, ::Signature) -> Query
    designate(::Query, ::InputShape, ::OutputShape) -> Query
    q::Query |> designate(::Signature) -> Query
    q::Query |> designate(::InputShape, ::OutputShape) -> Query

Sets the query signature.
"""
designate(q::Query, sig::Signature) =
    Query(q.op, q.args, sig, q.src)

designate(q::Query, ishp::InputShape, shp::OutputShape) =
    Query(q.op, q.args, Signature(ishp, shp), q.src)

designate(sig::Signature) =
    q::Query -> designate(q, sig)

designate(ishp::InputShape, shp::OutputShape) =
    q::Query -> designate(q, Signature(ishp, shp))

"""
    signature(::Query) -> Signature

Returns the query signature.
"""
signature(q::Query) = q.sig

shape(q::Query) = shape(q.sig)

ishape(q::Query) = ishape(q.sig)

decoration(q::Query) = decoration(q.sig)

idecoration(q::Query) = idecoration(q.sig)

domain(q::Query) = domain(q.sig)

idomain(q::Query) = idomain(q.sig)

mode(q::Query) = mode(q.sig)

imode(q::Query) = imode(q.sig)

cardinality(q::Query) = cardinality(q.sig)

isregular(q::Query) = isregular(q.sig)

isoptional(q::Query) = isoptional(q.sig)

isplural(q::Query) = isplural(q.sig)

isfree(q::Query) = isfree(q.sig)

isframed(q::Query) = isframed(q.sig)

slots(q::Query) = slots(q.sig)

function (q::Query)(input::AbstractVector)
    rt = Runtime()
    output = q(rt, input)
end

function (q::Query)(rt::Runtime, input::AbstractVector)
    try
        q.op(rt, input, q.args...)
    catch err
        if err isa QueryError && err.q === nothing && err.input === nothing
            err = err |> setquery(q) |> setinput(encapsulate(input, rt.refs))
        end
        rethrow(err)
    end
end

syntax(q::Query) =
    syntax(q.op, q.args)

show(io::IO, q::Query) =
    print_expr(io, syntax(q))

"""
    optimize(::Query)::Query

Rewrites the query to make it more effective.
"""
optimize(q::Query) =
    simplify(q) |> designate(q.sig)

"""
    QueryError(msg, ::Query, ::AbstractVector)

Exception thrown when a query gets unexpected input.
"""
struct QueryError <: Exception
    msg::String
    q::Union{Nothing,Query}
    input::Union{Nothing,AbstractVector}
end

QueryError(msg) = QueryError(msg, nothing, nothing)

setquery(q::Query) =
    err::QueryError -> QueryError(err.msg, q, err.input)

setinput(input::AbstractVector) =
    err::QueryError -> QueryError(err.msg, err.q, input)

function showerror(io::IO, err::QueryError)
    print(io, "$(nameof(QueryError)): $(err.msg)")
    if err.q !== nothing && err.input !== nothing
        println(io, " at:")
        println(io, err.q)
        println(io, "with input:")
        print(IOContext(io, :limit => true), err.input)
    end
end

# Vectorizing scalar functions.

"""
    lift(f) -> Query

`f` is any scalar unary function.

The query applies `f` to each element of the input vector.
"""
lift(f) = Query(lift, f)

lift(rt::Runtime, input::AbstractVector, f) =
    f.(input)

"""
    lift_to_tuple(f) -> Query

`f` is an n-ary function.

The query applies `f` to each row of an n-tuple vector.
"""
lift_to_tuple(f) = Query(lift_to_tuple, f)

function lift_to_tuple(rt::Runtime, input::AbstractVector, f)
    @assert input isa TupleVector
    _lift_to_tuple(f, length(input), columns(input)...)
end

@generated function _lift_to_tuple(f, len::Int, cols::AbstractVector...)
    D = length(cols)
    return quote
        I = Tuple{eltype.(cols)...}
        O = Core.Compiler.return_type(f, I)
        output = Vector{O}(undef, len)
        @inbounds for k = 1:len
            output[k] = @ncall $D f (d -> cols[d][k])
        end
        output
    end
end

"""
    lift_to_block(f)
    lift_to_block(f, default)

`f` is a function that takes a vector argument.

Applies a function `f` that takes a vector argument to each block of a block
vector.  When specified, `default` is used instead of applying `f` to an
empty block.
"""
lift_to_block(f) = Query(lift_to_block, f)

function lift_to_block(rt::Runtime, input::AbstractVector, f)
    @assert input isa BlockVector
    _lift_to_block(f, input)
end

lift_to_block(f, default) = Query(lift_to_block, f, default)

function lift_to_block(rt::Runtime, input::AbstractVector, f, default)
    @assert input isa BlockVector
    _lift_to_block(f, default, input)
end

function _lift_to_block(f, input)
    I = Tuple{typeof(cursor(input))}
    O = Core.Compiler.return_type(f, I)
    output = Vector{O}(undef, length(input))
    @inbounds for cr in cursor(input)
        output[cr.pos] = f(cr)
    end
    output
end

function _lift_to_block(f, default, input)
    I = Tuple{typeof(cursor(input))}
    O = Union{Core.Compiler.return_type(f, I), typeof(default)}
    output = Vector{O}(undef, length(input))
    @inbounds for cr in cursor(input)
        output[cr.pos] = !isempty(cr) ? f(cr) : default
    end
    output
end

"""
    lift_to_block_tuple(f)

Lifts an n-ary function to a tuple vector with block columns.  Applies the
function to every combinations of values from adjacent blocks.
"""
lift_to_block_tuple(f) = Query(lift_to_block_tuple, f)

function lift_to_block_tuple(rt::Runtime, input::AbstractVector, f)
    @assert input isa TupleVector && all(col isa BlockVector for col in columns(input))
    _lift_to_block_tuple(f, length(input), columns(input)...)
end

@generated function _lift_to_block_tuple(f, len::Int, cols::BlockVector...)
    D = length(cols)
    return quote
        card = foldl(|, cardinality.(cols), init=REG)
        @nextract $D offs (d -> offsets(cols[d]))
        @nextract $D elts (d -> elements(cols[d]))
        if @nall $D (d -> offs_d isa OneTo{Int})
            return BlockVector(:, _lift_to_tuple(f, len, (@ntuple $D elts)...), card)
        end
        len′ = 0
        regular = true
        @inbounds for k = 1:len
            sz = @ncall $D (*) (d -> (offs_d[k+1] - offs_d[k]))
            len′ += sz
            regular = regular && sz == 1
        end
        if regular
            return BlockVector(:, _lift_to_tuple(f, len, (@ntuple $D elts)...), card)
        end
        I = Tuple{eltype.(@ntuple $D elts)...}
        O = Core.Compiler.return_type(f, I)
        offs′ = Vector{Int}(undef, len+1)
        elts′ = Vector{O}(undef, len′)
        @inbounds offs′[1] = top = 1
        @inbounds for k = 1:len
            @nloops $D n (d -> offs_{$D-d+1}[k]:offs_{$D-d+1}[k+1]-1) (d -> elt_{$D-d+1} = elts_{$D-d+1}[n_d]) begin
                elts′[top] = @ncall $D f (d -> elt_d)
                top += 1
            end
            offs′[k+1] = top
        end
        return BlockVector(offs′, elts′, card)
    end
end

"""
    lift_const(val)

Produces a vector filled with the given value.
"""
lift_const(val) = Query(lift_const, val)

lift_const(rt::Runtime, input::AbstractVector, val) =
    fill(val, length(input))

"""
    lift_null()

Produces a block vector of empty blocks.
"""
lift_null() = Query(lift_null)

lift_null(rt::Runtime, input::AbstractVector) =
    BlockVector(fill(1, length(input)+1), Union{}[], OPT)

"""
    lift_block(block, card::Cardinality)

Produces a block vector filled with the given block.
"""
lift_block(block, card::Cardinality=OPT|PLU) = Query(lift_block, block, card)

function lift_block(rt::Runtime, input::AbstractVector, block::AbstractVector, card::Cardinality)
    if isempty(input)
        return BlockVector(:, block[[]], card)
    elseif length(input) == 1
        return BlockVector([1, length(block)+1], block, card)
    else
        len = length(input)
        sz = length(block)
        perm = Vector{Int}(undef, len*sz)
        for k in eachindex(input)
            copyto!(perm, 1 + sz * (k - 1), 1:sz)
        end
        return BlockVector(1:sz:(len*sz+1), block[perm], card)
    end
end

# Decoding regular vectors of composite values as columnar/SoA vectors.

"""
    decode_missing()

Decodes a vector with `missing` elements as a block vector, where `missing`
elements are converted to empty blocks.
"""
decode_missing() = Query(decode_missing)

function decode_missing(rt::Runtime, input::AbstractVector)
    if !(Missing <: eltype(input))
        return BlockVector(:, input, OPT)
    end
    sz = 0
    for elt in input
        if elt !== missing
            sz += 1
        end
    end
    O = Base.nonmissingtype(eltype(input))
    if sz == length(input)
        return BlockVector(:, collect(O, input), OPT)
    end
    offs = Vector{Int}(undef, length(input)+1)
    elts = Vector{O}(undef, sz)
    @inbounds offs[1] = top = 1
    @inbounds for k in eachindex(input)
        elt = input[k]
        if elt !== missing
            elts[top] = elt
            top += 1
        end
        offs[k+1] = top
    end
    return BlockVector(offs, elts, OPT)
end

"""
    decode_vector()

Decodes a vector with vector elements as a block vector.
"""
decode_vector() = Query(decode_vector)

function decode_vector(rt::Runtime, input::AbstractVector)
    @assert eltype(input) <: AbstractVector
    sz = 0
    for v in input
        sz += length(v)
    end
    O = eltype(eltype(input))
    offs = Vector{Int}(undef, length(input)+1)
    elts = Vector{O}(undef, sz)
    @inbounds offs[1] = top = 1
    @inbounds for k in eachindex(input)
        v = input[k]
        copyto!(elts, top, v)
        top += length(v)
        offs[k+1] = top
    end
    return BlockVector(offs, elts, OPT|PLU)
end

"""
    decode_tuple()

Decodes a vector with tuple elements as a tuple vector.
"""
decode_tuple() = Query(decode_tuple)

function decode_tuple(rt::Runtime, input::AbstractVector)
    @assert eltype(input) <: Union{Tuple,NamedTuple}
    lbls = Symbol[]
    I = eltype(input)
    if typeof(I) == DataType && I <: NamedTuple
        lbls = collect(Symbol, I.parameters[1])
        I = I.parameters[2]
    end
    Is = (I.parameters...,)
    cols = _decode_tuple(input, Is...)
    TupleVector(lbls, length(input), cols)
end

@generated function _decode_tuple(input, Is...)
    width = length(Is)
    return quote
        len = length(input)
        cols = @ncall $width tuple j -> Vector{Is[j]}(undef, len)
        @inbounds for k in eachindex(input)
            t = input[k]
            @nexprs $width j -> cols[j][k] = t[j]
        end
        collect(AbstractVector, cols)
    end
end

# Identity and composition.

"""
    pass()

Identity map.
"""
pass() = Query(pass)

pass(rt::Runtime, input::AbstractVector) =
    input

"""
    chain_of(q₁, q₂ … qₙ)

Sequentially applies q₁, q₂ … qₙ.
"""
chain_of() = pass()

chain_of(q) = q

chain_of(qs...) =
    Query(chain_of, collect(qs))

chain_of(qs::Vector) =
    Query(chain_of, qs)

syntax(::typeof(chain_of), args::Vector{Any}) =
    if length(args) == 1 && args[1] isa Vector
        Expr(:call, chain_of, syntax.(args[1])...)
    else
        Expr(:call, chain_of, syntax.(args)...)
    end

function chain_of(rt::Runtime, input::AbstractVector, qs)
    output = input
    for q in qs
        output = q(rt, output)
    end
    output
end

# Operations on tuple vectors.

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
    @assert input isa TupleVector
    j = locate(input, lbl)
    column(input, j)
end

"""
    in_tuple(lbl, q)

Using q, transforms the specified column of a tuple vector.
"""
in_tuple(lbl::Union{Int,Symbol}, q) = Query(in_tuple, lbl, q)

function in_tuple(rt::Runtime, input::AbstractVector, lbl, q)
    @assert input isa TupleVector
    j = locate(input, lbl)
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
    @assert input isa TupleVector
    j = locate(input, lbl)
    nested = column(input, j)
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

# Operations on block vectors.

"""
    as_block()

Wraps input values to one-element blocks.
"""
as_block() = Query(as_block)

as_block(rt::Runtime, input::AbstractVector) =
    BlockVector(:, input, REG)


"""
    in_block(q)

Using q, transfors the elements of the input blocks.
"""
in_block(q) = Query(in_block, q)

function in_block(rt::Runtime, input::AbstractVector, q)
    @assert input isa BlockVector
    BlockVector(offsets(input), q(rt, elements(input)), cardinality(input))
end

"""
    flat_block()

Flattens a nested block vector.
"""
flat_block() = Query(flat_block)

function flat_block(rt::Runtime, input::AbstractVector)
    @assert input isa BlockVector && elements(input) isa BlockVector
    offs = offsets(input)
    nested = elements(input)
    nested_offs = offsets(nested)
    elts = elements(nested)
    card = cardinality(input)|cardinality(nested)
    BlockVector(_flat_block(offs, nested_offs), elts, card)
end

_flat_block(offs1::AbstractVector{Int}, offs2::AbstractVector{Int}) =
    Int[offs2[off] for off in offs1]

_flat_block(offs1::OneTo{Int}, offs2::OneTo{Int}) = offs1

_flat_block(offs1::OneTo{Int}, offs2::AbstractVector{Int}) = offs2

_flat_block(offs1::AbstractVector{Int}, offs2::OneTo{Int}) = offs1

"""
    pull_block(lbl)

Converts a tuple with a block column to a block of tuples.
"""
pull_block(lbl) = Query(pull_block, lbl)

function pull_block(rt::Runtime, input::AbstractVector, lbl)
    @assert input isa TupleVector && column(input, lbl) isa BlockVector
    j = locate(input, lbl)
    len = length(input)
    lbls = labels(input)
    cols = columns(input)
    col = cols[j]
    card = cardinality(col)
    offs = offsets(col)
    col′ = elements(col)
    cols′ = copy(cols)
    if offs isa OneTo{Int}
        cols′[j] = col′
        return BlockVector(offs, TupleVector(lbls, len, cols′), card)
    end
    len′ = length(col′)
    perm = Vector{Int}(undef, len′)
    l = r = 1
    @inbounds for k = 1:len
        l = r
        r = offs[k+1]
        for n = l:r-1
            perm[n] = k
        end
    end
    for i in eachindex(cols′)
        cols′[i] =
            if i == j
                col′
            else
                cols′[i][perm]
            end
    end
    return BlockVector(offs, TupleVector(lbls, len′, cols′), card)
end

"""
    pull_every_block()

Converts a tuple vector with block columns to a block vector over a tuple
vector.
"""
pull_every_block() = Query(pull_every_block)

function pull_every_block(rt::Runtime, input::AbstractVector)
    @assert input isa TupleVector && all(col isa BlockVector for col in columns(input))
    cols = columns(input)
    _pull_every_block(labels(input), length(input), cols...)
end

@generated function _pull_every_block(lbls::Vector{Symbol}, len::Int, cols::BlockVector...)
    D = length(cols)
    return quote
        card = foldl(|, cardinality.(cols), init=REG)
        @nextract $D offs (d -> offsets(cols[d]))
        @nextract $D elts (d -> elements(cols[d]))
        if @nall $D (d -> offs_d isa OneTo{Int})
            return BlockVector(:, TupleVector(lbls, len, AbstractVector[(@ntuple $D elts)...]), card)
        end
        len′ = 0
        regular = true
        @inbounds for k = 1:len
            sz = @ncall $D (*) (d -> (offs_d[k+1] - offs_d[k]))
            len′ += sz
            regular = regular && sz == 1
        end
        if regular
            return BlockVector(:, TupleVector(lbls, len, AbstractVector[(@ntuple $D elts)...]), card)
        end
        offs′ = Vector{Int}(undef, len+1)
        @nextract $D perm (d -> Vector{Int}(undef, len′))
        @inbounds offs′[1] = top = 1
        @inbounds for k = 1:len
            @nloops $D n (d -> offs_{$D-d+1}[k]:offs_{$D-d+1}[k+1]-1) begin
                @nexprs $D (d -> perm_{$D-d+1}[top] = n_d)
                top += 1
            end
            offs′[k+1] = top
        end
        cols′ = @nref $D AbstractVector (d -> elts_d[perm_d])
        return BlockVector(offs′, TupleVector(lbls, len′, cols′), card)
    end
end

"""
    count_block()

Maps a block vector to a vector of block lengths.
"""
count_block() = Query(count_block)

function count_block(rt::Runtime, input::AbstractVector)
    @assert input isa BlockVector
    _count_block(offsets(input))
end

_count_block(offs::OneTo{Int}) =
    fill(1, length(offs)-1)

function _count_block(offs::AbstractVector{Int})
    len = length(offs) - 1
    output = Vector{Int}(undef, len)
    @inbounds for k = 1:len
        output[k] = offs[k+1] - offs[k]
    end
    output
end

"""
    any_block()

Checks if there is one `true` value in a block of `Bool` values.
"""
any_block() = Query(any_block)

function any_block(rt::Runtime, input::AbstractVector)
    @assert input isa BlockVector && eltype(elements(input)) <: Bool
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    if offs isa OneTo
        return elts
    end
    output = Vector{Bool}(undef, len)
    l = r = 1
    @inbounds for k = 1:len
        val = false
        l = r
        r = offs[k+1]
        for i = l:r-1
            if elts[i]
                val = true
                break
            end
        end
        output[k] = val
    end
    return output
end

# Sieving a vector.

"""
    sieve()

Filters a vector of pairs by the second column.
"""
sieve() = Query(sieve)

function sieve(rt::Runtime, input::AbstractVector)
    @assert input isa TupleVector && eltype(column(input, 2)) <: Bool
    len = length(input)
    val_col, pred_col = columns(input)
    sz = count(pred_col)
    if sz == len
        return BlockVector(:, val_col, OPT)
    elseif sz == 0
        return BlockVector(fill(1, len+1), val_col[[]], OPT)
    end
    offs = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs[1] = top = 1
    for k = 1:len
        if pred_col[k]
            perm[top] = k
            top += 1
        end
        offs[k+1] = top
    end
    return BlockVector(offs, val_col[perm], OPT)
end

# Pagination.

"""
    take_by(N)

Keeps the first N elements in a block.
"""
take_by(N::Union{Missing,Int}, rev::Bool=false) =
    Query(take_by, N, rev)

function take_by(rt::Runtime, input::AbstractVector, N::Missing, rev::Bool)
    @assert input isa BlockVector
    input
end

function take_by(rt::Runtime, input::AbstractVector, N::Int, rev::Bool)
    @assert input isa BlockVector
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    sz = 0
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        sz += r - l + 1
    end
    if sz == length(elts)
        return input
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        for j = (L + l - 1):(L + r - 1)
            perm[top] = j
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    card = cardinality(input)|OPT
    return BlockVector(offs′, elts′, card)
end

take_by(rev::Bool=false) =
    Query(take_by, rev)

function take_by(rt::Runtime, input::AbstractVector, rev::Bool)
    @assert input isa TupleVector
    cols = columns(input)
    @assert length(cols) == 2
    vals, Ns = cols
    @assert vals isa BlockVector
    @assert eltype(Ns) <: Union{Missing,Int}
    len = length(input)
    offs = offsets(vals)
    elts = elements(vals)
    R = 1
    sz = 0
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        sz += r - l + 1
    end
    if sz == length(elts)
        return val_col
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        for j = (L + l - 1):(L + r - 1)
            perm[top] = j
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    card = cardinality(vals)|OPT
    return BlockVector(offs′, elts′, card)
end

@inline _take_range(n::Int, l::Int, rev::Bool) =
    if !rev
        (1, n >= 0 ? min(l, n) : max(0, l + n))
    else
        (n >= 0 ? min(l + 1, n + 1) : max(1, l + n + 1), l)
    end

@inline _take_range(::Missing, l::Int, ::Bool) =
    (1, l)

# Optimizing a query expression.

function simplify(q::Query)
    qs = simplify_chain(q)
    if isempty(qs)
        return pass()
    elseif length(qs) == 1
        return qs[1]
    else
        return chain_of(qs)
    end
end

simplify(qs::Vector{Query}) =
    simplify.(qs)

simplify(other) = other

function simplify_chain(q::Query)
    if q.op == pass
        return Query[]
    elseif q.op == chain_of
        return simplify_block(vcat(simplify_chain.(q.args[1])...))
    else
        return [Query(q.op, simplify.(q.args)...)]
    end
end

function simplify_block(qs)
    while true
        if !any(qs[k].op == as_block && qs[k+1].op == in_block && qs[k+2].op == flat_block
                for k = 1:length(qs)-2)
            return qs
        end
        qs′ = Query[]
        k = 1
        while k <= length(qs)
            if k <= length(qs)-2 && qs[k].op == as_block && qs[k+1].op == in_block && qs[k+2].op == flat_block
                q = qs[k+1].args[1]
                if q.op == pass
                elseif q.op == chain_of
                    append!(qs′, q.args[1])
                else
                    push!(qs′, q)
                end
                k += 3
            else
                push!(qs′, qs[k])
                k += 1
            end
        end
        qs = qs′
    end
end
