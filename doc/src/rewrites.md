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

## Local Simplification

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

    N=2; r(chain_of(tuple_of(X(), Y(), Z()), column(N)))
    #-> Y()

Chained column operations can be moved inside the specified column
within the tuple constructor.

    N=1; r(chain_of(tuple_of(X(), Y()), with_column(N, Z())))
    #-> tuple_of(chain_of(X(), Z()), Y())

A `chain_of` sequential `with_elements` can be distributed.

    r(chain_of(with_elements(X()), with_elements(Y())))
    #-> with_elements(chain_of(X(), Y()))

In all cases, `flatten()` will undo a `wrap`.

    r(chain_of(wrap(), flatten()))
    #-> pass()

Since `wrap()` is 1-1/onto transformation and since `with_elements`
operates once per input, `with_elements` is a noop in this case.

    r(chain_of(wrap(), with_elements(X())))
    #-> chain_of(X(), wrap())

Since `wrap()` preserves values according to elementwise access, it can
be optimized if subsequent operations, such as `lift()` and
`tuple_lift()`, only accesses their input elementwise.

    r(chain_of(wrap(), lift(fn)))
    #-> lift(fn)

    r(chain_of(tuple_of(wrap(), X()), tuple_lift(fn)))
    #->chain_of(tuple_of(pass(), X()), tuple_lift(fn))

    r(chain_of(tuple_of(chain_of(X(), wrap()), Y()), tuple_lift(fn)))
    #-> chain_of(tuple_of(X(), Y()), tuple_lift(fn))

    N=2; r(chain_of(with_column(N, wrap()), distribute(N)))
    #-> wrap()

The `distribute` pipeline constructor transforms a tuple vector with a
column of blocks to a block vector with tuple elements.

    N=2; r(chain_of(with_column(N, wrap()), distribute(N)))
    #-> wrap()

    N=2; r(chain_of(with_column(N, chain_of(X(), wrap())), distribute(N)))
    #-> chain_of(with_column(2, X()), wrap())

We can move `flatten` to as late in the process as possible.

    N=2; r(chain_of(flatten(), with_elements(column(N))))
    #-> chain_of(with_elements(with_elements(column(2))), flatten())

    N=2; r(chain_of(flatten(), with_elements(chain_of(column(N), X()))))
    #=>
    chain_of(with_elements(with_elements(column(2))),
             flatten(),
             with_elements(X()))
    =#

A few more re-arangements given `chain_of` and `with_elements`.

    N=2; r(chain_of(distribute(N), with_elements(column(N))))
    #-> column(2)

    N=2; r(chain_of(distribute(N), with_elements(chain_of(column(N), X()))))
    #-> chain_of(column(2), with_elements(X()))

    N=2; r(chain_of(sieve_by(), with_elements(column(N))))
    #-> chain_of(with_column(1, column(2)), sieve_by())

## Common Sub-Expression Elimination

    r(tuple_of(X(), X()))
    #-> chain_of(X(), tuple_of(pass(), pass()))

