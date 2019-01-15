# Query Algebra


## Overview

This section describes the `Query` interface of vectorized data
transformations.  We will use the following definitions:

    using DataKnots:
        @VectorTree,
        OPT,
        PLU,
        REG,
        Query,
        Runtime,
        adapt_missing,
        adapt_tuple,
        adapt_vector,
        block_any,
        block_filler,
        block_length,
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
        record_lift,
        sieve,
        slice,
        tuple_lift,
        tuple_of,
        with_column,
        with_elements,
        wrap


### Lifting and fillers

`DataKnots` stores structured data in a column-oriented format, serialized
using specialized composite vector types.  Consequently, operations on data
must also be adapted to the column-oriented format.

In `DataKnots`, operations on column-oriented data are called *queries*.  A
query is a vectorized transformation: it takes a vector of input values and
produces a vector of the same size containing output values.

Any unary scalar function could be vectorized, which gives us a simple method
for creating new queries.  Consider, for example, function `titlecase()`, which
transforms the input string by capitalizing the first letter of each word and
converting every other character to lowercase.

    titlecase("JEFFERY A")      #-> "Jeffery A"

This function can be converted to a query, or *lifted*, using the `lift`
query constructor.

    q = lift(titlecase)
    q(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["Jeffery A", "James A", "Terry A"]

A scalar function with `N` arguments could be lifted by `tuple_lift` to make a
query that transforms a `TupleVector` with `N` columns.  For example, a binary
predicate `>` gives rise to a query `tuple_lift(>)` that transforms a
`TupleVector` with two columns into a Boolean vector.

    q = tuple_lift(>)
    q(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])
    #-> Bool[1, 0, 0]

In a similar manner, a function with a vector argument can be lifted by
`block_lift` to make a query that expects a `BlockVector` input.  For example,
function `length()`, which returns the length of a vector, could be converted
to a query `block_lift(length)` that transforms a block vector to an integer
vector containing block lengths.

    q = block_lift(length)
    q(@VectorTree [String] [["JEFFERY A", "NANCY A"], ["JAMES A"]])
    #-> [2, 1]

