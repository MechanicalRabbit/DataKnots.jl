#
# Representing data shapes and pipeline signatures.
#

import Base:
    convert,
    getindex,
    eltype,
    show


# Ordering test.

"""
    fits(x::T, y::T) :: Bool

Checks if constraint `x` implies constraint `y`.
"""
function fits end

#
# Order on cardinalities.
#

fits(c1::Cardinality, c2::Cardinality) = (c1 | c2) == c2


#
# Represents the shape of data.
#

"""
    AbstractShape

Represents the structure of column-oriented data.
"""
abstract type AbstractShape end

syntax(shp::AbstractShape) =
    Expr(:call, nameof(typeof(shp)))

syntax(p::Pair{Symbol,<:AbstractShape}) =
    Expr(:call, :(=>), syntax(siglabel(p.first)), syntax(p.second))

syntax_inner(shp::AbstractShape) =
    syntax(shp)

siglabel(lbl::Symbol) =
    Base.isidentifier(lbl) ? lbl : string(lbl)

sigsyntax(shp::AbstractShape) =
    nameof(typeof(shp))

sigsyntax(p::Pair{Symbol,<:AbstractShape}) =
    Expr(:(=), siglabel(p.first), sigsyntax(p.second))

show(io::IO, shp::AbstractShape) =
    print_expr(io, syntax(shp))


#
# Concrete shapes.
#

"""
    AnyShape()

Nothing is known about the data.
"""
struct AnyShape <: AbstractShape
end

syntax_inner(::AnyShape) =
    :Any

sigsyntax(::AnyShape) =
    :Any

eltype(::AnyShape) = Any

"""
    NoShape()

Inconsistent constraints on the data.
"""
struct NoShape <: AbstractShape
end

sigsyntax(::NoShape) =
    :None

eltype(::NoShape) = Union{}

"""
    ValueOf(::Type)

Shape of an atomic Julia value.
"""

struct ValueOf <: AbstractShape
    ty::Type
end

ValueOf(::Type{Any}) =
    AnyShape()

ValueOf(::Type{Union{}}) =
    NoShape()

convert(::Type{AbstractShape}, ty::Type) =
    ValueOf(ty)

syntax(shp::ValueOf) =
    Expr(:call, nameof(ValueOf), shp.ty)

syntax_inner(shp::ValueOf) =
    shp.ty

sigsyntax(shp::ValueOf) = shp.ty

eltype(shp::ValueOf) = shp.ty

"""
    TupleOf([lbls::Vector{Symbol},] flds::Vector{AbstractShape})
    TupleOf(flds::AbstractShape...)
    TupleOf(lflds::Pair{<:Union{Symbol,String},<:AbstractShape}...)

Shape of a `TupleVector`.
"""

struct TupleOf <: AbstractShape
    lbls::Vector{Symbol}
    cols::Vector{AbstractShape}
end

let NO_LBLS = Symbol[]

    global TupleOf

    @inline TupleOf() =
        TupleOf(NO_LBLS, AbstractShape[])

    @inline TupleOf(cols::Vector{AbstractShape}) =
        TupleOf(NO_LBLS, cols)

    @inline TupleOf(cols::Union{AbstractShape,Type}...) =
        TupleOf(NO_LBLS, collect(AbstractShape, cols))
end

@inline TupleOf(lcols::Pair{<:Union{Symbol,String},<:Union{AbstractShape,Type}}...) =
    TupleOf(collect(Symbol.(first.(lcols))), collect(AbstractShape, last.(lcols)))

syntax(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:call, nameof(TupleOf), syntax.(shp.cols)...)
    else
        Expr(:call, nameof(TupleOf), syntax.(shp.lbls .=> shp.cols)...)
    end

sigsyntax(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:tuple, sigsyntax.(shp.cols)...)
    else
        Expr(:tuple, sigsyntax.(shp.lbls .=> shp.cols)...)
    end

@inline labels(shp::TupleOf) = shp.lbls

function label(k::Int)
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
    !isempty(shp.lbls) ? shp.lbls[k] : label(k)
end

@inline getindex(shp::TupleOf, ::Colon) = shp.cols

@inline getindex(shp::TupleOf, k::Int) = shp.cols[k]

@inline getindex(shp::TupleOf, lbl::Union{Symbol,String}) =
    shp[findfirst(isequal(Symbol(lbl)), shp.lbls)]

@inline width(shp::TupleOf) = length(shp.cols)

@inline columns(shp::TupleOf) = shp.cols

@inline column(shp::TupleOf, j::Int) = shp.cols[j]

@inline column(shp::TupleOf, lbl::Symbol) =
    column(shp, findfirst(isequal(lbl), shp.lbls))

