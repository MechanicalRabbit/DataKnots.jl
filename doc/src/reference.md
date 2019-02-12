# Reference

DataKnots are a Julia library for building data processing
pipelines. In this library, each `Pipeline` represents a data
transformation and a specific input/output is a `DataKnot`.
With the exception of a few overloaded base functions such as
`run`, `get`, the bulk of this reference focuses on pipeline
constructors.

To exercise our reference examples, we import the package:

    using DataKnots

## DataKnots & Running Pipelines

A `DataKnot` is a column-oriented data store supporting
hierarchical and self-referential data. The top-level entry in
each `DataKnot` is a single data block, which can be plural or
singular, optional or mandatory. 

### Constructing and Extracting a DataKnot

The constructor, `DataKnot()`, takes a native Julia object,
typically a scalar value or an array. The `get()` function can be
used to retrieve the DataKnot's native Julia value. When passed a
scalar Julia value, such as a `String`, the DataKnot is singular.

    knot = DataKnot("Hello World")
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

    get(knot)
    #=>
    "Hello World"
    =#

When passed an array, the result is plural.

    knot = DataKnot(["Hello", "World"])
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │ Hello    │
    2 │ World    │
    =#

    get(knot)
    #=>
    ["Hello", "World"]
    =#

This conversion into plural knots only works on top-level arrays,
nested arrays are treated as native values. DataKnots don't know
about multi-dimensional arrays, tables or other structures. In
this way, conversion to/from a DataKnot preserves structure.

    knot = DataKnot([[1, 2], [3, 4]])
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │ [1, 2]   │
    2 │ [3, 4]   │
    =#

    get(knot)
    #=>
    Array{Int,1}[[1, 2], [3, 4]]
    =#

For DataKnots, `show` provides a convenient display. This display
has special treatment when a value is a `NamedTuple`. Even so,
the value is still a scalar.

    knot = DataKnot((name = "GARRY M", salary = 260004))
    #=>
    │ DataKnot        │
    │ name     salary │
    ├─────────────────┤
    │ GARRY M  260004 │
    =#

    get(knot)
    #=>
    (name = "GARRY M", salary = 260004)
    =#

This treatment of `NamedTuple` permits convenient representation
and display of arrays of tuples. While shown as a table, the value
retrieved by `get` round-trips as an array of named tuples.

    DataKnot([(name = "GARRY M", salary = 260004),
              (name = "ANTHONY R", salary = 185364),
              (name = "DANA A", salary = 170112)])
    #=>
      │ DataKnot          │
      │ name       salary │
    ──┼───────────────────┤
    1 │ GARRY M    260004 │
    2 │ ANTHONY R  185364 │
    3 │ DANA A     170112 │
    =#

The Implementation Guide provides for lower level details as to
the internal representation of a `DataKnot` and ways they could be
constructed by other means.

### Running Pipelines & Parameters

Once a DataKnot is constructed, it could be executed against a
pipeline using `run()` to produce an output. Since every
`DataKnot` is a primitive pipeline that reproduces itself, we
could write:

    run(DataKnot("Hello World"))
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

The `run()` function has a two argument form where the 1st
argument is a `DataKnot` and the 2nd argument is a `Pipeline`
expression. Since `It` is the identity pipeline that reproduces
its input, we can also write:

    run(DataKnot("Hello World"), It)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

Named arguments to `run()` become additional fields that are
accessible via `It`. Those arguments are converted into a
`DataKnot` if they are not already.

    run(It.hello, hello=DataKnot("Hello World"))
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

    run(It.hello, hello="Hello World")
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

Once a pipeline is `run()` the resulting `DataKnot` value can be
retrieved via `get()`.

    get(run(DataKnot(1) .+ 1))
    #=> 2 =#

## Constructing Pipelines


...
