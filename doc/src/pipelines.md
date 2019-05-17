# Pipeline Algebra

This section describes the `Pipeline` interface of vectorized data
transformations.  We will use the following definitions:

    using DataKnots:
        @VectorTree,
        Pipeline,
        Runtime,
        adapt_missing,
        adapt_tuple,
        adapt_vector,
        block_any,
        block_cardinality,
        block_filler,
        block_length,
        block_lift,
        block_not_empty,
        chain_of,
        column,
        distribute,
        distribute_all,
        filler,
        flatten,
        get_by,
        group_by,
        lift,
        null_filler,
        pass,
        sieve_by,
        slice_by,
        tuple_lift,
        tuple_of,
        unique_by,
        with_column,
        with_elements,
        wrap,
        x0toN,
        x1to1,
        x1toN

## Lifting and Fillers

`DataKnots` stores structured data in a column-oriented format, serialized
using specialized composite vector types.  Consequently, operations on data
must also be adapted to the column-oriented format.

In `DataKnots`, operations on column-oriented data are called *pipelines*.  A
pipeline is a vectorized transformation: it takes a vector of input values and
produces a vector of the same size containing output values.

Any unary scalar function could be vectorized, which gives us a simple method
for creating new pipelines.  Consider, for example, function `titlecase()`,
which transforms the input string by capitalizing the first letter of each word
and converting every other character to lowercase.

    titlecase("JEFFERY A")      #-> "Jeffery A"

This function can be converted to a pipeline or *lifted*, using the `lift`
pipeline constructor.

    p = lift(titlecase)
    p(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["Jeffery A", "James A", "Terry A"]

A scalar function with `N` arguments could be lifted by `tuple_lift` to make a
pipeline that transforms a `TupleVector` with `N` columns.  For example, a
binary predicate `>` gives rise to a pipeline `tuple_lift(>)` that transforms a
`TupleVector` with two columns into a Boolean vector.

    p = tuple_lift(>)
    p(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])
    #-> Bool[1, 0, 0]

In a similar manner, a function with a vector argument can be lifted by
`block_lift` to make a pipeline that expects a `BlockVector` input.  For
example, function `length()`, which returns the length of a vector, could be
converted to a pipeline `block_lift(length)` that transforms a block vector to
an integer vector containing block lengths.

    p = block_lift(length)
    p(@VectorTree [String] [["JEFFERY A", "NANCY A"], ["JAMES A"]])
    #-> [2, 1]

