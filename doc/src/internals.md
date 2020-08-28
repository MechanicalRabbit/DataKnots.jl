# DataKnots' Internals Walk-Though

This document is a walk-though of the DataKnots' backend for those that
wish to better understand its operation or write extensions. It's meant
to complement existing internals documentation.

    using DataKnots:
        @VectorTree,
        assemble,
        chain_of,
        flatten,
        lift,
        block_lift,
        shape,
        signature,
        unitknot,
        with_elements

## DataKnots: In-Memory Storage

The input and output of a query are `DataKnot`s. The `convert` function
can be used to convert a Julia structure into a DataKnot.

    db = convert(DataKnot, "Hello World")
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

Internally, DataKnots have a shape (`shp`) and data (`cell`). The shape
of this dataknot is `ValueOf(String)`. The data is a vector with a
single string value, `"Hello World"`.

    dump(db)
    #=>
    DataKnot
      shp: DataKnots.ValueOf
        ty: String <: AbstractString
      cell: Array{String}((1,))
        1: String "Hello World"
    =#

Notably, the `cell` of a data knot is always a vector of length one.
This implementation choice is made because our internal representation
is column-oriented.

### Block Vector

Let's take a slightly more complex data source, a vector of two strings.
Internally, this is seen as nested vector `[["Hello", "World"]]`, since
the top-level vector always has length one.

    db = convert(DataKnot, ["Hello", "World"])
    #=>
    ──┼───────┼
    1 │ Hello │
    2 │ World │
    =#

This nested vector is stored in a `BlockVector`, which represents
multiple blocks of a single kind of value in a single column. The
storage of the elements are collected in a single array, `elts`.

    dump(db.cell)
    #=>
    DataKnots.BlockVector{DataKnots.x0toN,…}
      offs: Array{Int64}((2,)) [1, 3]
      elts: Array{String}((2,))
        1: String "Hello"
        2: String "World"
    =#

The other array, `offs` contains the offsets needed to partition `etls`
into blocks. The `length(offs)` is the number of blocks plus one. Each
indice gives the offset in `elts` where the subordinate vector starts,
with the subsequent indice telling where the next vector starts. Hence,
the first (and only) block can be extracted as follows.

    begin N=1; db.cell.elts[db.cell.offs[N]:db.cell.offs[N+1]-1] end
    #-> ["Hello", "World"]

The cardinality of a block vector, `x0toN` in the example above,
constrains how many values there are in each block. With `@VectorTree`,
we could create a block vector where each block has exactly one value.
Note that singular blocks are displayed without row numbers.

    knot = DataKnot(Any, @VectorTree (1:1)String [["Hello World"]])
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

The structure of this knot is almost identical to its cousin above, only
that it has a single block. The `offs` in this case are `[1,2]`,
represented using the efficient `OneTo(2)` generator.

    dump(knot.cell)
    #=>
    DataKnots.BlockVector{DataKnots.x1to1,…}
      offs: Base.OneTo{Int64}
        stop: Int64 2
      elts: Array{String}((1,))
        1: String "Hello World"
    =#

So that conversion of a native Julia data value to a DataKnot is
efficient, the original representation is initially kept. However, once
processed, the data is often be normalized to use `BlockVector`.

    knot = convert(DataKnot, "Hello World");

    dump(knot.cell)
    #=>
    Array{String}((1,))
      1: String "Hello World"
    =#

In the next example, we process this knot with the identity query, `It`,
which produces the equivalent `BlockVector`.

    dump(knot[It].cell)
    #=>
    DataKnots.BlockVector{DataKnots.x1to1,…}
      offs: Base.OneTo{Int64}
        stop: Int64 2
      elts: Array{String}((1,))
        1: String "Hello World"
    =#

We only obtain `BlockVector` structures with `BlockVector` elements
during processing. They are flattened during query processing.
Consequently, in our query model, we do not have a native representation
of nested arrays.

### Tuple Vector

A tuple vector is a vectorized representation of a set of tuples. We can
use `@TupleVector` to directly construct these.

    knot = DataKnot(Any, @VectorTree (x=String, y=Real) [("A", 3.0)])
    #=>
    │ x  y   │
    ┼────────┼
    │ A  3.0 │
    =#

A `TupleVector` has two primary attributes: `lbls`, which label the
columns; and `cols`, which hold values. In this particular example, each
of the columns has only one value.

    dump(knot.cell)
    #=>
    DataKnots.TupleVector{Base.OneTo{Int64}}
      lbls: Array{Symbol}((2,))
        1: Symbol x
        2: Symbol y
      idxs: Base.OneTo{Int64}
        stop: Int64 1
      cols: Array{AbstractArray{T,1} where T}((2,))
        1: Array{String}((1,))
          1: String "A"
        2: Array{Real}((1,)) Real[3.0]
    ⋮
    =#

