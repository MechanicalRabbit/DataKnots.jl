# Thinking in Queries

DataKnots is a Julia library for building database queries. This
conceptual guide provides a deeper look at DataKnots beyond what
is available in the tutorial. We'll start with a quick overview of
the query algebra, then we'll move on to the structure of knots,
then pipelines, and finally back to query combinators.

There are four layers in the DataKnots package. At the lowest
level are `DataKnot` objects, which are the input and output of a
`Query`. At the highest level are combinators, such as `Count`,
which are used to build queries from other queries. The `Pipeline`
layer is an implementation detail, pipelines can be seen as a
detailed query plan describing just how data should be processed.
This layer helpful for explaining the semantics of queries and is
helpful for those building custom queries and combinators.

| Layer        | Function                              |
|:-------------|:--------------------------------------|
| `Combinator` | builds a `Query` from other queries   |
| `Query`      | assembles `Pipeline` extensions       |
| `Pipeline`   | transforms one `DataKnot` to another  |
| `DataKnot`   | provides block-oriented storage model |

To start working with DataKnots, we import the package:

    using DataKnots

This statement imports common query constructors such as `Lift`,
and combinators, such as `Count`. Further, it imports the
constructor for `DataKnot` objects. That said, pipeline functions,
such as `DataKnots.assemble` are not imported, but they would only
be used by those curious about the workings of queries.

## Query Algebra

In DataKnots, queries are assembled algebraically: they either
come from a set of atomic *primitives* or are built from other
queries using *combinators*.

### The Unit Knot

A `DataKnot`, or just *knot*, is a container for structured,
vectorized data. The `unitknot` is a trivial knot used as the
starting point for constructing other knots.

    unitknot
    #=>
    ┼──┼
    │  │
    =#

The unit knot has a single value, an empty tuple. You could get
the value of any knot using Julia's `get` function.

    get(unitknot)
    #-> ()

### Constant Queries

Any Julia value could be converted to a *query* using the `Lift`
constructor. Queries constructed this way are constant: for each
input element they receive, they output the given value. Consider
the query `Hello`, lifted from the string value `"Hello World"`.

    Hello = Lift("Hello World")

To query `unitknot` with `Hello`, we use indexing notation
`unitknot[Hello]`. In this case, `Hello` receives `()` from
`unitknot` and produces the value, `"Hello World"`.

    unitknot[Hello]
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

A `Tuple` lifted to a constant query is displayed as a table.

    unitknot[Lift((name="DataKnots", version="0.1"))]
    #=>
    │ name       version │
    ┼────────────────────┼
    │ DataKnots  0.1     │
    =#

A `missing` value lifted to a constant query produces no output.

    unitknot[Lift(missing)]
    #=>
    (empty)
    =#

A `Vector` lifted to a constant query will produce plural output.

    unitknot[Lift('a':'c')]
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    =#

We call queries constructed this way primitives, as they do not
rely upon any other query. There are also combinators, which build
new queries from existing ones.

### Composition & Identity

Two queries can be connected sequentially using the *composition*
combinator (`>>`). Consider the composition `Lift(1:3) >> Hello`.
Since `Hello` produces a value for each input element, preceding
it with `Lift(1:3)` generates three copies of `"Hello World"`.

    unitknot[Lift(1:3) >> Hello]
    #=>
    ──┼─────────────┼
    1 │ Hello World │
    2 │ Hello World │
    3 │ Hello World │
    =#

If we compose two plural queries, `Lift(1:2)` and `Lift('a':'c')`,
the output will contain the elements of `'a':'c'` repeated twice.

    unitknot[Lift(1:2) >> Lift('a':'c')]
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    4 │ a │
    5 │ b │
    6 │ c │
    =#

The *identity* with respect to query composition is called `It`.
This primitive can be composed with any query without changing the
query's output.

    unitknot[Hello >> It]
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

The identity primitive, `It`, can be used to construct queries
which rely upon the output from previous processing.

    Increment = It .+ 1
    unitknot[Lift(1:3) >> Increment]
    #=>
    ──┼───┼
    1 │ 2 │
    2 │ 3 │
    3 │ 4 │
    =#