Not just functions, but also regular values could give rise to pipelines.  The
`filler` constructor makes a pipeline from any scalar value.  This pipeline
maps any input vector to a vector filled with the given scalar.

    p = filler(200000)
    p(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> [200000, 200000, 200000]

Similarly, `block_filler` makes a pipeline from any vector value.  This
pipeline produces a `BlockVector` filled with the given vector.

    p = block_filler(["POLICE", "FIRE"])
    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree (0:N) × String [["POLICE", "FIRE"], ["POLICE", "FIRE"], ["POLICE", "FIRE"]]

A variant of `block_filler` called `null_filler` makes a pipeline that produces
a `BlockVector` filled with empty blocks.

    p = null_filler()
    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree (0:1) × Bottom [missing, missing, missing]

## Chaining Pipelines

Given a series of pipelines, the `chain_of` constructor creates their
*composition* pipeline, which transforms the input vector by sequentially
applying the given pipelines.

    p = chain_of(lift(split), lift(first), lift(titlecase))
    p(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["Jeffery", "James", "Terry"]

The degenerate composition of an empty sequence of pipelines has its own name,
`pass()`. It passes its input to the output unchanged.

    chain_of()
    #-> pass()

    p = pass()
    p(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["JEFFERY A", "JAMES A", "TERRY A"]

In general, pipeline constructors that take one or more pipelines as arguments
are called pipeline *combinators*.  Combinators are used to assemble elementary
pipelines into complex pipeline expressions.

## Composite Vectors

In `DataKnots`, composite data is represented as a tree of vectors with regular
`Vector` objects at the leaves and composite vectors, such as `TupleVector` and
`BlockVector`, at the intermediate nodes. Pipelines that operate and rearrange
this tree are described here.

The `tuple_of` pipeline combinator permits us to construct a `TupleVector`.
`TupleVector` is a vector of tuples composed of a sequence of column vectors.
Any collection of vectors could be used as columns as long as they all have the
same length.  One way to obtain *N* columns for a `TupleVector` is to apply *N*
pipelines to the same input vector.

    p = tuple_of(:first => chain_of(lift(split), lift(first), lift(titlecase)),
                 :last => lift(last))
    p(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> @VectorTree (first = String, last = Char) [(first = "Jeffery", last = 'A') … ]

In the opposite direction, the `column` constructor makes a pipeline that
extracts the specified column from the input `TupleVector`.

    p = column(:salary)
    p(@VectorTree (name=String, salary=Int) [("JEFFERY A", 101442), ("JAMES A", 103350), ("TERRY A", 93354)])
    #-> [101442, 103350, 93354]

The `wrap()` pipeline primitive is used to create a `BlockVector`.
`BlockVector` is a vector of vectors serialized as a partitioned vector of
elements.  Any input vector could be transformed to a `BlockVector` by
partitioning its elements into one-element blocks.

    p = wrap()
    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree (1:1) × String ["GARRY M", "ANTHONY R", "DANA A"]

Dual to `wrap()` is the pipeline `flatten()`, which transforms a nested
`BlockVector` by flattening its nested blocks.

    p = flatten()
    p(@VectorTree [[String]] [[["GARRY M"], ["ANTHONY R", "DANA A"]], [[], ["JOSE S"], ["CHARLES S"]]])
    #-> @VectorTree (0:N) × String [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]]

The `distribute` constructor makes a pipeline that rearranges a `TupleVector`
with a `BlockVector` column. This operation exchanges their positions, pushing
tuples down and pulling blocks up. Specifically, it takes each tuple, where a
specific field must contain a block value, and transforms it to a block of
tuples by distributing the block value over the tuple.

    p = distribute(:employee)
    p(@VectorTree (department = String, employee = [String]) [
        "POLICE"    ["GARRY M", "ANTHONY R", "DANA A"]
        "FIRE"      ["JOSE S", "CHARLES S"]]) |> display
    #=>
    @VectorTree of 2 × (0:N) × (department = String, employee = String):
     [(department = "POLICE", employee = "GARRY M"), (department = "POLICE", employee = "ANTHONY R"), (department = "POLICE", employee = "DANA A")]
     [(department = "FIRE", employee = "JOSE S"), (department = "FIRE", employee = "CHARLES S")]
    =#

Often we need to transform only a part of a composite vector, leaving the rest
of the structure intact.  This can be achieved using `with_column` and
`with_elements` combinators.  Specifically, `with_column` transforms a specific
column of a `TupleVector` while `with_elements` transforms the vector of
elements of a `BlockVector`.

    p = with_column(:employee, with_elements(lift(titlecase)))
    p(@VectorTree (department = String, employee = [String]) [
        "POLICE"    ["GARRY M", "ANTHONY R", "DANA A"]
        "FIRE"      ["JOSE S", "CHARLES S"]]) |> display
    #=>
    @VectorTree of 2 × (department = String, employee = (0:N) × String):
     (department = "POLICE", employee = ["Garry M", "Anthony R", "Dana A"])
     (department = "FIRE", employee = ["Jose S", "Charles S"])
    =#

## Specialized Pipelines

Not every data transformation can be implemented with lifting.  `DataKnots`
provide pipeline constructors for some common transformation tasks.

For example, data filtering is implemented with the pipeline `sieve_by()`.  As
input, it expects a `TupleVector` of pairs containing a value and a `Bool`
flag.  `sieve_by()` transforms the input to a `BlockVector` containing 0- and
1-element blocks.  When the flag is `false`, it is mapped to an empty block,
otherwise, it is mapped to a one-element block containing the data value.

    p = sieve_by()
    p(@VectorTree (String, Bool) [("JEFFERY A", true), ("JAMES A", true), ("TERRY A", false)])
    #-> @VectorTree (0:1) × String ["JEFFERY A", "JAMES A", missing]

If `DataKnots` does not provide a specific transformation, it is easy to create
a new one.  For example, let us create a pipeline constructor `double` which
makes a pipeline that doubles the elements of the input vector.

We need to provide two definitions: to create a `Pipeline` object and to
perform the tranformation on the given input vector.

    double() = Pipeline(double)
    double(::Runtime, input::AbstractVector{<:Number}) = input .* 2

    p = double()
    p([260004, 185364, 170112])
    #-> [520008, 370728, 340224]

It is also easy to create new pipeline combinators.  Let us create a combinator
`twice`, which applies the given pipeline to the input two times.

    twice(p) = Pipeline(twice, p)
    twice(rt::Runtime, input, p) = p(rt, p(rt, input))

    p = twice(double())
    p([260004, 185364, 170112])
    #-> [1040016, 741456, 680448]


## API Reference

```@autodocs
Modules = [DataKnots]
Pages = ["pipelines.jl"]
Public = false
```

## Test Suite

### Lifting

The `lift` constructor makes a pipeline by vectorizing a unary function.

    p = lift(titlecase)
    #-> lift(titlecase)

    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> ["Garry M", "Anthony R", "Dana A"]

The `block_lift` constructor makes a pipeline on block vectors by vectorizing a
unary vector function.

    p = block_lift(length)
    #-> block_lift(length)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]])
    #-> [3, 2]

Some vector functions may expect a non-empty vector as an argument.  In this
case, we should provide the value to replace empty blocks.

    p = block_lift(maximum, missing)
    #-> block_lift(maximum, missing)

    p(@VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]])
    #-> Union{Missing, Int64}[260004, missing, 202728]

The `tuple_lift` constructor makes a pipeline on tuple vectors by vectorizing a
function of several arguments.

    p = tuple_lift(>)
    #-> tuple_lift(>)

    p(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])
    #-> Bool[1, 0, 0]


### Fillers

The pipeline `filler(val)` ignores its input and produces a vector filled with
`val`.

    p = filler(200000)
    #-> filler(200000)

    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> [200000, 200000, 200000]

The pipeline `block_filler(blk, card)` produces a block vector filled with the
given block.

    p = block_filler(["POLICE", "FIRE"], x1toN)
    #-> block_filler(["POLICE", "FIRE"], x1toN)

    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree (1:N) × String [["POLICE", "FIRE"], ["POLICE", "FIRE"], ["POLICE", "FIRE"]]

The pipeline `null_filler()` produces a block vector with empty blocks.

    p = null_filler()
    #-> null_filler()

    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree (0:1) × Bottom [missing, missing, missing]


### Adapting row-oriented data

The pipeline `adapt_missing()` transforms a vector containing `missing` values
to a block vector with `missing` replaced by an empty block and other values
wrapped in 1-element block.

    p = adapt_missing()
    #-> adapt_missing()

    p([260004, 185364, 170112, missing, 202728, 197736])
    #-> @VectorTree (0:1) × Int64 [260004, 185364, 170112, missing, 202728, 197736]

The pipeline `adapt_vector()` transforms a vector of vectors to a block vector.

    p = adapt_vector()
    #-> adapt_vector()

    p([[260004, 185364, 170112], Int[], [202728, 197736]])
    #-> @VectorTree (0:N) × Int64 [[260004, 185364, 170112], [], [202728, 197736]]

The pipeline `adapt_tuple()` transforms a vector of tuples to a tuple vector.

    p = adapt_tuple()
    #-> adapt_tuple()

    p([("GARRY M", 260004), ("ANTHONY R", 185364), ("DANA A", 170112)]) |> display
    #=>
    @VectorTree of 3 × (String, Int64):
     ("GARRY M", 260004)
     ("ANTHONY R", 185364)
     ("DANA A", 170112)
    =#

Vectors of named tuples are also supported.

    p([(name="GARRY M", salary=260004), (name="ANTHONY R", salary=185364), (name="DANA A", salary=170112)]) |> display
    #=>
    @VectorTree of 3 × (name = String, salary = Int64):
     (name = "GARRY M", salary = 260004)
     (name = "ANTHONY R", salary = 185364)
     (name = "DANA A", salary = 170112)
    =#


### Composition

The `chain_of` combinator composes a sequence of pipelines.

    p = chain_of(lift(split), lift(first), lift(titlecase))
    #-> chain_of(lift(split), lift(first), lift(titlecase))

    p(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["Jeffery", "James", "Terry"]

The empty chain `chain_of()` has an alias `pass()`.

    p = pass()
    #-> pass()

    p(["GARRY M", "ANTHONY R", "DANA A"])
    #-> ["GARRY M", "ANTHONY R", "DANA A"]


### Tuple vectors

The pipeline `tuple_of(p₁, p₂ … pₙ)` produces a tuple vector, whose columns are
generated by applying `p₁`, `p₂` … `pₙ` to the input vector.

    p = tuple_of(:title => lift(titlecase), :last => lift(last))
    #-> tuple_of(:title => lift(titlecase), :last => lift(last))

    p(["GARRY M", "ANTHONY R", "DANA A"]) |> display
    #=>
    @VectorTree of 3 × (title = String, last = Char):
     (title = "Garry M", last = 'M')
     (title = "Anthony R", last = 'R')
     (title = "Dana A", last = 'A')
    =#

The pipeline `column(lbl)` extracts the specified column from a tuple vector.  The
`column` constructor accepts either the column position or the column label.

    p = column(1)
    #-> column(1)

    p(@VectorTree (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112])
    #-> ["GARRY M", "ANTHONY R", "DANA A"]

    p = column(:salary)
    #-> column(:salary)

    p(@VectorTree (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112])
    #-> [260004, 185364, 170112]

The `with_column` combinator lets us apply the given pipeline to a selected
column of a tuple vector.

    p = with_column(:name, lift(titlecase))
    #-> with_column(:name, lift(titlecase))

    p(@VectorTree (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]) |> display
    #=>
    @VectorTree of 3 × (name = String, salary = Int64):
     (name = "Garry M", salary = 260004)
     (name = "Anthony R", salary = 185364)
     (name = "Dana A", salary = 170112)
    =#


### Block vectors

The pipeline `wrap()` wraps the elements of the input vector to one-element
blocks.

    p = wrap()
    #-> wrap()

    p(["GARRY M", "ANTHONY R", "DANA A"])
    @VectorTree (1:1) × String ["GARRY M", "ANTHONY R", "DANA A"]

The pipeline `flatten()` flattens a nested block vector.

    p = flatten()
    #-> flatten()

    p(@VectorTree [[String]] [[["GARRY M"], ["ANTHONY R", "DANA A"]], [missing, ["JOSE S"], ["CHARLES S"]]])
    @VectorTree (0:N) × String [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]]

The `with_elements` combinator lets us apply the given pipeline to transform
the elements of a block vector.

    p = with_elements(lift(titlecase))
    #-> with_elements(lift(titlecase))

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]])
    @VectorTree (0:N) × String [["Garry M", "Anthony R", "Dana A"], ["Jose S", "Charles S"]]

