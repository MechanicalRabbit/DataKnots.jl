# DataKnots' Query Rewrites

This is a regression test for the query rewrite system.

    using DataKnots:
        @VectorTree,
        Pipeline,
        assemble,
        block_filler,
        block_lift,
        chain_of,
        column,
        filler,
        flatten,
        lift,
        null_filler,
        pass,
        rewrite_all,
        shape,
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

    X(rt::DataKnots.Runtime, input::AbstractVector) = []
    X() = Pipeline(X)

    Y(rt::DataKnots.Runtime, input::AbstractVector) = []
    Y() = Pipeline(Y)

    Z(rt::DataKnots.Runtime, input::AbstractVector) = []
    Z() = Pipeline(Z)

## Simplify

There are lots of combinations with `pass()` and other constructs that
end up being equivalent to `pass()`. We use `N` to signify any integer,
but fix it on a particular value for purposes of the test.

    r(chain_of(pass()))
    #-> pass()

    r(chain_of(X(), pass()))
    #-> X()

    r(with_elements(pass()))
    #-> pass()

    N=2; r(with_column(N, pass()))
    #-> pass()

    N=2; r(chain_of(pass(), with_column(N, with_elements(pass()))))
    #-> pass()

A pipeline chain that ends with a `filler` can ignore previous entries.
Here we use `X()` to represent any pipeline.

    r(chain_of(X(), null_filler()))
    #-> null_filler()

    r(chain_of(X(), filler("A")))
    #-> filler("A")

    r(chain_of(X(), block_filler([], x0toN)))
    #-> block_filler([], x0toN)

A `tuple_of` constructed followed by a `column` can be simplified to
just the column that was chosen.

    N=1; r(chain_of(tuple_of(X(), pass()), column(N)))
    #-> X()

Chained operations can be distributed over tuples.

    N=1; r(chain_of(tuple_of(X(), Y()), with_column(N, Z())))
    #-> tuple_of(chain_of(X(), Z()), Y())

In all cases, `flatten()` will undo a `wrap`.

    r(chain_of(wrap(), flatten()))
    #-> pass()

Since `wrap()` is 1-1/onto transformation and since `with_elements`
operates once per input, `with_elements` is a noop in this case.

    r(chain_of(wrap(), with_elements(X())))
    #-> chain_of(X(), wrap())

Since `wrap()` preserves values according to elementwise access, it can
be optimized if subsequent operations, such as `lift()`, only accesses
its input elementwise.

    r(chain_of(wrap(), lift(uppercase)))
    #-> lift(uppercase)

    r(chain_of(tuple_of(wrap(), X()), Y()))
    #->chain_of(tuple_of(pass(), X(), Y()))

    r(chain_of(tuple_of(chain_of(X(), wrap()), Y()), tuple_lift(+)))
    #-> chain_of(tuple_of(X(), Y()), tuple_lift(+))

