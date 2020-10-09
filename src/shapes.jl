#
# Representing data shapes and pipeline signatures.
#

import Base:
    convert,
    getindex,
    eltype,
    isempty,
    iterate,
    show


#
# Shapes of data.
#

"""
    AbstractShape

Describes the structure of column-oriented data.
"""
abstract type AbstractShape end

quoteof(shp::AbstractShape) =
    Expr(:call, nameof(typeof(shp)))

quoteof(p::Pair{Symbol,<:AbstractShape}) =
    Expr(:call, :(=>), labelquote(p.first), quoteof(p.second))

quoteof_inner(p::Pair{Symbol,<:AbstractShape}) =
    Expr(:call, :(=>), labelquote(p.first), quoteof_inner(p.second))

labelquote(lbl::Symbol) =
    quoteof(labelsyntax(lbl))

syntaxof(shp::AbstractShape) =
    nameof(typeof(shp))

syntaxof(p::Pair{Symbol,<:AbstractShape}) =
    Expr(:(=), labelsyntax(p.first), syntaxof(p.second))

labelsyntax(lbl::Symbol) =
    Base.isidentifier(lbl) ? lbl : string(lbl)

show(io::IO, shp::AbstractShape) =
    print_expr(io, quoteof(shp))

iterate(::AbstractShape) = nothing

width(::AbstractShape) = 0

branch(shp::AbstractShape, j) =
    (checkbounds(1:0, j); shp)

branch(shp::AbstractShape) =
    branch(shp, 1)

replace_branch(shp::AbstractShape, j::Int, f) =
    (checkbounds(1:0, j); shp)

#
# Concrete shapes.
#

abstract type DataShape <: AbstractShape end

"""
    AnyShape()

Nothing is known about the data.
"""
struct AnyShape <: DataShape
end

quoteof_inner(::AnyShape) =
    :Any

syntaxof(::AnyShape) =
    :Any

eltype(::AnyShape) = Any

"""
    NoShape()

Inconsistent constraints on the data.
"""
struct NoShape <: DataShape
end

syntaxof(::NoShape) =
    :Bottom

eltype(::NoShape) = Union{}

"""
    ValueOf(::Type)

Regular Julia vector with elements of the given type.
"""

struct ValueOf <: DataShape
    ty::Type
end

ValueOf(::Type{Any}) =
    AnyShape()

ValueOf(::Type{Union{}}) =
    NoShape()

convert(::Type{AbstractShape}, ty::Type) =
    ValueOf(ty)

quoteof(shp::ValueOf) =
    Expr(:call, nameof(ValueOf), shp.ty)

quoteof_inner(shp::ValueOf) =
    shp.ty

syntaxof(shp::ValueOf) = shp.ty

eltype(shp::ValueOf) = shp.ty

"""
    TupleOf([lbls::Vector{Symbol},] cols::Vector{AbstractShape})
    TupleOf(cols::AbstractShape...)
    TupleOf(lcols::Pair{<:Union{Symbol,AbstractString},<:AbstractShape}...)

Shape of a `TupleVector`.
"""

struct TupleOf <: DataShape
    lbls::Vector{Symbol}
    cols::Vector{AbstractShape}
end

TupleOf() =
    TupleOf(Symbol[], AbstractShape[])

TupleOf(cols::Vector{<:AbstractShape}) =
    TupleOf(Symbol[], cols)

TupleOf(cols::Union{AbstractShape,Type}...) =
    TupleOf(Symbol[], AbstractShape[col for col in cols])

TupleOf(lcols::Pair{<:Union{Symbol,AbstractString},<:Union{AbstractShape,Type}}...) =
    TupleOf(Symbol[first(lcol) for lcol in lcols], AbstractShape[last(lcol) for lcol in lcols])

quoteof(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:call, nameof(TupleOf), Any[quoteof_inner(col) for col in shp.cols]...)
    else
        Expr(:call, nameof(TupleOf), Any[quoteof_inner(lbl => col) for (lbl, col) in zip(shp.lbls, shp.cols)]...)
    end

syntaxof(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:tuple, Any[syntaxof(col) for col in shp.cols]...)
    else
        Expr(:tuple, Any[syntaxof(lbl => col) for (lbl, col) in zip(shp.lbls, shp.cols)]...)
    end

labels(shp::TupleOf) = shp.lbls