The pipeline `distribute(lbl)` transforms a tuple vector with a certain block
column to a block vector of tuples by distributing the block elements over the
tuple.

    p = distribute(1)
    #-> distribute(1)

    p(@VectorTree ([Int], [Int]) [
        [260004, 185364, 170112]    200000
        missing                     200000
        [202728, 197736]            [200000, 200000]]
    ) |> display
    #=>
    @VectorTree of 3 × (0:N) × (Int64, (0:N) × Int64):
     [(260004, [200000]), (185364, [200000]), (170112, [200000])]
     []
     [(202728, [200000, 200000]), (197736, [200000, 200000])]
    =#

The pipeline `distribute_all()` takes a tuple vector with block columns and
distribute all of the block columns.

    p = distribute_all()
    #-> distribute_all()

    p(@VectorTree ([Int], [Int]) [
        [260004, 185364, 170112]    200000
        missing                     200000
        [202728, 197736]            [200000, 200000]]
    ) |> display
    #=>
    @VectorTree of 3 × (0:N) × (Int64, Int64):
     [(260004, 200000), (185364, 200000), (170112, 200000)]
     []
     [(202728, 200000), (202728, 200000), (197736, 200000), (197736, 200000)]
    =#

This pipeline is equivalent to
`chain_of(distribute(1), with_elements(distribute(2)), flatten())`.

