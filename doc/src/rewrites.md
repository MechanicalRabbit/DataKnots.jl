# DataKnots' Query Rewrites

This is a regression test for the query rewrite system.

    using DataKnots:
        @VectorTree,
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
    p = null_filler()

## Simplify

There are lots of combinations with `pass` and other constructs that end
up being equivalent to `pass`.

    r(with_elements(pass()))
    #-> pass()

    [r(with_column(x, pass())) for x in [0, 3]]
    #-> DataKnots.Pipeline[pass(), pass()]
   
    [r(chain_of(x)) for x in (pass(), with_elements(pass()))]
    #-> DataKnots.Pipeline[pass(), pass()]

    r(chain_of(with_column(3, chain_of(with_elements(pass()), pass()))))
    #-> pass()

A chain that ends with a filler can ignore previous entries.

    r(chain_of(p, null_filler()))
    #-> null_filler()

    r(chain_of(p, filler("x")))
    #-> filler("x")
    
    r(chain_of(p, block_filler([], x0toN)))
    #-> block_filler([], x0toN)

    r(chain_of(filler("X"), filler("Y"), filler("Z")))
    #-> filler("Z")

A `tuple_of` constructed followed by a `column` can be simplified to
just the column that was chosen.

    r(chain_of(tuple_of(filler("A"), pass()), column(1)))
    #-> filler("A")

Chained operations can be distributed over tuples.

    r(chain_of(tuple_of(filler("A")), with_column(1, lift(lowercase))))
    #-> tuple_of(chain_of(filler("A"), lift(lowercase)))

In all cases, `flatten()` will undo a `wrap`.  

    r(chain_of(wrap(), flatten())
    #-> pass()

    r(chain_of(wrap(), with_elements(filler("A"))))
    #-> chain_of(filler("A"), wrap())

Since `wrap()` preserves values according to elementwise access, it can
be optimized if subsequent operations, such as `lift()`, only accesses
its input elementwise.

    r(chain_of(wrap(), lift(uppercase)))
    #-> lift(uppercase)

    r(chain_of(tuple_of(wrap(), filler(2)), tuple_lift(+)))
    #->chain_of(tuple_of(pass(), filler(2)), tuple_lift(+))

    r(chain_of(tuple_of(chain_of(filler(1), wrap()), filler(2)), tuple_lift(+)))
    #-> chain_of(tuple_of(filler(1), filler(2)), tuple_lift(+))