function ordinal_label(k::Int)
    lbl = ""
    if k == 1
        lbl = 'A' * lbl
    else
        while k > 1
            lbl = ('A' + (k - 1) % 26) * lbl
            k = 1 + (k - 1) ÷ 26
        end
    end
    return Symbol('#' * lbl)
end

function label(shp::TupleOf, k::Int)
    !isempty(shp.lbls) ? shp.lbls[k] : ordinal_label(k)
end

width(shp::TupleOf) = length(shp.cols)

branch(shp::TupleOf, j) = shp.cols[j]

columns(shp::TupleOf) = shp.cols

column(shp::TupleOf, j::Int) = shp.cols[j]

column(shp::TupleOf, lbl::Symbol) =
    column(shp, findfirst(isequal(lbl), shp.lbls))

locate(shp::TupleOf, j::Int) =
    1 <= j <= length(shp.cols) ? j : nothing

locate(shp::TupleOf, lbl::Symbol) =
    findfirst(isequal(lbl), shp.lbls)

function replace_column(shp::TupleOf, j::Int, f)
    col = shp.cols[j]
    col′ = f isa AbstractShape ? f : f(col)
    cols′ = copy(shp.cols)
    cols′[j] = col′
    TupleOf(shp.lbls, cols′)
end

replace_branch(shp::TupleOf, j::Int, f) =
    replace_column(shp, j, f)

function eltype(shp::TupleOf)
    t = Tuple{Any[eltype(col) for col in shp.cols]...}
    if isempty(shp.lbls)
        t
    else
        NamedTuple{(shp.lbls...,),t}
    end
end

iterate(shp::TupleOf) =
    iterate(shp, 1)

iterate(shp::TupleOf, j) =
    j <= length(shp.cols) ? (shp.cols[j], j+1) : nothing

"""
    BlockOf(elts::AbstractShape, card::Cardinality=x0toN)

Shape of a `BlockVector`.
"""
struct BlockOf <: DataShape
    elts::AbstractShape
    card::Cardinality
end

BlockOf(elts) =
    BlockOf(elts, x0toN)

quoteof(shp::BlockOf) =
    if shp.card == x0toN
        Expr(:call, nameof(BlockOf), quoteof_inner(shp.elts))
    else
        Expr(:call, nameof(BlockOf), quoteof_inner(shp.elts), quoteof(shp.card))
    end

syntaxof(shp::BlockOf) =
    Expr(:call, :×, syntaxof(shp.card), syntaxof(shp.elts))

width(::BlockOf) = 1

branch(shp::BlockOf, j) =
    (checkbounds(1:1, j); shp.elts)

elements(shp::BlockOf) = shp.elts

function replace_elements(shp::BlockOf, f)
    elts′ = f isa AbstractShape ? f : f(shp.elts)
    BlockOf(elts′, shp.card)
end

function replace_branch(shp::BlockOf, j::Int, f)
    checkbounds(1:1, j)
    replace_elements(shp, f)
end

cardinality(shp::BlockOf) = shp.card

ismandatory(shp::BlockOf) = ismandatory(shp.card)

issingular(shp::BlockOf) = issingular(shp.card)

function eltype(shp::BlockOf)
    t = eltype(shp.elts)
    if shp.card == x1to1
        t
    elseif shp.card == x0to1
        Union{t,Missing}
    else
        Vector{t}
    end
end

iterate(shp::BlockOf) =
    iterate(shp, 1)

iterate(shp::BlockOf, j) =
    j == 1 ? (shp.elts, 2) : nothing


#
# Annotations.
#

abstract type Annotation <: AbstractShape end

syntaxof(shp::Annotation) =
    syntaxof(shp.sub)

eltype(shp::Annotation) =
    eltype(subject(shp))

deannotate(shp::AbstractShape) =
    shp

deannotate(shp::Annotation) =
    deannotate(subject(shp))

width(::Annotation) = 1

branch(shp::Annotation, j) =
    (checkbounds(1:1, j); shp.sub)

function replace_branch(shp::Annotation, j::Int, f)
    checkbounds(1:1, j)
    replace_subject(shp, f)
end

iterate(shp::Annotation) =
    iterate(shp, 1)

iterate(shp::Annotation, j) =
    j == 1 ? (shp.sub, 2) : nothing

