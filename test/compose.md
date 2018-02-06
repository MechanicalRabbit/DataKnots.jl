# `>>`

The symbol `>>` denotes the composition combinator, which lets you structure
the query as a processing pipeline.

    using QueryCombinators

    Q = (It .+ 4) >> (It .* 6)

    execute(Q, 3)
    #-> 42

