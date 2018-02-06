#
# Record combinator.
#

struct RecordOp <: AbstractOperation
end

Record(Fs::Vector{Combinator}) =
    Combinator(RecordOp(), Fs)

Record(Fs...) =
    Record(collect(Combinator, Fs))

Layouts.layout(::RecordOp, args::Vector{Layouts.Layout}) =
    Layouts.layout(args; brk=("Record(",")"))

combine(env::Environment, q::Query, ::RecordOp, Xs::Vector{Combinator}) =
    let it = stub(q)
        q >> record(Query[combine(env, it, X) for X in Xs])
    end

record(qs...) =
    record(collect(Query, qs))

function record(qs::Vector{Query})
    idom = ibound(Domain[idomain(q) for q in qs])
    dom = OutputDomain(Domain[domain(q) for q in qs])
    return Query(RecordOp(), qs, idom, dom)
end

function execute(::RecordOp, args::Vector{Query}, input::KnotVector)
    outputs = KnotVector[execute(arg, narrow(idomain(arg), input)) for arg in args]
    dom = OutputDomain(Domain(Domain[domain(output) for output in outputs]))
    vals = SliceVector(TupleVector(length(input), AbstractVector[values(output) for output in outputs]))
    refs = Pair{Symbol,AbstractVector}[]
    for output in outputs
        merge!(refs, output.refs)
    end
    return KnotVector(vals, dom, refs)
end