The pipeline `block_length()` calculates the lengths of blocks in a block vector.

    p = block_length()
    #-> block_length()

    p(@VectorTree [String] [missing, "GARRY M", ["ANTHONY R", "DANA A"]])
    #-> [0, 1, 2]

The pipeline `block_not_empty()` produces a vector of Boolean values indicating
whether the input block is empty or not.

    p = block_not_empty()
    #-> block_not_empty()

    p(@VectorTree [String] [missing, "GARRY M", ["ANTHONY R", "DANA A"]])
    #-> Bool[0, 1, 1]

The pipeline `block_any()` checks whether the blocks in a `Bool` block vector
have any `true` values.

    p = block_any()
    #-> block_any()

    p(@VectorTree [Bool] [missing, true, false, [true, false], [false, false], [false, true]])
    #-> Bool[0, 1, 0, 1, 0, 1]

The pipeline `block_cardinality()` asserts the cardinality of a block vector.

    p = block_cardinality(x1to1, :employee, :name)
    #-> block_cardinality(x1to1, :employee, :name)

    p(@VectorTree [String] [["GARRY M"], ["ANTHONY R"], ["DANA A"]])
    #-> @VectorTree (1:1) × String ["GARRY M", "ANTHONY R", "DANA A"]

    p(@VectorTree [String] [["GARRY M"], ["ANTHONY R", "DANA A"]])
    #-> ERROR: "name": expected a singular value, relative to "employee"

    p(@VectorTree [String] [["GARRY M"], [], ["DANA A"]])
    #-> ERROR: "name": expected a mandatory value, relative to "employee"