Not just functions, but also regular values could give rise to queries.  The
`filler` constructor makes a query from any scalar value.  This query maps any
input vector to a vector filled with the given scalar.

    q = filler(200000)
    q(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> [200000, 200000, 200000]

Similarly, `block_filler` makes a query from any vector value.  This query
produces a `BlockVector` filled with the given vector.

    q = block_filler(["POLICE", "FIRE"])
    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree [String] [["POLICE", "FIRE"], ["POLICE", "FIRE"], ["POLICE", "FIRE"]]

A variant of `block_filler` called `null_filler` makes a query that produces a
`BlockVector` filled with empty blocks.

    q = null_filler()
    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree [Union{}, OPT] [missing, missing, missing]


### Chaining queries

Given a series of queries, the `chain_of` constructor creates their
*composition* query, which transforms the input vector by sequentially applying
the given queries.

    q = chain_of(lift(split), lift(first), lift(titlecase))
    q(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["Jeffery", "James", "Terry"]

The degenerate composition of an empty sequence of queries has its own name,
`pass()`. It passes its input to the output unchanged.

    chain_of()
    #-> pass()

    q = pass()
    q(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["JEFFERY A", "JAMES A", "TERRY A"]

In general, query constructors that take one or more queries as arguments are
called query *combinators*.  Combinators are used to assemble elementary
queries into complex query expressions.


### Working with composite vectors

In `DataKnots`, composite data is represented as a tree of vectors with regular
`Vector` objects at the leaves and composite vectors such as `TupleVector` and
`BlockVector` at the intermediate nodes.  We demonstrated how to create and
transform regular vectors using `filler` and `lift`.  Now let us show how to do
the same with composite vectors.

`TupleVector` is a vector of tuples composed of a sequence of column vectors.
Any collection of vectors could be used as columns as long as they all have the
same length.  One way to obtain `N` columns for a `TupleVector` is to apply `N`
queries to the same input vector.  This is precisely the query action of the
`tuple_of` combinator.

    q = tuple_of(:first => chain_of(lift(split), lift(first), lift(titlecase)),
                 :last => lift(last))
    q(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> @VectorTree (first = String, last = Char) [(first = "Jeffery", last = 'A') … ]

In the opposite direction, the `column` constructor makes a query that extracts
the specified column from the input `TupleVector`.

    q = column(:salary)
    q(@VectorTree (name=String, salary=Int) [("JEFFERY A", 101442), ("JAMES A", 103350), ("TERRY A", 93354)])
    #-> [101442, 103350, 93354]

`BlockVector` is a vector of vectors serialized as a partitioned vector of
elements.  Any input vector could be transformed to a `BlockVector` by the
query `wrap()`, which wraps the vector elements into one-element blocks.

    q = wrap()
    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree [String, REG] ["GARRY M", "ANTHONY R", "DANA A"]

Dual to `wrap()` is the query `flatten()`, which transforms a nested
`BlockVector` by flattening its nested blocks.

    q = flatten()
    q(@VectorTree [[String]] [[["GARRY M"], ["ANTHONY R", "DANA A"]], [[], ["JOSE S"], ["CHARLES S"]]])
    #-> @VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]]

The `distribute` constructor makes a query that rearranges a `TupleVector` with
a `BlockVector` column.  Specifically, it takes each tuple, which should
contain a block value, and transforms it to a block of tuples by distributing
the block value over the tuple.

    q = distribute(:employee)
    q(@VectorTree (department = String, employee = [String]) [
        "POLICE"    ["GARRY M", "ANTHONY R", "DANA A"]
        "FIRE"      ["JOSE S", "CHARLES S"]]) |> display
    #=>
    BlockVector of 2 × [(department = String, employee = String)]:
     [(department = "POLICE", employee = "GARRY M"), (department = "POLICE", employee = "ANTHONY R"), (department = "POLICE", employee = "DANA A")]
     [(department = "FIRE", employee = "JOSE S"), (department = "FIRE", employee = "CHARLES S")]
    =#

Often we need to transform only a part of a composite vector, leaving the rest
of the structure intact.  This can be achieved using `with_column` and
`with_elements` combinators.  Specifically, `with_column` transforms a specific
column of a `TupleVector` while `with_elements` transforms the vector of
elements of a `BlockVector`.

    q = with_column(:employee, with_elements(lift(titlecase)))
    q(@VectorTree (department = String, employee = [String]) [
        "POLICE"    ["GARRY M", "ANTHONY R", "DANA A"]
        "FIRE"      ["JOSE S", "CHARLES S"]]) |> display
    #=>
    TupleVector of 2 × (department = String, employee = [String]):
     (department = "POLICE", employee = ["Garry M", "Anthony R", "Dana A"])
     (department = "FIRE", employee = ["Jose S", "Charles S"])
    =#


### Specialized queries

Not every data transformation can be implemented with lifting.  `DataKnots`
provide query constructors for some common transformation tasks.

For example, data filtering is implemented with the query `sieve()`.  As input,
it expects a `TupleVector` of pairs containing a value and a `Bool` flag.
`sieve()` transforms the input to a `BlockVector` containing 0- and 1-element
blocks.  When the flag is `false`, it is mapped to an empty block, otherwise,
it is mapped to a one-element block containing the data value.

    q = sieve()
    q(@VectorTree (String, Bool) [("JEFFERY A", true), ("JAMES A", true), ("TERRY A", false)])
    #->  @VectorTree [String, OPT] ["JEFFERY A", "JAMES A", missing]

If `DataKnots` does not provide a specific transformation, it is easy to
create a new one.  For example, let us create a query constructor `double`
which makes a query that doubles the elements of the input vector.

We need to provide two definitions: to create a `Query` object and to perform
the query action on the given input vector.

    double() = Query(double)
    double(::Runtime, input::AbstractVector{<:Number}) = input .* 2

    q = double()
    q([260004, 185364, 170112])
    #-> [520008, 370728, 340224]

It is also easy to create new query combinators.  Let us create a combinator
`twice`, which applies the given query to the input two times.

    twice(q) = Query(twice, q)
    twice(::Runtime, input, q) = q(q(input))

    q = twice(double())
    q([260004, 185364, 170112])
    #-> [1040016, 741456, 680448]


## API Reference

```@autodocs
Modules = [DataKnots]
Pages = ["queries.jl"]
```


## Test Suite


### Lifting

The `lift` constructor makes a query by vectorizing a unary function.

    q = lift(titlecase)
    #-> lift(titlecase)

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> ["Garry M", "Anthony R", "Dana A"]

The `block_lift` constructor makes a query on block vectors by vectorizing a
unary vector function.

    q = block_lift(length)
    #-> block_lift(length)

    q(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]])
    #-> [3, 2]

Some vector functions may expect a non-empty vector as an argument.  In this
case, we should provide the value to replace empty blocks.

    q = block_lift(maximum, missing)
    #-> block_lift(maximum, missing)

    q(@VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]])
    #-> Union{Missing, Int}[260004, missing, 202728]