It's possible for there to be more than one row stored in a
`TupleVector`. Note this example is a vector of vectors, `[[...]]``, the
top-level vector has length 1, and the subordinate vector has 3 tuples.


    knot = DataKnot(Any, @VectorTree (1:N)*(x=String, y=Real) [
                     [("A", 3.0), ("B", 5.0), ("C", 7.0)]])
    #=>
      │ x  y   │
    ──┼────────┼
    1 │ A  3.0 │
    2 │ B  5.0 │
    3 │ C  7.0 │
    =#

In this case, the `TupleVector` is wrapped in a `BlockVector`. The very
first block of the top-level vector contains the three rows from the
underlying `TupleVector` with offsets (`[1, 4]`). Notice that the `cols`
are parallel vectors that store the underlying column variables.

    dump(knot.cell)
    #=>
    DataKnots.BlockVector{DataKnots.x1toN,…}
      offs: Array{Int64}((2,)) [1, 4]
      elts: DataKnots.TupleVector{Base.OneTo{Int64}}
        lbls: Array{Symbol}((2,))
          1: Symbol x
          2: Symbol y
        idxs: Base.OneTo{Int64}
          stop: Int64 3
        cols: Array{AbstractArray{T,1} where T}((2,))
          1: Array{String}((3,))
            1: String "A"
            2: String "B"
            3: String "C"
          2: Array{Real}((3,)) Real[3.0, 5.0, 7.0]
    ⋮
    =#

The `idxs` field is an optimization, it is a simple remapping of the
vector's indexes to the indexes in the underlying column vectors. Here,
the `idxs` shows a 1-1 correspondence. Let's filter this knot.

    fknot=knot[Filter(It.x .!== "B")]
    #=>
      │ x  y   │
    ──┼────────┼
    1 │ A  3.0 │
    2 │ C  7.0 │
    =#

In this case, the outermost `BlockVector` is updated to reflect only two
entries (`[1, 3]`). Then, `idxs` of the inner `TupleVector` reflects the
mapping `1=>1, 2=>3`, leaving the underlying column vectors unchanged.

    dump(fknot.cell)
    #=>
    DataKnots.BlockVector{DataKnots.x0toN,…}
      offs: Array{Int64}((2,)) [1, 3]
      elts: DataKnots.TupleVector{Array{Int64,1}}
        lbls: Array{Symbol}((2,))
          1: Symbol x
          2: Symbol y
        idxs: Array{Int64}((2,)) [1, 3]
        cols: Array{AbstractArray{T,1} where T}((2,))
          1: Array{String}((3,))
            1: String "A"
            2: String "B"
            3: String "C"
          2: Array{Real}((3,)) Real[3.0, 5.0, 7.0]
    ⋮
    =#

There is another optimization attribute `icols`. This caches multiple
levels of reindexing. To see this in action, we could filter our result;
but don't yet access them. The `idxs` reflects the filter processing,
but the computation of the resulting column vectors is deferred.

    fknot=knot[Filter(It.x .!== "B")]
    dump(fknot.cell)
    #=>
    ⋮
        idxs: Array{Int64}((2,)) [1, 3]
    ⋮
        icols: Array{AbstractArray{T,1} where T}((2,))
          1: #undef
          2: #undef
    =#

By showing the knot, this calculation happens, and the reindexed columns
are cached in the `icols` attribute. This is useful for cases where only
some of the columns need to be reindexed.

    fknot
    #=>
      │ x  y   │
    ──┼────────┼
    1 │ A  3.0 │
    2 │ C  7.0 │
    =#

    dump(fknot.cell)
    #=>
    ⋮
        icols: Array{AbstractArray{T,1} where T}((2,))
          1: Array{String}((2,))
            1: String "A"
            2: String "C"
          2: Array{Real}((2,)) Real[3.0, 7.0]
    =#

This optimization speeds reindexing because `col[idx1][idx2]` is the
same as `col[idx1[idx2]]`, from 2\*number of columns to the number of
columns + 1 operations.

### Shape of a Knot

Each knot is also associated with a *shape* which defines the structure
of the knot. It's a parallel hierarchy to the data `cell`. There is
`BlockOf`, which represents blocks, `TupleOf`, which represents tuples,
and `ValueOf`, which represent a native Julia data type.

    knot = DataKnot(Any, @VectorTree (1:N)*(x=String, y=Real) [
                     [("A", 3.0), ("B", 5.0), ("C", 7.0)]])
    #=>
      │ x  y   │
    ──┼────────┼
    1 │ A  3.0 │
    2 │ B  5.0 │
    3 │ C  7.0 │
    =#

The shape of a knot is stored within it's `shp` attribute. The shape
reflects the hierarchical structure of the knot, including cardinality
for block vectors.

    knot.shp
    #-> BlockOf(TupleOf(:x => String, :y => Real), x1toN)

Note we can have a block of tuples, a tuple of blocks, we can have a
block of values, etc. Here is a more complicated example.

    knot = unitknot[Lift(1:3) >> Record(:x=>It, :stats =>
                                    Record(:x² => It.*It,
                                           :upto=> Lift(n->1:n, (It,))))]
    #=>
      │ x  stats{x²,upto} │
    ──┼───────────────────┼
    1 │ 1  1, [1]         │
    2 │ 2  4, [1; 2]      │
    3 │ 3  9, [1; 2; 3]   │
    =#

    knot.shp
    #=>
    BlockOf(TupleOf(:x => BlockOf(Int64, x1to1),
                    :stats => BlockOf(TupleOf(:x² => BlockOf(Int64, x1to1),
                                              :upto => BlockOf(Int64)),
                                      x1to1)))
    =#

## Pipelines: Data Transformations

Queries aren't directly executed on their input data, instead they are
assembled into a program, or pipeline, which operates on the input. To
see this, let's start with a trivial query, `It`, upon the `unitknot`.

    unitknot[It]
    #=>
    ┼──┼
    │  │
    =#

How does this work?  We can `assemble()` the query against the shape of
the input knot. This gives us the pipeline `pass()`, which simply
returns the input it was given.

    p = assemble(unitknot.shp, It)
    #-> pass()

By inspecting the pipeline's signature, we can see it takes a block
containing a single empty tuple, and produces a block containing a
single empty tuple.

    signature(p)
    #-> Signature(BlockOf(TupleOf(), x1to1), BlockOf(TupleOf(), x1to1))

Since the `unitknot` matches the pipeline's input shape, we can run the
pipeline using `p(unitknot)`. The `pass` pipeline simply reproduces the
`unitknot`, a block having exactly one tuple with zero columns.

    p(unitknot)
    #=>
    ┼──┼
    │  │
    =#

    shape(unitknot)
    #-> BlockOf(TupleOf(), x1to1)

In general, the output of any query is always a `BlockVector, even if it
is only a singleton. The choice of a `TupleVector` having zero columns
for our `unitknot` distinguishes it from Julia's `missing` or `nothing`.

