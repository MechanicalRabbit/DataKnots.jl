#
# Representing data shapes and pipeline signatures.
#

import Base:
    convert,
    getindex,
    eltype,
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
    TupleOf(Symbol[], collect(AbstractShape, cols))

TupleOf(lcols::Pair{<:Union{Symbol,AbstractString},<:Union{AbstractShape,Type}}...) =
    TupleOf(collect(Symbol.(first.(lcols))), collect(AbstractShape, last.(lcols)))

quoteof(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:call, nameof(TupleOf), quoteof_inner.(shp.cols)...)
    else
        Expr(:call, nameof(TupleOf), quoteof_inner.(shp.lbls .=> shp.cols)...)
    end

syntaxof(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:tuple, syntaxof.(shp.cols)...)
    else
        Expr(:tuple, syntaxof.(shp.lbls .=> shp.cols)...)
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

columns(shp::TupleOf) = shp.cols

column(shp::TupleOf, j::Int) = shp.cols[j]

column(shp::TupleOf, lbl::Symbol) =
    column(shp, findfirst(isequal(lbl), shp.lbls))

function replace_column(shp::TupleOf, j::Int, f)
    col = shp.cols[j]
    col′ = f isa AbstractShape ? f : f(col)
    cols′ = copy(shp.cols)
    cols′[j] = col′
    TupleOf(shp.lbls, cols′)
end

function eltype(shp::TupleOf)
    t = Tuple{eltype.(shp.cols)...}
    if isempty(shp.lbls)
        t
    else
        NamedTuple{(shp.lbls...,),t}
    end
end

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

elements(shp::BlockOf) = shp.elts

function replace_elements(shp::BlockOf, f)
    elts′ = f isa AbstractShape ? f : f(shp.elts)
    BlockOf(elts′, shp.card)
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
    all(fits.(shp1.cols, shp2.cols)) &&
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
    TupleOf(labels(tv), shapeof.(columns(tv)))

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

