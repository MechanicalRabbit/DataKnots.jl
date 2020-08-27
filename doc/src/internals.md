# DataKnots' Internals

This document is a walk-though of the DataKnots' backend for those that
wish to help with implementation or write extensions. This document will
necessarily go into current implementation details that may change.

    using DataKnots: 
        @VectorTree,
        assemble,
        chain_of,
        flatten,
        unitknot,
        with_elements

## What is a DataKnot?

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
same as `col[idx1[idx2]]`. Hence, `tv[idx1][idx2]` goes from
`O(2*length(columns))` to `O(length(columns)+1)`.