function with_column(shp::TupleOf, j::Int, f)
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
    BlockOf(eshp::AbstractShape, card::Cardinality=x0toN)

Shape of a `BlockVector`.
"""
struct BlockOf <: AbstractShape
    elts::AbstractShape
    card::Cardinality
end

BlockOf(elts) =
    BlockOf(elts, x0toN)

syntax(shp::BlockOf) =
    if shp.card == x0toN
        Expr(:call, nameof(BlockOf), syntax_inner(shp.elts))
    else
        Expr(:call, nameof(BlockOf), syntax_inner(shp.elts), syntax(shp.card))
    end

sigsyntax(shp::BlockOf) =
    Expr(:call, :×, sigsyntax(shp.card), sigsyntax(shp.elts))

@inline getindex(shp::BlockOf) = shp.elts

@inline elements(shp::BlockOf) = shp.elts

function with_elements(shp::BlockOf, f)
    elts′ = f isa AbstractShape ? f : f(shp.elts)
    BlockOf(elts′, shp.card)
end

@inline cardinality(shp::BlockOf) = shp.card

@inline isregular(shp::BlockOf) = isregular(shp.card)

@inline isoptional(shp::BlockOf) = isoptional(shp.card)

@inline isplural(shp::BlockOf) = isplural(shp.card)

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

@inline getindex(shp::Annotation) = shp.sub

sigsyntax(shp::Annotation) =
    sigsyntax(shp.sub)

eltype(shp::Annotation) =
    eltype(subject(shp))

"""
    shp |> HasLabel(::Symbol)
"""
struct HasLabel <: Annotation
    sub::AbstractShape
    lbl::Symbol
end

HasLabel(sub::Union{AbstractShape,Type}, lbl::Union{Symbol,String}) =
    HasLabel(convert(AbstractShape, sub), Symbol(lbl))

HasLabel(lbl::Union{Symbol,String}) =
    sub -> HasLabel(sub, lbl)

syntax(shp::HasLabel) =
    Expr(:call, nameof(|>), syntax_inner(shp.sub), Expr(:call, nameof(HasLabel), syntax(siglabel(shp.lbl))))

subject(shp::HasLabel) = shp.sub

with_subject(shp::HasLabel, f) =
    HasLabel(f isa AbstractShape ? f : f(shp.sub), shp.lbl)

label(shp::HasLabel, default=nothing) =
    shp.lbl

"""
    sub |> IsFlow
"""

struct IsFlow <: Annotation
    sub::BlockOf
end

syntax(shp::IsFlow) =
    Expr(:call, nameof(|>), syntax_inner(shp.sub), nameof(IsFlow))

subject(shp::IsFlow) = shp.sub

with_subject(shp::IsFlow, f) =
    IsFlow(f isa AbstractShape ? f : f(shp.sub))

elements(shp::IsFlow) =
    elements(shp.sub)

with_elements(shp::IsFlow, f) =
    with_subject(shp, sub -> with_elements(sub, f))

cardinality(shp::IsFlow) =
    cardinality(subject(shp))

"""
    sub |> IsScope
"""

struct IsScope <: Annotation
    sub::TupleOf
end

syntax(shp::IsScope) =
    Expr(:call, nameof(|>), syntax_inner(shp.sub), nameof(IsScope))

subject(shp::IsScope) = shp.sub

with_subject(shp::IsScope, f) =
    IsScope(f isa AbstractShape ? f : f(shp.sub))

column(shp::IsScope) =
    column(shp.sub, 1)

with_column(shp::IsScope, f) =
    with_subject(shp, sub -> with_column(sub, 1, f))

context(shp::IsScope) =
    column(shp.sub, 2)


#
# Guessing the shape of a vector.
#

shapeof(v::AbstractVector) =
    ValueOf(eltype(v))

shapeof(tv::TupleVector) =
    TupleOf(labels(tv), shapeof.(columns(tv)))

shapeof(bv::BlockVector) =
    BlockOf(shapeof(elements(bv)), cardinality(bv))


#
# Signature of a pipeline.
#

"""
    Signature(::InputShape, ::OutputShape)

Shapes of a pipeline input and output.
"""
struct Signature
    ishp::AbstractShape
    shp::AbstractShape
end

Signature() = Signature(NoShape(), AnyShape())

syntax(sig::Signature) =
    Expr(:call, nameof(Signature), syntax(sig.ishp), syntax(sig.shp))

sigsyntax(sig::Signature) =
    Expr(:(->), sigsyntax(sig.ishp), sigsyntax(sig.shp))

show(io::IO, sig::Signature) =
    print_expr(io, syntax(sig))

ishape(sig::Signature) = sig.ishp

shape(sig::Signature) = sig.shp

