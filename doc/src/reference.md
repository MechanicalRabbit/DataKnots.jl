# Reference

DataKnots are a Julia library for building data processing
pipelines. In this library, each `Pipeline` represents a data
transformation; a specific input/output is a `DataKnot`. With the
exception of a few overloaded base functions such as `run`, `get`,
the bulk of this reference focuses on pipeline constructors.

To exercise our reference examples, we import the package:

    using DataKnots

## DataKnots & Running Pipelines

A `DataKnot` is a column-oriented data store supporting
hierarchical and self-referential data. A `DataKnot` is produced
when a `Pipeline` is `run`.

#### `DataKnots.Cardinality`

In DataKnots, the elementary unit is a collection of values, or
data *block*. Besides the Julia datatype for its values, an
additional property of each data block is its cardinality.

Cardinality is a constraint on the number of values in a block. A
block is called *mandatory* if it must contain at least one value;
*optional* otherwise. Similarly, a block is called *singular* if
it must contain at most one value; *plural* otherwise.

```julia
    REG::Cardinality = 0      # singular and mandatory
    OPT::Cardinality = 1      # optional, but singular
    PLU::Cardinality = 2      # plural, but mandatory
    OPT_PLU::Cardinality = 3  # optional and plural
```

To express the block cardinality constraint we use the `OPT`,
`PLU` and `REG` flags of the type DataKnots.Cardinality. The `OPT`
and `PLU` flags express relaxations of the mandatory and singular
constraint, respectively. A `REG` block which is both mandatory
and singular is called *regular* and it must contain exactly one
value. Conversely, a block with both `OPT|PLU` flags is
*unconstrained* and may have any number of elements.

If a block contains data of Julia type `T`, then an unconstrained
block of `T` would correspond to `Vector{T}` and an optional block
would correspond to `Union{Missing, T}`. A regular block can be
represented as a single Julia value of type `T`. There is no
direct representation for mandatory, plural blocks; however,
`Vector{T}` could be used with the convention that it always has
at least one element.

### Creating & Extracting DataKnots

The constructor `DataKnot()` takes a native Julia object,
typically a vector or scalar value. The `get()` function can be
used to retrieve the DataKnot's native Julia value. Like most
libraries, `show()` will produce a suitable display.

#### `DataKnots.DataKnot`

```julia
    DataKnot(elts::AbstractVector, card::Cardinality=OPT|PLU)
```

In the general case, a `DataKnot` can be constructed from an
`AbstractVector` to produce a `DataKnot` with a given cardinality.
By default, the `card` of the collection is unconstrained.

```julia
    DataKnot(elt, card::Cardinality=REG)
```

As a convenience, a non-vector constructor is also defined, it
marks the collection as being both singular and mandatory.

```julia
    DataKnot(::Missing, card::Cardinality=OPT)
```

Finally, there is an edge-case constructor for the creation
of an optional singular value that happens to be `Missing`.

    DataKnot(["GARRY M", "ANTHONY R", "DANA A"])
    #=>
      │ DataKnot  │
    ──┼───────────┤
    1 │ GARRY M   │
    2 │ ANTHONY R │
    3 │ DANA A    │
    =#

    DataKnot("GARRY M")
    #=>
    │ DataKnot │
    ├──────────┤
    │ GARRY M  │
    =#

    DataKnot(missing)
    #=>
    │ DataKnot │
    =#

Note that plural DataKnots are shown with an index, while singular
knots are shown without an index.

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
Regular values are returned as native Julia. Plural values are
returned as a vector.

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
the internal representation of a `DataKnot`. Other modules built
with this internal API may provide more convenient ways to
construct knots and get data.

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