"""
    sub |> IsLabeled(::Symbol)

The shape has an attached label.
"""
struct IsLabeled <: Annotation
    sub::AbstractShape
    lbl::Symbol
end

IsLabeled(sub::Union{AbstractShape,Type}, lbl::Union{Symbol,AbstractString}) =
    IsLabeled(convert(AbstractShape, sub), Symbol(lbl))

IsLabeled(lbl::Union{Symbol,AbstractString}) =
    sub -> IsLabeled(sub, lbl)

quoteof(shp::IsLabeled) =
    Expr(:call, nameof(|>), quoteof_inner(shp.sub), Expr(:call, nameof(IsLabeled), labelquote(shp.lbl)))

subject(shp::IsLabeled) = shp.sub

replace_subject(shp::IsLabeled, f) =
    IsLabeled(f isa AbstractShape ? f : f(shp.sub), shp.lbl)

label(shp::IsLabeled) =
    shp.lbl

"""
    sub |> IsFlow

The annotated `BlockVector` holds the output flow.
"""

struct IsFlow <: Annotation
    sub::BlockOf
end

quoteof(shp::IsFlow) =
    Expr(:call, nameof(|>), quoteof_inner(shp.sub), nameof(IsFlow))

subject(shp::IsFlow) = shp.sub

replace_subject(shp::IsFlow, f) =
    IsFlow(f isa AbstractShape ? f : f(shp.sub))

elements(shp::IsFlow) =
    elements(shp.sub)

replace_elements(shp::IsFlow, f) =
    replace_subject(shp, sub -> replace_elements(sub, f))

cardinality(shp::IsFlow) =
    cardinality(shp.sub)

"""
    sub |> IsScope

The annotated `TupleVector` holds the scoping context.
"""

struct IsScope <: Annotation
    sub::TupleOf
end

quoteof(shp::IsScope) =
    Expr(:call, nameof(|>), quoteof_inner(shp.sub), nameof(IsScope))

subject(shp::IsScope) = shp.sub

replace_subject(shp::IsScope, f) =
    IsScope(f isa AbstractShape ? f : f(shp.sub))

column(shp::IsScope) =
    column(shp.sub, 1)

replace_column(shp::IsScope, f) =
    replace_subject(shp, sub -> replace_column(sub, 1, f))

context(shp::IsScope) =
    column(shp.sub, 2)


#
# Pipeline profile.
#

struct Passthrough <: AbstractShape
    pos::Int
end

Passthrough() =
    Passthrough(1)

quoteof(shp::Passthrough) =
    Expr(:call, nameof(Passthrough), shp.pos)

syntaxof(shp::Passthrough) =
    Symbol("_", shp.pos)

position(shp::Passthrough) =
    shp.pos

count_passthrough(::Passthrough) = 1

function count_passthrough(@nospecialize shp::AbstractShape)
    c = 0
    for j = 1:width(shp)
        c += count_passthrough(branch(shp, j))
    end
    c
end


#
# Partial order on shapes.
#

"""
    fits(x::T, y::T) :: Bool

Checks if constraint `x` implies constraint `y`.
"""
function fits end

fits(c1::Cardinality, c2::Cardinality) =
    (c1 | c2) == c2

fits(::AbstractShape, ::AbstractShape) = false

fits(::DataShape, ::AnyShape) = true

fits(::NoShape, ::DataShape) = true

fits(::NoShape, ::AnyShape) = true

fits(shp1::ValueOf, shp2::ValueOf) =
    shp1.ty <: shp2.ty

fits(shp1::TupleOf, shp2::TupleOf) =
    length(shp1.cols) == length(shp2.cols) &&
    all(Bool[fits(col1, col2) for (col1, col2) in zip(shp1.cols, shp2.cols)]) &&
    (isempty(shp2.lbls) || shp1.lbls == shp2.lbls)

fits(shp1::BlockOf, shp2::BlockOf) =
    fits(shp1.elts, shp2.elts) &&
    fits(shp1.card, shp2.card)

fits(shp1::IsLabeled, shp2::IsLabeled) =
    fits(shp1.sub, shp2.sub) && shp1.lbl == shp2.lbl

fits(shp1::IsLabeled, shp2::AbstractShape) =
    fits(shp1.sub, shp2)

fits(shp1::IsFlow, shp2::IsFlow) =
    fits(shp1.sub, shp2.sub)

