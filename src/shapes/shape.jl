#
# Representing the shape of the data.
#

# Shape types.

abstract type AbstractShape end

syntax(shp::AbstractShape) =
    Expr(:call, nameof(typeof(shp)), Symbol(" … "))

sigsyntax(shp::AbstractShape) =
    nameof(typeof(shp))

show(io::IO, shp::AbstractShape) =
    Layouts.print_code(io, syntax(shp))

isclosed(::AbstractShape) =
    true

rebind(shp::AbstractShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    shp

rebind(bindings::Pair{Symbol}...) =
    let bindings = sort(collect(Pair{Symbol,AbstractShape}, bindings), by=first)
        obj -> rebind(obj, bindings)
    end

# Data shape known by its name.

struct ClassShape <: AbstractShape
    cls::Symbol
end

convert(::Type{AbstractShape}, cls::Symbol) =
    ClassShape(cls)

syntax(shp::ClassShape) =
    Expr(:call, nameof(ClassShape), QuoteNode(shp.cls))

sigsyntax(shp::ClassShape) =
    shp.cls

class(shp::ClassShape) =
    shp.cls

isclosed(::ClassShape) =
    false

rebind(shp::ClassShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    if any(shp.cls == binding.first for binding in bindings)
        ClosedShape(shp.cls, bindings)
    else
        shp
    end

# Named shape together with its definition.

struct ClosedShape <: AbstractShape
    cls::Symbol
    bindings::Vector{Pair{Symbol,AbstractShape}}
end

ClosedShape(cls, bindings::Pair{Symbol,<:AbstractShape}...) =
    ClosedShape(cls, sort(collect(Pair{Symbol,AbstractShape}, bindings), by=first))

syntax(shp::ClosedShape) =
    Expr(:call, :|>, syntax(ClassShape(shp.cls)), Expr(:call, rebind, syntax.(shp.bindings)...))

syntax(pair::Pair{Symbol,AbstractShape}) =
    Expr(:call, :(=>), QuoteNode(pair.first), syntax(pair.second))

sigsyntax(shp::ClosedShape) =
    shp.cls

class(shp::ClosedShape) =
    shp.cls

bindings(shp::ClosedShape) =
    shp.bindings

function getindex(shp::ClosedShape)
    for binding in shp.bindings
        if binding.first == shp.cls
            return rebind(binding.second, shp.bindings)
        end
    end
    ClassShape(shp.cls)
end

function decoration(shp::ClosedShape, name::Symbol, ty::Type=Any, default=missing)
    for binding in shp.bindings
        if binding.first == shp.cls
            return decoration(binding.second, name, ty, default)
        end
    end
    default
end

decorate(shp::ClosedShape, decors::Vector{Pair{Symbol,Any}}) =
    ClosedShape(shp.cls,
                Pair{Symbol,AbstractShape}[
                    binding.first == shp.cls ?
                        binding.first => decorate(binding.second, decors) : binding
                    for binding in shp.bindings])

# Arbitrary properties as constraints attached to a shape.

struct DecoratedShape <: AbstractShape
    base::AbstractShape
    decors::Vector{Pair{Symbol,Any}}
end

syntax(shp::DecoratedShape) =
    Expr(:call, :|>, syntax(shp.base), Expr(:call, decorate, shp.decors...))

sigsyntax(shp::DecoratedShape) =
    sigsyntax(shp.base)

decoration(::AbstractShape, ::Symbol, ::Type=Any, default=missing) =
    default

function decoration(shp::DecoratedShape, name::Symbol, ty::Type=Any, default=missing)
    for decor in shp.decors
        if decor.first == name
            val = decor.second
            if val isa ty
                return val::ty
            end
            break
        end
    end
    return default
end

isclosed(shp::DecoratedShape) = isclosed(shp.base)

rebind(shp::DecoratedShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    let base′ = rebind(shp.base, bindings)
        base === base′ ? shp : decorate(base′, shp.decors)
    end

getindex(shp::DecoratedShape) =
    shp.base

eltype(shp::DecoratedShape) =
    eltype(shp.base)

function decorate(shp::AbstractShape, decors::Vector{Pair{Symbol,Any}})
    if isempty(decors)
        return shp
    end
    return DecoratedShape(shp, decors)
end

function decorate(shp::DecoratedShape, decors::Vector{Pair{Symbol,Any}})
    if isempty(decors)
        return shp
    end
    return DecoratedShape(shp.base, merge(shp.decors, decors))
end

decorate(decors::Pair{Symbol}...) =
    let decors = sort(collect(Pair{Symbol,Any}, decors), by=first)
        obj -> decorate(obj, decors)
    end

# Indicates data of arbitrary shape.

struct AnyShape <: AbstractShape
end

syntax(::AnyShape) =
    Expr(:call, nameof(AnyShape))

sigsyntax(::AnyShape) =
    :Any

# Indicates contradictory constraints on the data.

struct NoneShape <: AbstractShape
end

syntax(::NoneShape) = Expr(:call, nameof(NoneShape))

sigsyntax(::NoneShape) =
    :None

# A regular Julia value of the given type.

struct NativeShape <: AbstractShape
    ty::Type
end

convert(::Type{AbstractShape}, ty::Type) =
    NativeShape(ty)

syntax(shp::NativeShape) =
    Expr(:call, nameof(NativeShape), shp.ty)

sigsyntax(shp::NativeShape) =
    nameof(shp.ty)

eltype(shp::NativeShape) = shp.ty

# Tuple with the given fields.

struct TupleShape <: AbstractShape
    cols::Vector{AbstractShape}
    closed::Bool

    TupleShape(cols::Vector{AbstractShape}) =
        new(cols, all(isclosed, cols))
end

TupleShape(itr...) =
    TupleShape(collect(AbstractShape, itr))

syntax(shp::TupleShape) =
    Expr(:call, nameof(TupleShape), map(syntax, shp.cols)...)

sigsyntax(shp::TupleShape) =
    Expr(:tuple, sigsyntax.(shp.cols)...)

getindex(shp::TupleShape, ::Colon) = shp.cols

getindex(shp::TupleShape, i) = shp.cols[i]

isclosed(shp::TupleShape) = shp.closed

rebind(shp::TupleShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    if !isclosed(shp)
        TupleShape(AbstractShape[rebind(col, bindings) for col in shp.cols])
    else
        shp
    end

# Collection of homogeneous elements.

struct BlockShape <: AbstractShape
    elts::AbstractShape
end

syntax(shp::BlockShape) =
    Expr(:call, nameof(BlockShape), syntax(shp.elts))

sigsyntax(shp::BlockShape) =
    Expr(:vect, sigsyntax(shp.elts))

getindex(shp::BlockShape) = shp.elts

isclosed(shp::BlockShape) = isclosed(shp.elts)

rebind(shp::BlockShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    if !isclosed(shp)
        BlockShape(rebind(shp.elts, bindings))
    else
        shp
    end

# Derived shapes have some underlying structural representation.

abstract type DerivedShape <: AbstractShape end

# Shape of the query output.

struct OutputMode
    card::Cardinality
end

OutputMode() = OutputMode(REG)

convert(::Type{OutputMode}, card::Cardinality) =
    OutputMode(card)

syntax(md::OutputMode) =
    md.card == REG ?
        Expr(:call, nameof(OutputMode)) :
        Expr(:call, nameof(OutputMode), md.card)

show(io::IO, md::OutputMode) =
    Layouts.print_code(io, syntax(md))

cardinality(md::OutputMode) = md.card

isregular(md::OutputMode) = isregular(md.card)

isoptional(md::OutputMode) = isoptional(md.card)

isplural(md::OutputMode) = isplural(md.card)

struct OutputShape <: DerivedShape
    dom::AbstractShape
    md::OutputMode
end

OutputShape(dom) = OutputShape(dom, REG)

syntax(shp::OutputShape) =
    if shp.md.card == REG
        Expr(:call, nameof(OutputShape), syntax(shp.dom))
    else
        Expr(:call, nameof(OutputShape), syntax(shp.dom), shp.md.card)
    end

function sigsyntax(shp::OutputShape)
    tag = decoration(shp.dom, :tag, Symbol, missing)
    s = string(tag)
    if isempty(s) || startswith(s, "#")
        tag = missing
    end
    ex = Expr(:ref,
              sigsyntax(shp.dom),
              Expr(:call, :(..), fits(OPT, shp.md.card) ? 0 : 1,
                                 fits(PLU, shp.md.card) ? :∞ : 1))
    if tag !== missing
        ex = Expr(:call, :(=>), tag, ex)
    end
    ex
end

getindex(shp::OutputShape) = shp.dom

isclosed(shp::OutputShape) = isclosed(shp.dom)

rebind(shp::OutputShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    if !isclosed(shp)
        OutputShape(rebind(shp.dom, bindings), shp.md)
    else
        shp
    end

domain(shp::OutputShape) = shp.dom

mode(shp::OutputShape) = shp.md

cardinality(shp::OutputShape) = shp.md.card

isregular(shp::OutputShape) = isregular(shp.md)

isoptional(shp::OutputShape) = isoptional(shp.md)

isplural(shp::OutputShape) = isplural(shp.md)

decoration(shp::OutputShape, name::Symbol, ty::Type=Any, default=missing) =
    decoration(shp.dom, name, ty, default)

decorate(shp::OutputShape, decors::Vector{Pair{Symbol,Any}}) =
    OutputShape(decorate(shp.dom, decors), shp.md)

# Shape of the query input.

struct InputMode
    slots::Vector{Pair{Symbol,OutputShape}}
    framed::Bool
end

let NO_SLOTS = Pair{Symbol,OutputShape}[]

    global InputMode

    InputMode(slots::Vector{Pair{Symbol,OutputShape}}) =
        InputMode(slots, false)

    InputMode(framed::Bool) =
        InputMode(NO_SLOTS, framed)

    InputMode() =
        InputMode(NO_SLOTS, false)
end

syntax(md::InputMode) =
    if isempty(md.slots) && !md.framed
        Expr(:call, nameof(InputMode))
    elseif isempty(md.slots)
        Expr(:call, nameof(InputMode), md.framed)
    elseif !md.framed
        Expr(:call, nameof(InputMode), syntax(md.slots))
    else
        Expr(:call, nameof(InputMode), syntax(md.slots), md.framed)
    end

show(io::IO, md::InputMode) =
    Layouts.print_code(io, syntax(md))

slots(md::InputMode) = md.slots

isframed(md::InputMode) = md.framed

isfree(md::InputMode) = isempty(md.slots) && !md.framed

struct InputShape <: DerivedShape
    dom::AbstractShape
    md::InputMode
end

InputShape(dom) = InputShape(dom, InputMode())

InputShape(dom, slots::Vector{Pair{Symbol,OutputShape}}) =
    InputShape(dom, InputMode(slots))

InputShape(dom, framed::Bool) =
    InputShape(dom, InputMode(framed))

InputShape(dom, slots::Vector{Pair{Symbol,OutputShape}}, framed::Bool) =
    InputShape(dom, InputMode(slots, framed))

function syntax(shp::InputShape)
    args = Any[syntax(shp.dom)]
    if !isempty(shp.md.slots)
        push!(args, Expr(:vect, map(slot -> Expr(:call, :(=>), QuoteNode(slot.first), syntax(slot.second)),
                                    shp.md.slots)...))
    end
    if shp.md.framed
        push!(args, shp.md.framed)
    end
    Expr(:call, nameof(InputShape), args...)
end

function sigsyntax(shp::InputShape)
    ex = sigsyntax(shp.dom)
    if !isempty(shp.md.slots)
        ex = Expr(:tuple, ex, map(slot -> Expr(:(=), slot.first, sigsyntax(slot.second)), shp.md.slots)...)
    end
    if shp.md.framed
        ex = Expr(:vect, Expr(:(...), ex))
    end
    ex
end

getindex(shp::InputShape) = shp.dom

domain(shp::InputShape) = shp.dom

mode(shp::InputShape) = shp.md

slots(shp::InputShape) = slots(shp.md)

isframed(shp::InputShape) = isframed(shp.md)

isfree(shp::InputShape) = isfree(shp.md)

decoration(shp::InputShape, name::Symbol, ty::Type=Any, default=missing) =
    decoration(shp.dom, name, ty, default)

decorate(shp::InputShape, decors::Vector{Pair{Symbol,Any}}) =
    InputShape(decorate(shp.dom, decors), shp.md)

# Shape of a record.

struct RecordShape <: DerivedShape
    flds::Vector{OutputShape}
    closed::Bool

    RecordShape(flds::Vector{OutputShape}) =
        new(flds, all(isclosed, flds))
end

RecordShape(itr...) =
    RecordShape(collect(OutputShape, itr))

syntax(shp::RecordShape) =
    Expr(:call, nameof(RecordShape), syntax.(shp.flds)...)

sigsyntax(shp::RecordShape) =
    Expr(:tuple, sigsyntax.(shp.flds)...)

getindex(shp::RecordShape, ::Colon) = shp.flds

getindex(shp::RecordShape, i) = shp.flds[i]

isclosed(shp::RecordShape) = shp.closed

rebind(shp::RecordShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    if !isclosed(shp)
        RecordShape(OutputShape[rebind(fld, bindings) for fld in shp.flds])
    else
        shp
    end

# Adding extra fields to the base shape.

struct ShadowShape <: DerivedShape
    base::AbstractShape
    flds::Vector{OutputShape}
    closed::Bool

    ShadowShape(base::AbstractShape, flds::Vector{OutputShape}) =
        new(base, flds, isclosed(base) && all(isclosed, flds))
end

ShadowShape(base, itr...) =
    ShadowShape(base, collect(OutputShape, itr))

syntax(shp::ShadowShape) =
    Expr(:call, nameof(ShadowShape), syntax(shp.base), syntax.(shp.flds)...)

sigsyntax(shp::ShadowShape) =
    Expr(:tuple, sigsyntax(shp.base), sigsyntax.(shp.flds)...)

getindex(shp::ShadowShape) = shp.base

getindex(shp::ShadowShape, ::Colon) = shp.flds

getindex(shp::ShadowShape, i) = shp.flds[i]

isclosed(shp::ShadowShape) = shp.closed

rebind(shp::ShadowShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    if !isclosed(shp)
        ShadowShape(rebind(shp.base, bindings), OutputShape[rebind(fld, bindings) for fld in shp.flds])
    else
        shp
    end

# Shape of a sorted index.

struct IndexShape <: DerivedShape
    key::OutputShape
    val::OutputShape
end

syntax(shp::IndexShape) =
    Expr(:call, nameof(IndexShape), shp.key, shp.val)

sigsyntax(shp::IndexShape) =
    Expr(:call, :(=>), syntax(shp.key), syntax(sh.val))

getindex(shp::IndexShape, ::Colon) =
    (shp.key, shp.val)

getindex(shp::IndexShape, i) =
    (shp.key, shp.val)[i]

isclosed(shp::IndexShape) =
    isclosed(shp.key) && isclosed(shp.val)

rebind(shp::IndexShape, bindings::Vector{Pair{Symbol,AbstractShape}}) =
    if !isclosed(shp.key) && !isclosed(shp.val)
        IndexShape(rebind(shp.key, bindings), rebind(shp.val), bindings)
    elseif !isclosed(shp.key)
        IndexShape(rebind(shp.key, bindings), shp.val)
    elseif !isclosed(shp.val)
        IndexShape(shp.key, rebind(shp.val, bindings))
    else
        shp
    end

# Subshape relation.

fits(shp1::AbstractShape, shp2::AbstractShape) = false

fits(shp1::S, shp2::S) where {S<:AbstractShape} =
    shp1 == shp2

fits(shp1::AbstractShape, shp2::AnyShape) =
    !isclosed(shp2) || isclosed(shp1)

fits(shp1::AnyShape, shp2::AnyShape) =
    !isclosed(shp2) || isclosed(shp1)

fits(::NoneShape, ::AbstractShape) = true

fits(::NoneShape, ::AnyShape) = true

fits(::NoneShape, ::NoneShape) = true

fits(shp1::DecoratedShape, shp2::AbstractShape) =
    fits(shp1.base, shp2)

fits(shp1::DecoratedShape, shp2::AnyShape) =
    fits(shp1.base, shp2)

fits(shp1::AbstractShape, shp2::DecoratedShape) =
    isempty(shp2.decors) && fits(shp1, shp2.base)

fits(shp1::NoneShape, shp2::DecoratedShape) =
    isempty(shp2.decors) && fits(shp1, shp2.base)

fits(shp1::DecoratedShape, shp2::DecoratedShape) =
    shp1 == shp2 ||
    fits(shp1.base, shp2.base) && fits(shp1.decors, shp2.decors)

function fits(decors1::Vector{Pair{Symbol,Any}}, decors2::Vector{Pair{Symbol,Any}})
    j = 1
    for decor2 in decors2
        while j <= length(decors1) && decors1[j].first < decor2.first
            j += 1
        end
        if j > length(decors1) || decors1[j].first != decor2.first
            return false
        end
        if !(decors1[j].second === nothing || isequal(decors1[j].second, decor2.second))
            return false
        end
    end
    return true
end

fits(shp1::NativeShape, shp2::NativeShape) =
    shp1.ty <: shp2.ty

fits(shp1::TupleShape, shp2::TupleShape) =
    shp1 == shp2 || shp1.cols == shp2.cols ||
    length(shp1.cols) == length(shp2.cols) &&
    all(fits(col1, col2) for (col1, col2) in zip(shp1.cols, shp2.cols))

fits(shp1::BlockShape, shp2::BlockShape) =
    shp1 == shp2 ||
    fits(shp1.elts, shp2.elts)

fits(shp1::ClassShape, shp2::ClassShape) =
    shp1.cls == shp2.cls

fits(shp1::ClosedShape, shp2::ClosedShape) =
    shp1 == shp2 ||
    shp1.cls == shp2.cls && fits(shp1.bindings, shp2.bindings)

fits(shp1::ClosedShape, shp2::ClassShape) =
    shp1.cls == shp2.cls

fits(shp1::ClassShape, shp2::ClosedShape) =
    isempty(shp2.bindings) && shp1.cls == shp2.cls

fits(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ||
    fits(shp1.md, shp2.md) &&
    fits(shp1.dom, shp2.dom)

fits(md1::OutputMode, md2::OutputMode) =
    fits(md1.card, md2.card)

fits(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ||
    fits(shp1.md, shp2.md) &&
    fits(shp1.dom, shp2.dom)

fits(md1::InputMode, md2::InputMode) =
    md1.framed >= md2.framed &&
    fits(md1.slots, md2.slots)

function fits(nshps1::Vector{Pair{Symbol,S}}, nshps2::Vector{Pair{Symbol,S}}) where {S<:AbstractShape}
    j = 1
    for nshp2 in nshps2
        while j <= length(nshps1) && nshps1[j].first < nshp2.first
            j += 1
        end
        if j > length(nshps1) || nshps1[j].first != nshp2.first
            return false
        end
        if !fits(nshps1[j].second, nshp2.second)
            return false
        end
    end
    return true
end

fits(shp1::RecordShape, shp2::RecordShape) =
    shp1 == shp2 || shp1.flds == shp2.flds ||
    length(shp1.flds) == length(shp2.flds) &&
    all(fits(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds))

fits(shp1::ShadowShape, shp2::ShadowShape) =
    shp1 == shp2 || shp1.base == shp2.base && shp1.flds == shp2.flds ||
    fits(shp1.base, shp2.base) &&
    length(shp1.flds) == length(shp2.flds) &&
    all(fits(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds))

fits(shp1::IndexShape, shp2::IndexShape) =
    shp1 == shp2 || shp1.key == shp2.key && shp1.val == shp2.val ||
    fits(shp1.key, shp2.key) && fits(shp1.val, shp2.val)

# Upper and lower bounds.

bound(::Type{<:AbstractShape}) = NoneShape()

ibound(::Type{<:AbstractShape}) = AnyShape()

bound(shp1::AbstractShape, shp2::AbstractShape) =
    AnyShape()

ibound(::AbstractShape, ::AbstractShape) = NoneShape()

bound(shp1::DecoratedShape, shp2::AbstractShape) =
    bound(shp1.base, shp2)

ibound(shp1::DecoratedShape, shp2::AbstractShape) =
    DecoratedShape(ibound(shp1.base, shp2), shp1.decors)

bound(shp1::AbstractShape, shp2::DecoratedShape) =
    bound(shp1, shp2.base)

ibound(shp1::AbstractShape, shp2::DecoratedShape) =
    DecoratedShape(ibound(shp1, shp2.base), shp2.decors)

bound(shp1::DecoratedShape, shp2::DecoratedShape) =
    shp1 == shp2 ? shp1 :
    let base = bound(shp1.base, shp2.base),
        decors = bound(shp1.decors, shp2.decors)
        isempty(decors) ? base : DecoratedShape(base, decors)
    end

ibound(shp1::DecoratedShape, shp2::DecoratedShape) =
    shp1 == shp2 ? shp1 :
    let base = ibound(shp1.base, shp2.base),
        decors = ibound(shp1.decors, shp2.decors)
        isempty(decors) ? base : DecoratedShape(base, decors)
    end

function bound(decors1::Vector{Pair{Symbol,Any}}, decors2::Vector{Pair{Symbol,Any}})
    decors = Pair{Symbol,Any}[]
    i = 1
    j = 1
    while i <= length(decors1) && j <= length(decors2)
        if decors1[i].first < decors2[j].first
            i += 1
        elseif decors1[i].first > decors2[j].first
            j += 1
        else
            if isequal(decors1[i].second, decors2[j].second) || decors2[j].second === nothing
                push!(decors, decors1[i])
            elseif decors1[i].second === nothing
                push!(decors, decors2[j])
            end
            i += 1
            j += 1
        end
    end
    decors
end

ibound(decors1::Vector{Pair{Symbol,Any}}, decors2::Vector{Pair{Symbol,Any}}) =
    merge((d1, d2) -> isequal(d1, d2) ? d1 : nothing, decors1, decors2)

bound(shp1::NoneShape, shp2::AbstractShape) = shp2

bound(shp1::NoneShape, shp2::DecoratedShape) = shp2

bound(shp1::AbstractShape, shp2::NoneShape) = shp1

bound(shp1::DecoratedShape, shp2::NoneShape) = shp1

bound(shp1::NoneShape, ::NoneShape) = shp1

ibound(shp1::AnyShape, shp2::AbstractShape) = shp2

ibound(shp1::AnyShape, shp2::DecoratedShape) =
    DecoratedShape(ibound(shp1, shp2.base), shp2.decors)

ibound(shp1::AbstractShape, shp2::AnyShape) = shp1

ibound(shp1::DecoratedShape, shp2::AnyShape) =
    DecoratedShape(ibound(shp1.base, shp2), shp1.decors)

ibound(shp1::AnyShape, shp2::AnyShape) = shp1

bound(shp1::NativeShape, shp2::NativeShape) =
    shp1 == shp2 ? shp1 :
    let ty = typejoin(shp1.ty, shp2.ty)
        ty == Any ? AnyShape() : NativeShape(ty)
    end

ibound(shp1::NativeShape, shp2::NativeShape) =
    shp1 == shp2 ? shp1 :
    let ty = typeintersect(shp1.ty, shp2.ty)
        ty == Union{} ? NoneShape() : NativeShape(ty)
    end

bound(shp1::ClassShape, shp2::ClassShape) =
    shp1.cls == shp2.cls ? shp1 : AnyShape()

ibound(shp1::ClassShape, shp2::ClassShape) =
    shp1.cls == shp2.cls ? shp1 : NoneShape()

bound(shp1::ClosedShape, shp2::ClosedShape) =
    shp1 == shp2 || shp1.cls == shp2.cls && shp1.bindings == shp2.bindings ? shp1 :
    shp1.cls == shp2.cls ? ClosedShape(shp1.cls, bound(shp1.bindings, shp2.bindings)) : AnyShape()

ibound(shp1::ClosedShape, shp2::ClosedShape) =
    shp1 == shp2 || shp1.cls == shp2.cls && shp1.bindings == shp2.bindings ? shp1 :
    shp1.cls == shp2.cls ? ClosedShape(shp1.cls, ibound(shp1.bindings, shp2.bindings)) : NoneShape()

bound(shp1::ClassShape, shp2::ClosedShape) =
    shp1.cls == shp2.cls ? shp1 : AnyShape()

bound(shp1::ClosedShape, shp2::ClassShape) =
    shp1.cls == shp2.cls ? shp2 : AnyShape()

ibound(shp1::ClassShape, shp2::ClosedShape) =
    shp1.cls == shp2.cls ? shp2 : NoneShape()

ibound(shp1::ClosedShape, shp2::ClassShape) =
    shp1.cls == shp2.cls ? shp1 : NoneShape()

bound(shp1::TupleShape, shp2::TupleShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.cols) == length(shp2.cols) ?
        TupleShape(AbstractShape[bound(col1, col2) for (col1, col2) in zip(shp1.cols, shp2.cols)]) :
        AnyShape(isclosed(shp1) && isclosed(shp2))

ibound(shp1::TupleShape, shp2::TupleShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.cols) == length(shp2.cols) ?
        TupleShape(AbstractShape[ibound(col1, col2) for (col1, col2) in zip(shp1.cols, shp2.cols)]) :
        NoneShape()

bound(shp1::BlockShape, shp2::BlockShape) =
    shp1 == shp2 ? shp1 :
    BlockShape(bound(shp1.elts, shp2.elts))

ibound(shp1::BlockShape, shp2::BlockShape) =
    shp1 == shp2 ? shp1 :
    BlockShape(ibound(shp1.elts, shp2.elts))

bound(::Type{OutputMode}) = OutputMode(bound(Cardinality))

bound(md1::OutputMode, md2::OutputMode) =
    OutputMode(bound(md1.card, md2.card))

ibound(::Type{OutputMode}) = OutputMode(ibound(Cardinality))

ibound(md1::OutputMode, md2::OutputMode) =
    OutputMode(ibound(md1.card, md2.card))

bound(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ? shp1 :
    OutputShape(bound(shp1.dom, shp2.dom), bound(shp1.md, shp2.md))

ibound(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ? shp1 :
    OutputShape(ibound(shp1.dom, shp2.dom), ibound(shp1.md, shp2.md))

bound(::Type{InputMode}) = error()

bound(md1::InputMode, md2::InputMode) =
    InputMode(bound(md1.slots, md2.slots), md1.framed && md2.framed)

ibound(::Type{InputMode}) = InputMode()

ibound(md1::InputMode, md2::InputMode) =
    InputMode(ibound(md1.slots, md2.slots), md1.framed || md2.framed)

bound(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ? shp1 :
    InputShape(bound(shp1.dom, shp2.dom), bound(shp1.md, shp2.md))

ibound(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ? shp1 :
    InputShape(ibound(shp1.dom, shp2.dom), ibound(shp1.md, shp2.md))

function bound(slots1::Vector{Pair{Symbol,S}}, slots2::Vector{Pair{Symbol,S}}) where {S<:AbstractShape}
    slots = Pair{Symbol,S}[]
    i = 1
    j = 1
    while i <= length(slots1) && j <= length(slots2)
        if slots1[i].first < slots2[j].first
            i += 1
        elseif slots1[i].first > slots2[j].first
            j += 1
        else
            if isequal(slots1[i].second, slots2[j].second)
                push!(slots, slots1[i])
            else
                push!(slots, Pair{Symbol,S}(slots1[i].first, bound(slots1[i].second, slots2[j].second)))
            end
            i += 1
            j += 1
        end
    end
    slots
end

ibound(slots1::Vector{Pair{Symbol,S}}, slots2::Vector{Pair{Symbol,S}}) where {S<:AbstractShape} =
    merge(ibound, slots1, slots2)

bound(shp1::RecordShape, shp2::RecordShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.flds) == length(shp2.flds) ?
        RecordShape(OutputShape[bound(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds)]) :
        AnyShape()

ibound(shp1::RecordShape, shp2::RecordShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.flds) == length(shp2.flds) ?
        RecordShape(OutputShape[ibound(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds)]) :
        NoneShape()

bound(shp1::ShadowShape, shp2::ShadowShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.flds) == length(shp2.flds) ?
        ShadowShape(bound(shp1.base, shp2.base),
                    OutputShape[bound(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds)]) :
        AnyShape()

ibound(shp1::ShadowShape, shp2::ShadowShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.flds) == length(shp2.flds) ?
        ShadowShape(ibound(shp1.base, shp2.base),
                    OutputShape[ibound(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds)]) :
        NoneShape()

bound(shp1::IndexShape, shp2::IndexShape) =
    shp1 == shp2 ? shp1 : IndexShape(bound(shp1.key, shp2.key), bound(shp1.val, shp2.val))

ibound(shp1::IndexShape, shp2::IndexShape) =
    shp1 == shp2 ? shp1 : IndexShape(ibound(shp1.key, shp2.key), ibound(shp1.val, shp2.val))

# Shape-aware vector.

struct ShapeAwareVector{T,V<:AbstractVector{T}} <: AbstractVector{T}
    shp::AbstractShape
    vals::V
end

