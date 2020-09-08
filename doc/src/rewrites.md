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

    r(with_column(1, pass()))
    #-> pass()

    r(with_elements(pass()))
    #-> pass()

    r(chain_of(wrap(), flatten()))
    #-> pass()

    r(chain_of(wrap(), with_elements(A())))
    #-> chain_of(A(), wrap())

    r(chain_of(wrap(), lift(fn)))
    #-> lift(fn)

    r(chain_of(A(), filler("A")))
    #-> filler("A")

    r(chain_of(A(), null_filler()))
    #-> null_filler()

    r(chain_of(A(), block_filler("A")))
    #-> block_filler("A", x0toN)

    r(chain_of(with_column(1, with_elements(wrap())), distribute(1)))
    #-> chain_of(distribute(1), with_elements(with_column(1, wrap())))

    r(chain_of(with_elements(wrap()), flatten()))
    #-> pass()

    r(chain_of(with_column(1, wrap()), distribute(1)))
    #-> wrap()

## Consequences

With the previous simplification rules, there are many combinations
combinations that come for free.

    r(chain_of(pass(), pass()))
    #-> pass()

    r(with_elements(pass()))
    #-> pass()

    r(with_elements(chain_of(pass(), pass())))
    #-> pass()

    r(chain_of(A(), B(), C(), filler("A")))
    #-> filler("A")

## Wrap Pushdown Cases

In this next pipeline, we can see how the 1st `wrap()` is pushed down
and cancels a `flatten()`.

    p = chain_of(
         with_column(1, A()),
         with_column(1, with_elements(wrap())),
         distribute(1),
         with_elements(with_column(1, with_elements(B()))),
         with_elements(with_column(1, flatten())),
         with_elements(with_column(1, C())))

    r(p)
    #=>
    chain_of(with_column(1, A()),
             distribute(1),
             with_elements(with_column(1, chain_of(B(), C()))))
    =#

With a simple query we can have a farily complex tree.

    q = assemble(convert(DataKnot,10), @query keep(x => 0.5).(it * x))


