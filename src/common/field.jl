#
# Tuple field.
#

struct TaggedFieldOp <: AbstractPrimitive
    tag::Symbol
end

struct FieldOp <: AbstractPrimitive
    pos::Int
end

Field(tag::Symbol) =
    Combinator(TaggedFieldOp(tag))

Field(pos::Int) =
    Combinator(FieldOp(pos))

Layouts.layout(op::TaggedFieldOp) =
    Layouts.literal("Field($(repr(op.tag)))")

Layouts.layout(op::FieldOp) =
    Layouts.literal("Field($(op.pos))")

function Query(op::TaggedFieldOp, dom::Domain)
    q = lookup(dom, op.tag)
    @assert q !== nothing "$(op.tag) is not a field of $dom"
    q::Query
end

Query(op::FieldOp, dom::Domain) =
    Query(op, InputDomain(dom), dom[op.pos])

function lookup(dom::Domain, tag::Symbol)
    shape(dom) isa DataKnots.TupleShape || return nothing
    for (pos, field) in enumerate(dom[:])
        shape(field) isa OutputShape || continue
        ftag = decoration(field[], :tag, Symbol)
        if ftag == tag
            return Query(FieldOp(pos), dom)
        end
    end
    nothing
end

execute(op::FieldOp, input::KnotVector) =
    KnotVector(column(input.vals, op.pos), input.dom[][op.pos], input.refs)