fits(shp1::IsFlow, shp2::AbstractShape) =
    fits(shp1.sub, shp2)

fits(shp1::IsScope, shp2::IsScope) =
    fits(shp1.sub, shp2.sub)

fits(shp1::IsScope, shp2::AbstractShape) =
    fits(shp1.sub, shp2)


#
# Guessing the shape of a vector.
#

shapeof(v::AbstractVector) =
    ValueOf(eltype(v))

shapeof(tv::TupleVector) =
    TupleOf(labels(tv), AbstractShape[shapeof(col) for col in columns(tv)])

shapeof(bv::BlockVector) =
    BlockOf(shapeof(elements(bv)), cardinality(bv))

fits(v::AbstractVector, shp::AbstractShape) =
    fits(shapeof(v), shp)


#
# Signature of a pipeline.
#

"""
    Signature(::AbstractShape, ::AbstractShape)

Shapes of a pipeline source and tagret.
"""
struct Signature
    src::AbstractShape
    tgt::AbstractShape
end

Signature() = Signature(NoShape(), AnyShape())

quoteof(sig::Signature) =
    Expr(:call, nameof(Signature), quoteof(sig.src), quoteof(sig.tgt))

syntaxof(sig::Signature) =
    Expr(:(->), syntaxof(sig.src), syntaxof(sig.tgt))

show(io::IO, sig::Signature) =
    print_expr(io, quoteof(sig))

source(sig::Signature) = sig.src

target(sig::Signature) = sig.tgt

function unify(sig1::Signature, sig2::Signature)
    n1 = count_passthrough(sig1.src)
    n2 = count_passthrough(sig2.src)
    repl1 = Union{AbstractShape,Nothing}[]
    repl2 = Union{AbstractShape,Nothing}[]
    for k = 1:n1
        push!(repl1, nothing)
    end
    for k = 1:n2
        push!(repl2, nothing)
    end
    unify!(sig1.tgt, sig2.src, repl1, repl2)
    src = substitute(sig1.src, repl1, true)
    tgt = substitute(sig2.tgt, repl2)
    tgt = substitute(tgt, repl1, true)
    j = 1
    for k = eachindex(repl1)
        if repl1[k] === nothing
            repl1[k] = Passthrough(j)
            j += 1
        end
    end
    src = substitute(src, repl1)
    tgt = substitute(tgt, repl1)
    Signature(src, tgt)
end

unify!(shp1::AbstractShape, shp2::AbstractShape, repl1, repl2) =
    error("cannot unify $shp1 and $shp2")

function unify!(shp1::Union{ValueOf,NoShape}, shp2::Union{ValueOf,AnyShape}, repl1, repl2)
    eltype(shp1) <: eltype(shp2) || error("cannot unify $shp1 and $shp2")
    nothing
end

unify!(shp1::NoShape, shp2::NoShape, repl1, repl2) = nothing

unify!(shp1::AnyShape, shp2::AnyShape, repl1, repl2) = nothing

function unify!(shp1::TupleOf, shp2::TupleOf, repl1, repl2)
    width(shp1) == width(shp2) || error("cannot unify $shp1 and $shp2")
    for k = 1:width(shp1)
        unify!(column(shp1, k), column(shp2, k), repl1, repl2)
    end
    nothing
end

function unify!(shp1::BlockOf, shp2::BlockOf, repl1, repl2)
    fits(cardinality(shp1), cardinality(shp2)) || error("cannot unify $shp1 and $shp2")
    unify!(elements(shp1), elements(shp2), repl1, repl2)
end

function unify!(shp1::Passthrough, shp2::Passthrough, repl1, repl2)
    repl2[position(shp2)] = shp1
    nothing
end

function unify!(shp1::AbstractShape, shp2::Passthrough, repl1, repl2)
    repl2[position(shp2)] = shp1
    nothing
end

function unify!(shp1::Passthrough, shp2::Union{ValueOf,AnyShape,NoShape}, repl1, repl2)
    pos1 = position(shp1)
    shp1′ = repl1[pos1]
    shp1′ === nothing || return unify!(shp1′, shp2, repl1, repl2)
    repl1[pos1] = shp2
    nothing
end