In DataKnots, queries are built algebraically, starting with query
primitives, such as constants (`Lift`) or the identity (`It`), and
then arranged with with combinators, such as composition (`>>`).
This lets us define sophisticated query components and remix them
in creative ways.

## The Shape of Data

To discuss the structure and function of queries, we must first
describe the *shape* of `DataKnot` objects. Shapes are used to
track value types, cardinality constraints, field labels, and
other properties.

To obtain the shape of a knot, use the `shape` function.

    DataKnots.shape(unitknot)
    #-> BlockOf(TupleOf(), x1to1)

Here we discover that the shape of the `unitknot` is a singular
block of empty tuples.

### Blocks

A *block* is a collection of elements of a particular type, with
the number of its elements satisfying a certain cardinality
constraint. Query results are always packaged as a block.

Consider the knot produced by the query `Lift('a':'c')`.

    abc = unitknot[Lift('a':'c')]
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    =#

The knot `abc` contains several character elements wrapped in a
single block.

    DataKnots.shape(abc)
    #-> BlockOf(Char)

Now consider the output of a singular query.

    hello = unitknot[Lift("Hello World")]
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

This knot contains a single string wrapped in a block. Since this
block contains exactly one element, its cardinality is `:x1to1`.

    DataKnots.shape(hello)
    #-> BlockOf(String, x1to1)

### Cardinality

*Cardinality* restricts the possible number of elements per block:
*singular* means there is at most one value in each block;
*mandatory* means there must be at least one value in each block.

| Cardinality | Mandatory | Singular | Description               |
|:------------|:----------|:---------|--------------------------:|
| `:x0to1`    | *no*      | *yes*    | optional, singular value  |
| `:x0toN`    | *no*      | *no*     | optional, plural values   |
| `:x1to1`    | *yes*     | *yes*    | exactly one value         |
| `:x1toN`    | *yes*     | *no*     | at least one plural value |

When an `AbstractVector` is converted to queries via `Lift`, the
default cardinality is `:x0toN`. Values of `Missing` type are
treated as `:x0to1`. Otherwise, the cardinality is `:x1to1`.

