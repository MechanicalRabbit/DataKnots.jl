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
        distribute,
        distribute_all,
        filler,
        flatten,
        lift,
        null_filler,
        pass,
        rewrite_all,
        shape,
        sieve_by,
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
pipeline provided. In these cases, we'll define `X()`, `Y()`, and `Z()`
to represent arbitrary pipelines.

    X(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    X() = Pipeline(X)

    Y(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    Y() = Pipeline(Y)

    Z(rt::DataKnots.Runtime, input::AbstractVector) = [1:length(input)]
    Z() = Pipeline(Z)

Sometimes there's a Julia function which can also be arbitrary, we'll
use the function `fn` for this purpose.

    fn() = nothing

## Simplifications

There are lots of combinations with `pass()` and other constructs that
end up being equivalent to `pass()`. We use `N` to signify any integer,
but fix it on a particular value for purposes of the test.

    r(chain_of(pass()))
    #-> pass()