function unify!(shp1::Passthrough, shp2::TupleOf, repl1, repl2)
    pos1 = position(shp1)
    shp1′ = repl1[pos1]
    shp1′ === nothing || return unify!(shp1′, shp2, repl1, repl2)
    cols = AbstractShape[]
    for j = 1:width(shp2)
        push!(repl1, nothing)
        push!(cols, Passthrough(length(repl1)))
    end
    shp1′ = TupleOf(labels(shp2), cols)
    repl1[pos1] = shp1′
    unify!(shp1′, shp2, repl1, repl2)
end

function unify!(shp1::Passthrough, shp2::BlockOf, repl1, repl2)
    pos1 = position(shp1)
    shp1′ = repl1[pos1]
    shp1′ === nothing || return unify!(shp1′, shp2, repl1, repl2)
    push!(repl1, nothing)
    shp1′ = BlockOf(Passthrough(length(repl1)), cardinality(shp2))
    repl1[pos1] = shp1′
    unify!(shp1′, shp2, repl1, repl2)
end

function propagate(sig::Signature, src::AbstractShape)
    n = count_passthrough(sig.src)
    repl = Union{AbstractShape,Nothing}[]
    for k = 1:n
        push!(repl, nothing)
    end
    unify!(src, sig.src, Union{AbstractShape,Nothing}[], repl)
    substitute(sig.tgt, repl)
end

substitute(@nospecialize(shp::AbstractShape), repl, deep=false) = shp

function substitute(shp::Passthrough, repl, deep)
    shp′ = repl[position(shp)]
    if shp′ !== nothing
        shp = shp′
        if deep
            shp = substitute(shp, repl, deep)
        end
    end
    shp
end

substitute(shp::TupleOf, repl, deep) =
    TupleOf(labels(shp), AbstractShape[substitute(col, repl, deep) for col in columns(shp)])

substitute(shp::BlockOf, repl, deep) =
    BlockOf(substitute(elements(shp), repl, deep), cardinality(shp))

function adjust_position(sig, x)
    x != 0 || return sig
    n = count_passthrough(sig.src)
    n > 0 || return sig
    repl = Union{AbstractShape,Nothing}[]
    for k = 1:n
        push!(repl, Passthrough(k + x))
    end
    Signature(substitute(sig.src, repl), substitute(sig.tgt, repl))
end


#
# Rendering as a tree.
#

print_graph(shp::AbstractShape) =
    print_graph(stdout, shp)

function print_graph(io::IO, shp::AbstractShape; indent=0)
    gr = graphof(shp)
    w = 0
    for (ind, name, descr) in gr
        w = max(w, ind*2 + textwidth(name))
    end
    for (k, (ind, name, descr)) in enumerate(gr)
        print(io, " " ^ indent)
        for j = 1:ind
            more = false
            k′ = k + 1
            while k′ <= length(gr)
                ind′ = gr[k′][1]
                if ind′ == j
                    more = true
                end
                ind′ > j || break
                k′ += 1
            end
            print(io, j < ind ? (more ? "│ " : "  ") : (more ? "├╴" : "└╴"))
        end
        print(io, name)
        if !isempty(descr)
            print(io, " " ^ (2 + w - ind*2 - textwidth(name)))
            print(io, descr)
        end
        println(io)
    end
end

function graphof(shp::AbstractShape)
    gr = Tuple{Int,String,String}[]
    graphof!(gr, shp, nothing, 0, "#")
    gr
end

function graphof!(gr, shp::AbstractShape, card, ind, name)
    descr = "$(syntaxof(shp))"
    if card !== nothing
        descr = "$card × $descr"
    end
    push!(gr, (ind, name, descr))
end

function graphof!(gr, shp::BlockOf, card, ind, name)
    card′ = "$(syntaxof(cardinality(shp)))"
    if card !== nothing
        card′ = "$card × $card′"
    end
    graphof!(gr, elements(shp), card′, ind, name)
end

function graphof!(gr, shp::TupleOf, card, ind, name)
    descr = card !== nothing ? card : ""
    push!(gr, (ind, name, descr))
    for j = 1:width(shp)
        graphof!(gr, column(shp, j), nothing, ind+1, string(label(shp, j)))
    end
    gr
end

graphof!(gr, shp::IsLabeled, card, ind, name) =
    graphof!(gr, subject(shp), card, ind, string(label(shp)))

graphof!(gr, shp::Annotation, card, ind, name) =
    graphof!(gr, subject(shp), card, ind, name)