For more detail on how `Lift` constructs queries, see the section
entitled [cardinality of lift](#Cardinality-of-Lift-1).

### Values

So that we could declare the use of native Julia values as block
elements, we wrap their type in a *value* shape. In particular,
`BlockOf(String)` abbreviates `BlockOf(ValueOf(String))`.

    DataKnots.BlockOf(DataKnots.ValueOf(String))
    #-> BlockOf(String)

When a Julia value is lifted to queries, the outer `Vector` is
used to represent block elements. Its element type is then wrapped
with `ValueOf` to become the block's shape. Hence, a block of
`Vector` could be constructed:

    numbers = unitknot[Lift([[1,2],[3]])]
    #=>
    ──┼──────┼
    1 │ 1; 2 │
    2 │ 3    │
    =#

The shape of `numbers` this is a block of `ValueOf(Vector)`.

    DataKnots.shape(numbers)
    #-> BlockOf(Array{Int64,1})

Once could also construct this shape directly.

    DataKnots.BlockOf(DataKnots.ValueOf(Vector{Int64}))
    #-> BlockOf(Array{Int64,1})

Some queries may produce empty output, that is, a single block
that happens to not have any values in it.

    empty = unitknot[Lift(missing)]
    #=>
    (empty)
    =#

The shape of this `empty` knot indicates its block could have at
most one value (`:x0to1`). Further, `missing` is treated as the
lack of value. Hence, rather than a `ValueOf(Missing)` shape, it
has the bottom shape, `NoShape()`.

    DataKnots.shape(empty)
    #-> BlockOf(NoShape(), x0to1)

### Labels

Shape is also used to track query labels. A label can be given to
a query using the `Label` primitive.

    labeled = unitknot[Lift("Hello World") >> Label(:message)]
    #=>
    │ message     │
    ┼─────────────┼
    │ Hello World │
    =#

When the `Label` primitive is composed with a query, it doesn't
change how data is processed, but instead modifies output shape.

    DataKnots.shape(labeled)
    #-> BlockOf(String, x1to1) |> IsLabeled(:message)

We use the `Pair` constructor as a convenient syntax for the
assignment of labels.

    unitknot[:message => "Hello World"]
    #=>
    │ message     │
    ┼─────────────┼
    │ Hello World │
    =#

The label shape is used when displaying titles. It also is used by
the `Record` combinator when constructing tuples.

### Tuples

Besides blocks that structure data sequentially, data could also
be organized in parallel as a named *tuple*.

    message = unitknot[Record(:message=>"Hello World")]
    #=>
    │ message     │
    ┼─────────────┼
    │ Hello World │
    =#

The `Record` combinator converts query labels, such as `message`,
into field names. In a tuple constructed by `Record`, field values
are always wrapped in a block. Hence, the shape of this query is a
block of tuples, with elements being a block of strings.

    DataKnots.shape(message)
    #-> BlockOf(TupleOf(:message => BlockOf(String, x1to1)), x1to1)

The only structural difference between this query and a table is
the cardinality of the outer block.

    table = unitknot[Lift(1:3) >> Record(:n => It, :n² => It .* It)]
    #=>
      │ n  n² │
    ──┼───────┼
    1 │ 1   1 │
    2 │ 2   4 │
    3 │ 3   9 │
    =#

    DataKnots.shape(table)
    #-> BlockOf(TupleOf(:n => BlockOf(Int64, x1to1), :n² => BlockOf(Int64, x1to1)))

The combination of blocks, values, labels, and tuples permit
structured hierararchies to be represented as a `DataKnot`.

## Pipeline Processing

So far we've discussed knots, queries and combinators. What we've
not discussed are pipelines, which transform one knot to another.
Normally one doesn't interact with pipelines unless you are
building novel query combinators.

To start, how does `unitknot[Lift("Hello")]` function?

### Assembling Pipelines

Before we can assemble a pipeline, we first need the shape of the
input source. Since we're going to be running our query against
the `unitknot`, let's obtain its shape.

    unitshape = DataKnots.shape(unitknot)
    #-> BlockOf(TupleOf(), x1to1)

We could then assemble the pipeline for `Lift("Hello")`.

    hello_pipe = DataKnots.assemble(unitshape, Lift("Hello"))
    #-> with_elements(filler("Hello"))

This pipeline has two phases: it loops though each element of the
input block (`with_elements`); then, for each of those elements,
it produces the string value `"Hello"` (`filler`).

Once assembled, we could run the pipeline against the `unitknot`.

    hello_pipe(unitknot)
    #=>
    ┼───────┼
    │ Hello │
    =#

Observe that pipeline assembly doesn't depend upon the exact input
data, but it does depends upon shape of the input source.

### Pipeline Signature

A pipeline is a function that maps data blocks from an input
*source* to blocks in its output *target*. We could inquire about
the pipeline's input and output shapes.

    DataKnots.source(hello_pipe)
    #-> BlockOf(TupleOf(), x1to1)

    DataKnots.target(hello_pipe)
    #-> BlockOf(String, x1to1)

One needs both the `source` and the `target` shapes to define the
signature of the pipeline function.

    DataKnots.signature(hello_pipe)
    #-> Signature(BlockOf(TupleOf(), x1to1), BlockOf(String, x1to1))

Here we see that `hello_pipe` expects its input source to provide
an empty tuple, and that it'll produce a string.

### Trivial Pipelines

Internally, any `DataKnot` can be converted into a `Pipeline`
capable of reproducing itself.

    unitpipe = DataKnots.trivial_pipe(unitknot)
    #-> pass()

The signature of a `trivial` pipeline has both the source and the
target being the shape of the knot it was derived from.

    DataKnots.signature(unitpipe)
    #-> Signature(BlockOf(TupleOf(), x1to1), BlockOf(TupleOf(), x1to1) |> IsFlow)

We could use this `unitpipe` on itself.

    unitpipe(unitknot)
    #=>
    ┼──┼
    │  │
    =#

### Queries are Pipeline Extensions

Previously we saw how we could assemble a `Query` to a `Pipeline`
by providing a given shape. In the more nominal case, one builds
pipelines by extending previous pipelines. Let's recall our
`unitpipe`.

    unitpipe = DataKnots.trivial_pipe(unitknot)
    #-> pass()

Let's extend the this pipeline with the query `Lift("Hello")`.

    hello_pipe = DataKnots.assemble(nothing, unitpipe, Lift("Hello"))
    #-> chain_of(with_elements(chain_of(filler("Hello"), wrap())), flatten())

This pipeline could then be run.

    hello_pipe(unitknot)
    #=>
    ┼───────┼
    │ Hello │
    =#

## Combinators

Now that we've covered shapes and pipelines, we could go further
into detail how things work at a higher level.

### Lifting Functions

Any function could be used in a query. Consider the function
`double(x)` that, when applied to a `Number`, produces a `Number`:

    double(x) = 2x
    double(3) #-> 6

What we want is an analogue to `double` which, instead of
operating on numbers, operates on queries. Such functions are
called query combinators. We can convert any function to a
combinator by passing the function and its arguments to `Lift`.

    Double(X) = Lift(double, (X,))

For a given query `X`, the combinator `Double(X)` evaluates `X`
and then runs each output element though the `double` function.

    unitknot[Lift(1:3) >> Double(It)]
    #=>
    ──┼───┼
    1 │ 2 │
    2 │ 4 │
    3 │ 6 │
    =#

Alternatively, instead of `Lift` we could use broadcasting. For
example, `double.(It)` is equivalent to `Lift(double, (It,))`.

    unitknot[Lift(1:3) >> double.(It)]
    #=>
    ──┼───┼
    1 │ 2 │
    2 │ 4 │
    3 │ 6 │
    =#

Broadcasting also works with operators.

    unitknot[Lift(1:3) >> (It .+ 1)]
    #=>
    ──┼───┼
    1 │ 2 │
    2 │ 3 │
    3 │ 4 │
    =#

Unary operators can be broadcast as well.

    unitknot[Lift(1:3) >> (√).(It)]
    #=>
    ──┼─────────┼
    1 │ 1.0     │
    2 │ 1.41421 │
    3 │ 1.73205 │
    =#

Broadcasting could only be used when at least one argument is a
query. For this reason, when defining a combinator, it is
recommended to use `Lift` over broadcasting.

    Sqrt(X) = Lift(√, (X,))

    unitknot[Sqrt(2)]
    #=>
    ┼─────────┼
    │ 1.41421 │
    =#

Vector-valued functions give rise to plural queries. Here, the
unit range constructor is lifted to a query combinator that builds
plural queries.

    OneTo(X) = Lift(:, (1, X))

    unitknot[OneTo(3)]
    #=>
    ──┼───┼
    1 │ 1 │
    2 │ 2 │
    3 │ 3 │
    =#

Since later in this guide we'll want to enumerate the alphabet,
let's define a combinator for that as well. In this definition,
anonymous function syntax (`->`) is used to build an expression
that is then lifted to queries.

    Chars(N) = Lift(n -> 'a':'a'+n-1, (N,))

    unitknot[Chars(3)]
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    =#

Lifting lets us use rich statistical and data processing functions
from within our queries.

### Aggregate Queries

So far queries have been *elementwise*; that is, for each input
element, they produce zero or more output elements. Consider the
`Count` primitive; it returns the number of its input elements.

    unitknot[Lift(1:3) >> Count]
    #=>
    ┼───┼
    │ 3 │
    =#

An *aggregate* query such as `Count` is computed over the input as
a whole, and not for each individual element. The semantics of
aggregates require discussion. Consider `Lift(1:3) >> OneTo(It)`.

    OneTo(X) = Lift(:, (1, X))

    unitknot[Lift(1:3) >> OneTo(It)]
    #=>
    ──┼───┼
    1 │ 1 │
    2 │ 1 │
    3 │ 2 │
    4 │ 1 │
    5 │ 2 │
    6 │ 3 │
    =#

By appending `>> Sum` we could aggregate the entire input flow,
producing a single output element.

    unitknot[Lift(1:3) >> OneTo(It) >> Sum]
    #=>
    ┼────┼
    │ 10 │
    =#

What if we wanted to produce sums by the outer query, `Lift(1:3)`?
Since query composition (`>>`) is associative, adding parenthesis
around `OneTo(It) >> Sum` will not change the result.

    unitknot[Lift(1:3) >> (OneTo(It) >> Sum)]
    #=>
    ┼────┼
    │ 10 │
    =#

We could use `Record` to create this elementwise barrier.
However, it introduces an intermediate, unwanted structure:
we asked for sums, not a table with sums.

    unitknot[Lift(1:3) >>
             Record(:data => OneTo(It),
                    :sum => OneTo(It) >> Sum)]
    #=>
      │ data     sum │
    ──┼──────────────┼
    1 │ 1          1 │
    2 │ 1; 2       3 │
    3 │ 1; 2; 3    6 │
    =#

We need the `Each` combinator, which much the same as `Record`,
acts as an elementwise barrier. For each input element, `Each`
evaluates its argument, and then collects the outputs.

    unitknot[Lift(1:3) >> Each(OneTo(It) >> Sum)]
    #=>
    ──┼───┼
    1 │ 1 │
    2 │ 3 │
    3 │ 6 │
    =#

Normally, one wouldn't need to use `Each` — for aggregates such as
`Sum` or `Count`, the query `Y >> Each(X >> Count)` is equivalent
to `Y >> Count(X)`. Hence, we could use the combinator form of
`Sum` to do this relative summation.

    unitknot[Lift(1:3) >> Sum(OneTo(It))]
    #=>
    ──┼───┼
    1 │ 1 │
    2 │ 3 │
    3 │ 6 │
    =#

Julia functions taking a vector argument, such as `mean`, can be
lifted to a combinator taking a plural query. When performed, the
plural output is converted into the function's vector argument.

    using Statistics
    Mean(X) = mean.(X)

    unitknot[Mean(Lift(1:3) >> Sum(OneTo(It)))]
    #=>
    ┼─────────┼
    │ 3.33333 │
    =#

To use `Mean` as a query primitive, we use `Then` to build a query
that aggregates elements from its input. Next, we register this
query aggregate so it is used when `Mean` is treated as a query.

    DataKnots.Lift(::typeof(Mean)) = DataKnots.Then(Mean)

Once these are done, one could take an average of sums as follows:

    unitknot[Lift(1:3) >> Sum(OneTo(It)) >> Mean]
    #=>
    ┼─────────┼
    │ 3.33333 │
    =#

In DataKnots, summary operations are expressed as aggregate query
primitives or as query combinators taking a plural query argument.
Moreover, custom aggregates can be constructed from native Julia
functions and lifted into the query algebra.

### Take

Unlike `Filter` which evaluates its argument for each input
element, the argument to `Take` is evaluated once, and in the
context of the input's *source*.

    unitknot[Lift(1:3) >> Each(Lift('a':'c') >> Take(It))]
    #=>
    ──┼───┼
    1 │ a │
    2 │ a │
    3 │ b │
    4 │ a │
    5 │ b │
    6 │ c │
    =#

In this example, the argument of `Take` evaluates in the context
of `Lift(1:3)`. Therefore, `Take` will be performed three times,
where `It` has the values `1`, `2`, and `3`.

### Group

Before we can demonstrate `Group`, we need an interesting dataset.
Let's create a flat list of numbers with two characteristics.

    DataRow = :data=> Record(:no => It,
                             :even => iseven.(It),
                             :char => Char.((It .+ 2) .% 3 .+ 97))
    DataSet = Lift(1:9) >> DataRow

    unitknot[DataSet]
    #=>
      │ data            │
      │ no  even   char │
    ──┼─────────────────┼
    1 │  1  false  a    │
    2 │  2   true  b    │
    3 │  3  false  c    │
    4 │  4   true  a    │
    5 │  5  false  b    │
    6 │  6   true  c    │
    7 │  7  false  a    │
    8 │  8   true  b    │
    9 │  9  false  c    │
    =#

The `Group` combinator rearranges the dataset to bucket unique
values of a particular expression together with its matching data.

    unitknot[DataSet >> Group(It.char)]
    #=>
      │ char  data{no,even,char}                   │
    ──┼────────────────────────────────────────────┼
    1 │ a     1, false, a; 4, true, a; 7, false, a │
    2 │ b     2, true, b; 5, false, b; 8, true, b  │
    3 │ c     3, false, c; 6, true, c; 9, false, c │
    =#

With this rearrangement, we could summarize data with respect to
the grouping expression.

    unitknot[DataSet >>
             Group(It.char) >>
             Record(It.char,
                    It.data.no,
                    :count => Count(It.data),
                    :mean => mean.(It.data.no))]
    #=>
      │ char  no       count  mean │
    ──┼────────────────────────────┼
    1 │ a     1; 4; 7      3   4.0 │
    2 │ b     2; 5; 8      3   5.0 │
    3 │ c     3; 6; 9      3   6.0 │
    =#

It's possible to group by more than one expression.

    unitknot[DataSet >>
             Group(It.even, It.char) >>
             Record(It.even, It.char, It.data.no)]
    #=>
      │ even   char  no   │
    ──┼───────────────────┼
    1 │ false  a     1; 7 │
    2 │ false  b     5    │
    3 │ false  c     3; 9 │
    4 │  true  a     4    │
    5 │  true  b     2; 8 │
    6 │  true  c     6    │
    =#

The `Group` combinator lets you adapt the structure of a dataset
to form a hierarchy suitable to a particular analysis.

### Query Parameters

With DataKnots, parameters can be provided so that static data can
be used within query expressions. By convention, we use upper
case, singular labels for query parameters.

    unitknot["Hello " .* Get(:WHO), WHO="World"]
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

To make `Get` convenient, `It` provides a shorthand syntax.

    unitknot["Hello " .* It.WHO, WHO="World"]
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

Query parameters are available anywhere in the query. They could,
for example be used within a filter.

    query = OneTo(6) >> Filter(It .> It.START)

    unitknot[query, START=3]
    #=>
    ──┼───┼
    1 │ 4 │
    2 │ 5 │
    3 │ 6 │
    =#

Parameters can also be defined as part of a query using `Given`.
This combinator takes set of pairs (`=>`) that map symbols
(`:name`) onto query expressions. The subsequent argument is then
evaluated in a naming context where the defined parameters are
available for reuse.

    unitknot[Given(:WHO => "World", "Hello " .* Get(:WHO))]
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

Query parameters can be especially useful when managing
aggregates, or with expressions that one may wish to repeat more
than once.

    GreaterThanAverage(X) =
      Given(:AVG => Mean(X),
            X >> Filter(It .> Get(:AVG)))

    unitknot[GreaterThanAverage(OneTo(6))]
    #=>
    ──┼───┼
    1 │ 4 │
    2 │ 5 │
    3 │ 6 │
    =#

With `Given` the parameter provided, `AVG` does not leak into
the surrounding context.

    unitknot[GreaterThanAverage(OneTo(6)) >> It.AVG]
    #-> ERROR: cannot find "AVG" at ⋮

In DataKnots, query parameters permit external data to be used
within query expressions. Parameters that are defined with `Given`
can be used to remember values and reuse them.

## Julia Integration

DataKnots is a query algebra embedded in the Julia programming
language. We should discuss the interaction between the semantics
of the query algebra and the semantics of Julia.

### Precedence of Composition

DataKnots uses Julia's bitshift operator (`>>`) for composition.

This works visually, but the *precedence* of this operator does
not match user expectations. Specifically, common binary operators
such as addition (`+`) have a lower precedence.

This expectation mismatch could lead a user to write:

    unitknot[Lift(1:3) >> It .+ It]
    #-> ERROR: cannot apply + to Tuple{Array{Int64,1},Tuple{}}⋮

To fix this query, we add parentheses.

    unitknot[Lift(1:3) >> (It .+ It)]
    #=>
    ──┼───┼
    1 │ 2 │
    2 │ 4 │
    3 │ 6 │
    =#

### Composition of Queries

For bitshift operator (`>>`) to work as composition, the first
operand must be a query.

    unitknot[1:3 >> "Hello"]
    #-> ERROR: MethodError: no method matching >>(::Int64, ::String)⋮

To fix this query, we use `Lift` to convert the first operand to a
query.

    unitknot[Lift(1:3) >> "Hello"]
    #=>
    ──┼───────┼
    1 │ Hello │
    2 │ Hello │
    3 │ Hello │
    =#

### Support for `Tuple`

A `Tuple` lifted to a constant query is displayed as a table.

    unitknot[Lift((msg="Hello",))]
    #=>
    │ msg   │
    ┼───────┼
    │ Hello │
    =#

When they are lifted, native vectors are automatically converted
into our block vector. However, native tuples are left unwrapped.

    DataKnots.shape(unitknot[Lift((msg="Hello",))])
    #-> BlockOf(NamedTuple{(:msg,),Tuple{String}}, x1to1)

That said, tuple entries can be directly accessed using `It`.

    unitknot[Lift((msg="Hello",)) >> It.msg]
    #=>
    │ msg   │
    ┼───────┼
    │ Hello │
    =#

Although it looks the same visually, this has a different shape.

    DataKnots.shape(unitknot[Lift((msg="Hello",)) >> It.msg])
    #-> BlockOf(String, x1to1) |> IsLabeled(:msg)

### Cardinality of Lift

For constant queries produced by `Lift`, the cardinality is
guessed based upon the type of the underlying data.  If the type
is `Missing`, then it is `x0to1`. If the type is a kind of
`AbstractVector`, then `Lift` guesses it should be unconstrained
(`:x0toN`). All other data types are assumed to have a mandatory,
singular cardinality (`:x1to1`).


| Type             | Cardinality | Mandatory | Singular |
|:-----------------|:------------|:----------|:---------|
| `Missing`        | `:x0to1`    | *no*      | *yes*    |
| `AbstractVector` | `:x0toN`    | *no*      | *no*     |
| `Any`            | `:x1to1`    | *yes*     | *yes*    |
|                  | `:x1toN`    | *yes*     | *no*     |

We can cause a constant query produced by `Lift` to produce knots
having a specific cardinality.

    greetings = unitknot[Lift(["Hello"], :x1toN)]
    #=>
    ──┼───────┼
    1 │ Hello │
    =#

The shape of the `greetings` knot will then indicate that it has a
plural block with at least one element.

    DataKnots.shape(greetings)
    #-> BlockOf(String, x1toN)

Observe that specifying the cardinality works even for singular
values, even if the value lifted happens to be a vector.

    greeting = unitknot[Lift(["Hello"], :x1to1)]
    #=>
    ┼───────┼
    │ Hello │
    =#

    DataKnots.shape(greeting)
    #-> BlockOf(String, x1to1)

Just because a `Vector` is automatically converted into a block
doesn't mean a block can't contain a vector.

    opaque = ["HELLO", "WORLD"]

    single = unitknot[Lift([opaque], :x1to1)]
    #=>
    ┼──────────────┼
    │ HELLO; WORLD │
    =#

The value of this knot is actually a `Vector`, even if it may be
shown in a convenient way.

    DataKnots.shape(single)
    #-> BlockOf(Array{String,1}, x1to1)

This value can be retrieved using `get`.

    get(single)
    #-> ["HELLO", "WORLD"]

### Broadcasting over Queries

Broadcasting can be used to convert function calls into query
expressions. For broadcasting to build a query, at least one
argument must be a query.

Even when the argument isn't a query, the result often works
as expected.

    unitknot[iseven.(2)]
    #=>
    ┼──────┼
    │ true │
    =#

In this case, `iseven.(2)` is evaluated to the constant `true`,
which is automatically lifted to a constant query.

For some functions this may lead to unexpected results. Suppose
we need to generate 3 random characters.

    using Random: seed!, rand
    seed!(1)
    rand('a':'z')
    #-> 'o'

We could try to make the following query.

    unitknot[Lift(1:3) >> rand('a':'z')]
    #=>
    ──┼───┼
    1 │ c │
    2 │ c │
    3 │ c │
    =#

Unfortunately, the function `rand` evaluated once, which gives us
the same value repeated 3 times. Let's try broadcasting.

    unitknot[Lift(1:3) >> rand.('a':'z')]
    #-> ERROR: ArgumentError: Sampler for this object is not defined⋮

For broadcasting to generate a query, we need at least one
argument to be a query. If we don't have a query argument, we
could make one using `Lift`.

    unitknot[Lift(1:3) >> rand.(Lift('a':'z'))]
    #=>
    ──┼───┼
    1 │ h │
    2 │ b │
    3 │ v │
    =#
