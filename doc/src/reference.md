# Reference

DataKnots are a Julia library for building data processing
pipelines. In this library, each `Pipeline` represents a data
transformation; a specific input/output is a `DataKnot`.
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

### Working with DataKnots

The constructor `DataKnot()` takes a native Julia object,
typically a vector or scalar value. The `get()` function can be
used to retrieve the DataKnot's native Julia value. Like most
libraries, `show()` will produce a suitable display.

#### `DataKnots.DataKnot`

```julia
    DataKnot(elts::AbstractVector)
```

In the common case, a `DataKnot` can be constructed from any
`AbstractVector` to produce a *plural* `DataKnot`.

```julia
    DataKnot(elt::T) where {T}
```

The general case accepts any Julia value to produce a *singular*
`DataKnot`. Plural DataKnots are shown with an index, while
singular knots are shown without an index.

    DataKnot("GARRY M")
    #=>
    │ DataKnot │
    ├──────────┤
    │ GARRY M  │
    =#

    DataKnot(["GARRY M", "ANTHONY R", "DANA A"])
    #=>
      │ DataKnot  │
    ──┼───────────┤
    1 │ GARRY M   │
    2 │ ANTHONY R │
    3 │ DANA A    │
    =#

Only the top-most vector is treated as a plural sequence. Nested
vectors are not treated specially.

    DataKnot([[260004, 185364], [170112]])
    #=>
      │ DataKnot         │
    ──┼──────────────────┤
    1 │ [260004, 185364] │
    2 │ [170112]         │
    =#

#### `show`

```julia
    show(data::DataKnot)
```

Besides displaying plural and singular knots differently, the
`show` method has special treatment for `Tuple` and `NamedTuple`.

    DataKnot((name = "GARRY M", salary = 260004))
    #=>
    │ DataKnot        │
    │ name     salary │
    ├─────────────────┤
    │ GARRY M  260004 │
    =#

This permits a vector-of-tuples to be displayed as tabular data.

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

#### `get`

```julia
    get(data::DataKnot)
```

A DataKnot can be converted into native Julia values using `get`.
Plural knots return a top-level vector.

    get(DataKnot("GARRY M"))
    #=>
    "GARRY M"
    =#
  
    get(DataKnot(["GARRY M", "ANTHONY R", "DANA A"]))
    #=>
    ["GARRY M", "ANTHONY R", "DANA A"]
    =#

Nested vectors and other data, such as a `TupleVector`, round-trip
though the conversion to a `DataKnot` and back using `get`.

    get(DataKnot([[260004, 185364], [170112]]))
    #=>
    Array{Int,1}[[260004, 185364], [170112]]
    =#

    get(DataKnot((name = "GARRY M", salary = 260004)))
    #=>
    (name = "GARRY M", salary = 260004)
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