### `wrap()`

The pipeline component, `wrap()`, takes a value and converts it into
data flow, represented as a singular `BlockVector`. First recall the
direct conversion of a string value into a `DataKnot`.

    knot = convert(DataKnot, "Hello World");

    dump(knot)
    #=>
    DataKnot
      shp: DataKnots.ValueOf
        ty: String <: AbstractString
      cell: Array{String}((1,))
        1: String "Hello World"
    =#

The shape of this knot is a `ValueOf(String)`.

    shape(knot)
    #-> ValueOf(String)

Any query, when applied to an input shape that is not a `BlockVector`,
first uses `wrap()` to convert the input to be a `BlockVector`. Hence,
for this particular case, `It` performs this conversion, and then does
nothing with it.

    p = assemble(knot.shp, It)
    #-> wrap()

    dump(p(knot))
    #=>
    DataKnot
      shp: DataKnots.BlockOf
        elts: DataKnots.ValueOf
          ty: String <: AbstractString
        card: DataKnots.Cardinality DataKnots.x1to1
      cell: DataKnots.BlockVector{DataKnots.x1to1,…}
        offs: Base.OneTo{Int64}
          stop: Int64 2
        elts: Array{String}((1,))
          1: String "Hello World"
    =#

Or, more succinctly, we could verify the shape changes to a block of
strings, where each block has exactly one element.

    shape(p(knot))
    #-> BlockOf(String, x1to1)

That said, once this is converted back to a row-oriented result using
`get()`, they both return a single string value.

    get(knot)
    #-> "Hello World"

    get(p(knot))
    #-> "Hello World"

Hence, from the perspective outside of `DataKnots` pipeline, these two
forms of the knot are for all intents and purposes identicial.

### `chain_of` and `with_elements`

A primary value of DataKnots is the automatic handling of plural values.
This bookkeeping is performed during the translation of queries into
pipelines. We've seen how `BlockVector` uses a vectorized format,
tracking its block cardinality. We've also seen how `wrap()` converts
single values into this vectorized form.

    knot = convert(DataKnot, "Hello World");

    assemble(knot.shp, It)
    #-> wrap()

To operate on elements of each block, e.g. *elementwise* operation, the
`with_elements()` pipeline component is used. Logically, you could think
of the `It` query as applying the pipeline identity, `pass()` to each
element of every block. We can see this with the unoptimized assembly.

    p = assemble(knot.shp, It, rewrite=nothing)
    #-> chain_of(wrap(), with_elements(pass()))

This pipeline operates sequentially via `chain_of()`. The first thing it
does is `wrap()` the singular result into a `BlockVector` as seen above.
The next pipeline component, `with_elements(pass())` applies the
identity pipeline to each element of the block.

    p(knot)
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

Of course, `with_elements(pass())` is effectively a noop, and then, a
`chain_of(wrap())` can be simplified to `wrap()`. Hence, after pipeline
rewrites are applied, we get the optimized form.

    p = assemble(knot.shp, It)
    #-> wrap()

The principle value of DataKnots' queries are working on block
vectors transparently. In our implementation, this is done with the
`with_elements` pipeline component.