The `tuple_lift` constructor makes a query on tuple vectors by vectorizing a
function of several arguments.

    q = tuple_lift(>)
    #-> tuple_lift(>)

    q(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])
    #-> Bool[1, 0, 0]

The `record_lift` constructor is used when the input is in the *record* layout
(a tuple vector with block vector columns); `record_lift(f)` is a shortcut for
`chain_of(distribute_all(),with_elements(tuple_lift(f)))`.

    q = record_lift(>)
    #-> record_lift(>)

    q(@VectorTree ([Int], [Int]) [[260004, 185364, 170112] 200000; missing 200000; [202728, 197736] [200000, 200000]])
    #-> @VectorTree [Bool] [[1, 0, 0], [], [1, 1, 0, 0]]

With `record_lift`, the cardinality of the output is the upper bound of the
column block cardinalities.

    q(@VectorTree ([Int, PLU], [Int, REG]) [([260004, 185364, 170112], 200000)])
    #-> @VectorTree [Bool, PLU] [[1, 0, 0]]


### Fillers

The query `filler(val)` ignores its input and produces a vector filled with
`val`.

    q = filler(200000)
    #-> filler(200000)

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> [200000, 200000, 200000]

The query `block_filler(blk, card)` produces a block vector filled with the
given block.

    q = block_filler(["POLICE", "FIRE"], PLU)
    #-> block_filler(["POLICE", "FIRE"], PLU)

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree [String, PLU] [["POLICE", "FIRE"], ["POLICE", "FIRE"], ["POLICE", "FIRE"]]

The query `null_filler()` produces a block vector with empty blocks.

    q = null_filler()
    #-> null_filler()

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree [Union{}, OPT] [missing, missing, missing]


### Adapting row-oriented data

The query `adapt_missing()` transforms a vector containing `missing` values to
a block vector with `missing` replaced by an empty block and other values
wrapped in 1-element block.

    q = adapt_missing()
    #-> adapt_missing()

    q([260004, 185364, 170112, missing, 202728, 197736])
    #-> @VectorTree [Int, OPT] [260004, 185364, 170112, missing, 202728, 197736]

The query `adapt_vector()` transforms a vector of vectors to a block vector.

    q = adapt_vector()
    #-> adapt_vector()

    q([[260004, 185364, 170112], Int[], [202728, 197736]])
    #-> @VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]]

The query `adapt_tuple()` transforms a vector of tuples to a tuple vector.

    q = adapt_tuple()
    #-> adapt_tuple()

    q([("GARRY M", 260004), ("ANTHONY R", 185364), ("DANA A", 170112)]) |> display
    #=>
    TupleVector of 3 × (String, Int):
     ("GARRY M", 260004)
     ("ANTHONY R", 185364)
     ("DANA A", 170112)
    =#

Vectors of named tuples are also supported.

    q([(name="GARRY M", salary=260004), (name="ANTHONY R", salary=185364), (name="DANA A", salary=170112)]) |> display
    #=>
    TupleVector of 3 × (name = String, salary = Int):
     (name = "GARRY M", salary = 260004)
     (name = "ANTHONY R", salary = 185364)
     (name = "DANA A", salary = 170112)
    =#


### Composition

The `chain_of` combinator composes a sequence of queries.

    q = chain_of(lift(split), lift(first), lift(titlecase))
    #-> chain_of(lift(split), lift(first), lift(titlecase))

    q(["JEFFERY A", "JAMES A", "TERRY A"])
    #-> ["Jeffery", "James", "Terry"]

The empty chain `chain_of()` has an alias `pass()`.

    q = pass()
    #-> pass()

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> ["GARRY M", "ANTHONY R", "DANA A"]


### Tuple vectors

The query `tuple_of(q₁, q₂ … qₙ)` produces a tuple vector, whose columns are
generated by applying `q₁`, `q₂` … `qₙ` to the input vector.

    q = tuple_of(:title => lift(titlecase), :last => lift(last))
    #-> tuple_of(:title => lift(titlecase), :last => lift(last))

    q(["GARRY M", "ANTHONY R", "DANA A"]) |> display
    #=>
    TupleVector of 3 × (title = String, last = Char):
     (title = "Garry M", last = 'M')
     (title = "Anthony R", last = 'R')
     (title = "Dana A", last = 'A')
    =#

The query `column(lbl)` extracts the specified column from a tuple vector.  The
`column` constructor accepts either the column position or the column label.

    q = column(1)
    #-> column(1)

    q(@VectorTree (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112])
    #-> ["GARRY M", "ANTHONY R", "DANA A"]

    q = column(:salary)
    #-> column(:salary)

    q(@VectorTree (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112])
    #-> [260004, 185364, 170112]

