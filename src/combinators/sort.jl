#
# Sorting combinator.
#

ordering_spec(::AbstractShape, rev::Bool) = nothing

ordering_spec(::NativeShape, rev::Bool) = rev

ordering_spec(shp::OutputShape, rev::Bool) =
    (rev ⊻ decoration(domain(shp), :rev, Bool, false), ordering_spec(domain(shp), rev))

ordering_spec(shp::DecoratedShape, rev::Bool) =
    ordering_spec(shp[], rev ⊻ decoration(shp, :rev, Bool, false))

ordering_spec(shp::RecordShape, rev::Bool) =
    ((ordering_spec(col, rev) for col in shp[:])...,)

asc() =
    Combinator(asc)

desc() =
    Combinator(desc)

convert(::Type{SomeCombinator}, ::typeof(asc)) =
    asc()

convert(::Type{SomeCombinator}, ::typeof(desc)) =
    desc()

translate(::Type{Val{:asc}}, ::Tuple{}) =
    asc()

translate(::Type{Val{:desc}}, ::Tuple{}) =
    desc()

asc(env::Environment, q::Query) =
    q |> designate(ishape(q), shape(q) |> decorate(:rev => false))

desc(env::Environment, q::Query) =
    q |> designate(ishape(q), shape(q) |> decorate(:rev => true))

Base.sort(Xs::SomeCombinator...) =
    Combinator(sort, Xs...)

convert(::Type{SomeCombinator}, ::typeof(sort)) =
    sort()

translate(::Type{Val{:sort}}, args::Tuple) =
    sort(translate.(args)...)

Base.sort(env::Environment, q::Query) =
    let spec = ordering_spec(domain(q), false)
        chain_of(
            q,
            sort_it(spec),
        ) |> designate(ishape(q), shape(q))
    end

function Base.sort(env::Environment, q::Query, X::SomeCombinator)
    x = combine(X, env, stub(q))
    idom = idomain(q)
    imd = ibound(imode(q), imode(x))
    spec = ordering_spec(shape(x), false)
    chain_of(
        duplicate_input(imd),
        in_input(imd, chain_of(project_input(imd, imode(q)), q)),
        distribute(imd, mode(q)),
        in_output(mode(q),
                  tuple_of(chain_of(project_input(imd, imode(x)), x),
                           project_input(imd, InputMode()))),
        sort_by(spec),
    ) |> designate(InputShape(idom, imd), shape(q))
end

Base.sort(env::Environment, q::Query, Xs...) =
        sort(env, q, record(Xs...))