The source and/or target labels could be omitted.

    p = block_cardinality(x1to1, :employee, nothing)

    p(@VectorTree [String] [[]])
    #-> ERROR: expected a mandatory value, relative to "employee"

    p = block_cardinality(x1to1, nothing, :name)

    p(@VectorTree [String] [[]])
    #-> ERROR: "name": expected a mandatory value

    p = block_cardinality(x1to1, nothing, nothing)

    p(@VectorTree [String] [[]])
    #-> ERROR: expected a mandatory value

The `block_cardinality()` pipeline could also be used to widen the cardinality
constraint.

    p = block_cardinality(x0toN)
    #-> block_cardinality(x0toN)

    p(@VectorTree [String] [["GARRY M"], ["ANTHONY R"], ["DANA A"]])
    #-> @VectorTree (0:N) × String [["GARRY M"], ["ANTHONY R"], ["DANA A"]]

    p(@VectorTree (1:1)String ["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree (0:N) × String [["GARRY M"], ["ANTHONY R"], ["DANA A"]]


### Filtering

The pipeline `sieve_by()` filters a vector of pairs by the second column.

    p = sieve_by()
    #-> sieve_by()

    p(@VectorTree (Int, Bool) [260004 true; 185364 false; 170112 false])
    #-> @VectorTree (0:1) × Int64 [260004, missing, missing]


### Indexing

The pipeline `get_by(N)` transforms a block vector by extracting the `N`-th
element of each block.

    p = get_by(2)
    #-> get_by(2)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree (0:1) × String ["ANTHONY R", "CHARLES S", missing]

The pipeline `get_by(-N)` takes the `N`-th element from the end.

    p = get_by(-1)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree (0:1) × String ["DANA A", "CHARLES S", missing]

It is possible to explicitly specify the cardinality of the output.

    p = get_by(1, x1to1)
    #-> get_by(1, x1to1)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]])
    #-> @VectorTree (1:1) × String ["GARRY M", "JOSE S"]

    p = get_by(-1, x1to1)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]])
    #-> @VectorTree (1:1) × String ["DANA A", "CHARLES S"]

A variant of this pipeline `get_by()` expects a tuple vector with two columns:
the first column containing the blocks and the second column with the indexes.

    p = get_by()
    #-> get_by()

    p(@VectorTree ([String], Int) [(["GARRY M", "ANTHONY R", "DANA A"], 1), (["JOSE S", "CHARLES S"], -1), (missing, 0)])
    #-> @VectorTree (0:1) × String ["GARRY M", "CHARLES S", missing]

    p(@VectorTree ([String], Int) [(["GARRY M", "ANTHONY R", "DANA A"], 1), (["JOSE S", "CHARLES S"], -1)])
    #-> @VectorTree (0:1) × String ["GARRY M", "CHARLES S"]


