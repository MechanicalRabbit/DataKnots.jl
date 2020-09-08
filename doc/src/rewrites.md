# DataKnots' Query Rewrites

This is a regression test for the query rewrite system.

    using DataKnots

    using DataKnots:
        @VectorTree,
        Pipeline,
        assemble,
        block_filler,
        block_lift,
        chain_of,
        column,
        delinearize!,
        distribute,
        distribute_all,
        filler,
        flatten,
        lift,
        linearize,
        null_filler,
        pass,
        rewrite_all,
        shape,
        sieve_by,
        simplify!,
        signature,
        tuple_lift,
        tuple_of,
        unitknot,
        with_column,
        with_elements,
        wrap,
        x0toN

    r = rewrite_all

In many cases, we'll be doing rewrites that are independent of the
pipeline provided. In these cases, we'll define `A()`, `B()`, etc.  to
represent arbitrary pipelines.

    A(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    A(args...) = Pipeline(A, args...)

    B(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    B(args...) = Pipeline(B, args...)

    C(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    C(args...) = Pipeline(C, args...)

    D(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    D(args...) = Pipeline(D, args...)

    E(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    E(args...) = Pipeline(E, args...)

Sometimes there's a Julia function which can also be arbitrary, we'll
use the function `fn` for this purpose.

    fn() = nothing

## Simplifications

There are lots of combinations with `pass()` and other constructs that
end up being equivalent to `pass()`. We use `N` to signify any integer,
but fix it on a particular value for purposes of the test.

    r(chain_of(pass()))
    #-> pass()

    r(chain_of(wrap(), flatten()))
    #-> pass()

    r(chain_of(wrap(), with_elements(A())))
    #-> chain_of(A(), wrap())

## Natural Transformations

Locally, we know that `chain_of(wrap(), flatten())` reduces to `pass()`,
however, what if `wrap()` is separated from `flatten()` with a natural
transformation, such as `distribute(1)` between them?

    p = chain_of(
         with_column(1, A()),
         with_column(1, with_elements(wrap())),
         distribute(1),
         with_elements(with_column(1, with_elements(with_elements(C())))),
         with_elements(with_column(1, with_elements(D()))),
         with_elements(with_column(1, flatten())),
         with_elements(with_column(1, E())))

With a simple query we can have a farily complex tree.

    q = assemble(convert(DataKnot,10), @query keep(x => 0.5).(it * x))


