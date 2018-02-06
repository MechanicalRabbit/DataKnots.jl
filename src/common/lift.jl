#
# Lifting regular functions and operators.
#


struct LiftPrim{F<:Function} <: AbstractPrimitive
    fn::F
end

Lift(fn, Xs...) =
    Combinator(WrapOp(LiftPrim(fn)), Combinator[convert(Combinator, X) for X in Xs])

Lift′(fn) = Combinator(LiftPrim(fn))

Layouts.layout(op::WrapOp{LiftPrim{F}}, args::Vector{Layouts.Layout}) where {F} =
    Layouts.layout(Layouts.Layout[Layouts.literal(repr(op.prim.fn)), args...], brk=("Lift(",")"))

Layouts.layout(op::LiftPrim) =
    Layouts.literal("Lift′($(op.fn))")

Base.Broadcast._containertype(::Type{Combinator}) = Combinator

Base.Broadcast.promote_containertype(::Type{Combinator}, ::Type{Combinator}) =
    Combinator

Base.Broadcast.promote_containertype(::Type{Combinator}, ::Type{Any}) =
    Combinator

Base.Broadcast.promote_containertype(::Type{Any}, ::Type{Combinator}) =
    Combinator

Base.Broadcast.broadcast_c(fn, ::Type{Combinator}, Xs...) =
    Combinator(WrapOp(LiftPrim(fn)), collect(Combinator, Xs))

combine(env::Environment, q::Query, op::WrapOp{P}, args::Vector{Combinator}) where {P<:LiftPrim} =
    let it = stub(q)
        q >> combine(env, record(Query[combine(env, it, arg) for arg in args]), op.prim)
    end

function Query(op::LiftPrim, dom::Domain)
    argdoms = dom[:]
    card = bound(Cardinality[cardinality(argdom) for argdom in argdoms])
    argtypes = Type[eltype(argdom[]) for argdom in argdoms]
    restype = Union{Base.return_types(op.fn, (argtypes...))...}
    isig = InputDomain(Domain[OutputDomain(card, Domain(argtype)) for argtype in argtypes])
    osig = OutputDomain(restype)
    return Query(op, isig, osig)
end

function execute(op::LiftPrim, input::KnotVector)
    argdoms = domain(input)[][:]
    card = bound(Cardinality[cardinality(argdom) for argdom in argdoms])
    argtypes = Type[eltype(argdom[]) for argdom in argdoms]
    restype = Union{Base.return_types(op.fn, (argtypes...))...}
    len = length(input)
    if card == REG
        vals = regular_lift_map(op.fn, restype, len, map(items, columns(values(input)))...)
    else
        vals = lift_map(op.fn, restype, len, map(col -> (offsets(col), items(col)), columns(values(input)))...)
    end
    dom = OutputDomain(card, Domain(restype))
    return KnotVector(vals, dom)
end

@generated function regular_lift_map(fn, ty::Type, len::Int, args::AbstractVector...)
    ar = length(args)
    argvals_vars = ((Symbol("argvals", i) for i = 1:ar)...)
    init = :()
    for i = 1:ar
        init = quote
            $init
            $(argvals_vars[i]) = args[$i]
        end
    end
    return quote
        $init
        ($(argvals_vars...),) = args
        itms = Vector{ty}(len)
        @inbounds for k = 1:len
            itms[k] = fn($((:($argvals_var[k]) for argvals_var in argvals_vars)...))
        end
        return SliceVector(itms)
    end
end