The `with_column` combinator lets us apply the given query to a selected column
of a tuple vector.

    q = with_column(:name, lift(titlecase))
    #-> with_column(:name, lift(titlecase))

    q(@VectorTree (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]) |> display
    #=>
    TupleVector of 3 × (name = String, salary = Int):
     (name = "Garry M", salary = 260004)
     (name = "Anthony R", salary = 185364)
     (name = "Dana A", salary = 170112)
    =#


### Block vectors

The query `wrap()` wraps the elements of the input vector to one-element blocks.

    q = wrap()
    #-> wrap()

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @VectorTree [String, REG] ["GARRY M", "ANTHONY R", "DANA A"]

The query `flatten()` flattens a nested block vector.

    q = flatten()
    #-> flatten()

    q(@VectorTree [[String]] [[["GARRY M"], ["ANTHONY R", "DANA A"]], [missing, ["JOSE S"], ["CHARLES S"]]])
    #-> @VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]]

The `with_elements` combinator lets us apply the given query to transform the
elements of a block vector.

    q = with_elements(lift(titlecase))
    #-> with_elements(lift(titlecase))

    q(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]])
    #-> @VectorTree [String] [["Garry M", "Anthony R", "Dana A"], ["Jose S", "Charles S"]]

The query `distribute(lbl)` transforms a tuple vector with a block column to a
block vector of tuples by distributing the block elements over the tuple.

    q = distribute(1)
    #-> distribute(1)

    q(@VectorTree ([Int], [Int]) [
        [260004, 185364, 170112]    200000
        missing                     200000
        [202728, 197736]            [200000, 200000]]
    ) |> display
    #=>
    BlockVector of 3 × [(Int, [Int])]:
     [(260004, [200000]), (185364, [200000]), (170112, [200000])]
     []
     [(202728, [200000, 200000]), (197736, [200000, 200000])]
    =#

The query `distribute_all()` takes a tuple vector with block columns and
distribute all of the block columns.

    q = distribute_all()
    #-> distribute_all()

    q(@VectorTree ([Int], [Int]) [
        [260004, 185364, 170112]    200000
        missing                     200000
        [202728, 197736]            [200000, 200000]]
    ) |> display
    #=>
    BlockVector of 3 × [(Int, Int)]:
     [(260004, 200000), (185364, 200000), (170112, 200000)]
     []
     [(202728, 200000), (202728, 200000), (197736, 200000), (197736, 200000)]
    =#

This query is equivalent to
`chain_of(distribute(1),with_elements(distribute(2),flatten())`.

The query `block_length()` calculates the lengths of blocks in a block vector.

    q = block_length()
    #-> block_length()

    q(@VectorTree [String] [missing, "GARRY M", ["ANTHONY R", "DANA A"]])
    #-> [0, 1, 2]

The query `block_any()` checks whether the blocks in a `Bool` block vector have
any `true` values.

    q = block_any()
    #-> block_any()

    q(@VectorTree [Bool] [missing, true, false, [true, false], [false, false], [false, true]])
    #-> Bool[0, 1, 0, 1, 0, 1]


### Filtering

The query `sieve()` filters a vector of pairs by the second column.

    q = sieve()
    #-> sieve()

    q(@VectorTree (Int, Bool) [260004 true; 185364 false; 170112 false])
    #-> @VectorTree [Int, OPT] [260004, missing, missing]


### Slicing

The query `slice(N)` transforms a block vector by keeping the first `N`
elements of each block.

    q = slice(2)
    #-> slice(2, false)

    q(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree [String] [["GARRY M", "ANTHONY R"], ["JOSE S", "CHARLES S"], []]

When `N` is negative, `slice(N)` drops the last `N` elements of each block.

    q = slice(-1)

    q(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree [String] [["GARRY M", "ANTHONY R"], ["JOSE S"], []]

The query `slice(N, true)` drops the first `N` elements (or keeps the last `N`
elements if `N` is negative).

    q = slice(2, true)

    q(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree [String] [["DANA A"], [], []]

    q = slice(-1, true)

    q(@VectorTree [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"], missing])
    #-> @VectorTree [String] [["DANA A"], ["CHARLES S"], []]

A variant of this query `slice()` expects a tuple vector with two columns: the
first column containing the blocks and the second column with the number of
elements to keep.

    q = slice()
    #-> slice(false)

    q(@VectorTree ([String], Int) [(["GARRY M", "ANTHONY R", "DANA A"], 1), (["JOSE S", "CHARLES S"], -1), (missing, 0)])
    #-> @VectorTree [String] [["GARRY M"], ["JOSE S"], []]
