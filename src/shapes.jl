#
# Representing data shapes and query signatures.
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
    flds::Vector{AbstractShape}
end

let NO_LBLS = Symbol[]

    global TupleOf

    @inline TupleOf() =
        TupleOf(NO_LBLS, AbstractShape[])

    @inline TupleOf(flds::Vector{AbstractShape}) =
        TupleOf(NO_LBLS, flds)

    @inline TupleOf(flds::Union{AbstractShape,Type}...) =
        TupleOf(NO_LBLS, collect(AbstractShape, flds))
end

@inline TupleOf(lflds::Pair{<:Union{Symbol,String},<:Union{AbstractShape,Type}}...) =
    TupleOf(collect(Symbol.(first.(lflds))), collect(AbstractShape, last.(lflds)))

syntax(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:call, nameof(TupleOf), syntax.(shp.flds)...)
    else
        Expr(:call, nameof(TupleOf), syntax.(shp.lbls .=> shp.flds)...)
    end

sigsyntax(shp::TupleOf) =
    if isempty(shp.lbls)
        Expr(:tuple, sigsyntax.(shp.flds)...)
    else
        Expr(:tuple, sigsyntax.(shp.lbls .=> shp.flds)...)
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
    return SymboL('#' * lbl)
end

function label(shp::TupleOf, k::Int)
    !isempty(shp.lbls) ? shp.lbls[k] : label(k)
end

@inline getindex(shp::TupleOf, ::Colon) = shp.flds

@inline getindex(shp::TupleOf, k::Int) = shp.flds[k]

@inline getindex(shp::TupleOf, lbl::Union{Symbol,String}) =
    shp[findfirst(isequal(Symbol(lbl)), shp.lbls)]

@inline width(shp::TupleOf) = length(shp.flds)

"""
    BlockOf(eshp::AbstractShape, card::Cardinality=x0toN)

Shape of a `BlockVector`.
"""
struct BlockOf <: AbstractShape
    elt::AbstractShape
    card::Cardinality
end

BlockOf(elt) =
    BlockOf(elt, x0toN)

syntax(shp::BlockOf) =
    if shp.card == x0toN
        Expr(:call, nameof(BlockOf), syntax_inner(shp.elt))
    else
        Expr(:call, nameof(BlockOf), syntax_inner(shp.elt), syntax(shp.card))
    end

sigsyntax(shp::BlockOf) =
    Expr(:call, :×, sigsyntax(shp.card), sigsyntax(shp.elt))

@inline getindex(shp::BlockOf) = shp.elt

@inline cardinality(shp::BlockOf) = shp.card

@inline isregular(shp::BlockOf) = isregular(shp.card)

@inline isoptional(shp::BlockOf) = isoptional(shp.card)

@inline isplural(shp::BlockOf) = isplural(shp.card)


#
# Annotations.
#

abstract type Annotation <: AbstractShape end

@inline getindex(shp::Annotation) = shp.sub

sigsyntax(shp::Annotation) =
    sigsyntax(shp.sub)

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

"""
    sub |> IsMonad()
"""

struct IsMonad <: Annotation
    sub::AbstractShape
end

IsMonad() =
    sub -> IsMonad(sub)

syntax(shp::IsMonad) =
    Expr(:call, nameof(|>), syntax_inner(shp.sub), Expr(:call, nameof(IsMonad)))

"""
    sub |> IsComonad()
"""

struct IsComonad <: Annotation
    sub::AbstractShape
end

IsComonad() =
    sub -> IsComonad(sub)

syntax(shp::IsComonad) =
    Expr(:call, nameof(|>), syntax_inner(shp.sub), Expr(:call, nameof(IsComonad)))


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
# Signature of a query.
#

"""
    Signature(::InputShape, ::OutputShape)

Shapes of a query input and output.
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

