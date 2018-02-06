#
# Query definition.
#

struct Query
    op::AbstractOperation
    args::Vector{Query}
    idom::Domain
    dom::Domain
end

let NO_ARGS = Query[]
    Query(op::AbstractPrimitive, idom::Domain, dom::Domain) =
        Query(op, NO_ARGS, idom, dom)
end

show(io::IO, q::Query) =
    Layouts.render_single_layout(io, q)

show(io::IO, ::MIME"text/plain", q::Query) =
    Layouts.render_best_layout(io, q)

Layouts.layout(q::Query) =
    Layouts.layout(q.op, q.args)

Layouts.layout(op::AbstractOperation, args::Vector{Query}) =
    Layouts.layout(op, Layouts.Layout[Layouts.layout(arg) for arg in args])

Layouts.layout(op::AbstractPrimitive, ::Vector{Query}) =
    Layouts.layout(op)

operation(q::Query) = q.op

arguments(q::Query) = q.args

getitem(q::Query, ::Colon) = q.args

idomain(q::Query) = q.idom

ishape(q::Query) = shape(q.idom)

domain(q::Query) = q.dom

shape(q::Query) = shape(q.dom)

cardinality(q::Query) = cardinality(q.dom)

function execute(q::Query, input::KnotVector)
    #println("$q : $(q.idom) -> $(q.dom)")
    @assert fits(input.dom, q.idom) "input $(input.dom) does not match the query signature $q : $(q.idom) -> $(q.dom))"
    output = execute(q.op, q.args, q.idom, q.dom, input)
    @assert fits(output.dom, q.dom) "output $(output.dom) does not match the query signature $q : $(q.idom) -> $(q.dom))"
    output
end

@inline execute(op::AbstractOperation, args::Vector{Query}, idom::Domain, dom::Domain, input::KnotVector) =
    execute(op, args, input)

@inline execute(op::AbstractPrimitive, ::Vector{Query}, idom::Domain, dom::Domain, input::KnotVector) =
    execute(op, idom, dom, input)

@inline execute(op::AbstractPrimitive, ::Domain, ::Domain, input::KnotVector) =
    execute(op, input)

stub(q::Query) =
    stub(domain(q)[])

istub(q::Query) =
    stub(idomain(q)[])

stub(ty::Type) =
    stub(convert(Domain, ty))

stub(dom::Domain) =
    Query(ItOp(), InputDomain(dom), OutputDomain(dom))

fits(q::Query, r::Query) =
    fits(domain(q)[], idomain(r)[])