### Slicing

The pipeline `slice_by(N)` transforms a block vector by keeping the first `N`
elements of each block.

    p = slice_by(2)
    #-> slice_by(2, false)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree (0:N) × String [["GARRY M", "ANTHONY R"], ["JOSE S", "CHARLES S"], []]

When `N` is negative, `slice_by(N)` drops the last `-N` elements of each block.

    p = slice_by(-1)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree (0:N) × String [["GARRY M", "ANTHONY R"], ["JOSE S"], []]

The pipeline `slice_by(N, true)` drops the first `N` elements (or keeps the
last `-N` elements if `N` is negative).

    p = slice_by(2, true)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree (0:N) × String [["DANA A"], [], []]

    p = slice_by(-1, true)

    p(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree (0:N) × String [["DANA A"], ["CHARLES S"], []]

A variant of this pipeline `slice_by()` expects a tuple vector with two
columns: the first column containing the blocks and the second column with the
number of elements to keep.

    p = slice_by()
    #-> slice_by(false)

    p(@VectorTree ([String], Int) [(["GARRY M", "ANTHONY R", "DANA A"], 1), (["JOSE S", "CHARLES S"], -1), (missing, 0)])
    #-> @VectorTree (0:N) × String [["GARRY M"], ["JOSE S"], []]


### Grouping

The pipeline `unique_by()` transforms a block vector by keeping one copy of
each distinct value in each block.

    p = unique_by()
    #-> unique_by()

    p(@VectorTree [String] [["FIRE", "POLICE", "POLICE", "FIRE"], ["FIRE", "OEMC", "OEMC"], []])
    #-> @VectorTree (0:N) × String [["FIRE", "POLICE"], ["FIRE", "OEMC"], []]

Compositve values are also supported.

    p(@VectorTree [(0:1)String] [["POLICE", "FIRE", missing, "OEMC", "POLICE", missing]])
    #-> @VectorTree (0:N) × ((0:1) × String) [[missing, "FIRE", "OEMC", "POLICE"]]

The pipeline `group_by()` expects a block vector of pairs two columns values
and keys.  The values are further partitioned into blocks by grouping the
values with equal keys.

    p = group_by()
    #-> group_by()

    p(@VectorTree [(String, String)] [[("DANIEL A", "FIRE"), ("JEFFERY A", "POLICE"), ("JAMES A", "FIRE"), ("NANCY A", "POLICE")]])
    #-> @VectorTree (0:N) × ((1:N) × String, String) [[(["DANIEL A", "JAMES A"], "FIRE"), (["JEFFERY A", "NANCY A"], "POLICE")]]

The keys could be assembled from tuples and blocks.

    p(@VectorTree [(String, (0:1)((0:1)Int, (0:1)Int))] [[("JEFFERY A", (10, missing)), ("NANCY A", (8, missing))], [("JAMES A", (10, missing)), ("DANIEL A", (10, missing))], [("LAKENYA A", (missing, 2)), ("DORIS A", (missing, 2)), ("ASKEW A", (6, missing)), ("MARY Z", missing)], []])
    #-> @VectorTree (0:N) × ((1:N) × String, (0:1) × ((0:1) × Int64, (0:1) × Int64)) [[(["NANCY A"], (8, missing)), (["JEFFERY A"], (10, missing))], [(["JAMES A", "DANIEL A"], (10, missing))], [(["MARY Z"], missing), (["LAKENYA A", "DORIS A"], (missing, 2)), (["ASKEW A"], (6, missing))], []]

Plural blocks could also serve as keys.

    p(@VectorTree [(String, [String])] [[("ANTONIO", ["POLICE", "OEMC"]), ("DOLORES", ["FINANCE"]), ("MARY", ["FINANCE"]), ("CRYSTAL", ["POLICE", "OEMC"]), ("PIA", ["POLICE"]), ("CALVIN", [])]])
    #-> @VectorTree (0:N) × ((1:N) × String, (0:N) × String) [[(["CALVIN"], []), (["DOLORES", "MARY"], ["FINANCE"]), (["PIA"], ["POLICE"]), (["ANTONIO", "CRYSTAL"], ["POLICE", "OEMC"])]]

