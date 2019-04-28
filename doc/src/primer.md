# Primer

DataKnots is a Julia library for building database queries. In
DataKnots, queries are assembled algebraically: they either come
from a set of atomic *primitives* or are built from other queries
using *combinators*.

To start working with DataKnots, we import the package:

    using DataKnots

## The Unit Knot

A `DataKnot`, or just *knot*, is a container for structured,
vectorized data. The `unitknot` is a trivial knot used as the
starting point for constructing other knots.

    unitknot
    #=>
    │ It │
    ┼────┼
    │    │
    =#

The unit knot has a single value, an empty tuple. You could get
the value of any knot using Julia's `get` function.

    get(unitknot)
    #-> ()

## Constant Queries

Any Julia value could be converted to a *query* using the `Lift`
constructor. Queries constructed this way are constant: for each
input element they receive, they output the given value. Consider
the query `Hello`, lifted from the string value `"Hello World"`.

    Hello = Lift("Hello World")

To query `unitknot` with `Hello`, we use indexing notation
`unitknot[Hello]`. In this case, `Hello` receives `nothing` from
`unitknot` and produces the value, `"Hello World"`.

    unitknot[Hello]
    #=>
    │ It          │
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
    │ It │
    ┼────┼
    =#

A `Vector` lifted to a constant query will produce plural output.

    unitknot[Lift('a':'c')]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

We call queries constructed this way primitives, as they do not
rely upon any other query. There are also combinators, which build
new queries from existing ones.

## Composition & Identity

Two queries can be connected sequentially using the *composition*
combinator (`>>`). Consider the composition `Lift(1:3) >> Hello`.
Since `Hello` produces a value for each input element, preceding
it with `Lift(1:3)` generates three copies of `"Hello World"`.

    unitknot[Lift(1:3) >> Hello]
    #=>
      │ It          │
    ──┼─────────────┼
    1 │ Hello World │
    2 │ Hello World │
    3 │ Hello World │
    =#

If we compose two plural queries, `Lift(1:2)` and `Lift('a':'c')`,
the output will contain the elements of `'a':'c'` repeated twice.

    unitknot[Lift(1:2) >> Lift('a':'c')]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    4 │ a  │
    5 │ b  │
    6 │ c  │
    =#

The *identity* with respect to query composition is called `It`.
This primitive can be composed with any query without changing the
query's output.

    unitknot[Hello >> It]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

The identity primitive, `It`, can be used to construct queries
which rely upon the output from previous processing.

    Increment = It .+ 1
    unitknot[Lift(1:3) >> Increment]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  3 │
    3 │  4 │
    =#

In DataKnots, queries are built algebraically, starting with query
primitives, such as constants (`Lift`) or the identity (`It`), and
then arranged with with combinators, such as composition (`>>`).
This lets us define sophisticated query components and remix them
in creative ways.

## Lifting Functions

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
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Alternatively, instead of `Lift` we could use broadcasting. For
example, `double.(It)` is equivalent to `Lift(double, (It,))`.

    unitknot[Lift(1:3) >> double.(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Broadcasting also works with operators.

    unitknot[Lift(1:3) >> (It .+ 1)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  3 │
    3 │  4 │
    =#

Unary operators can be broadcast as well.

    unitknot[Lift(1:3) >> (√).(It)]
    #=>
      │ It      │
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
    │ It      │
    ┼─────────┼
    │ 1.41421 │
    =#

Vector-valued functions give rise to plural queries. Here, the
unit range constructor is lifted to a query combinator that builds
plural queries.

    OneTo(X) = Lift(:, (1, X))

    unitknot[OneTo(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

Since later in this guide we'll want to enumerate the alphabet,
let's define a combinator for that as well. In this definition,
anonymous function syntax (`->`) is used to build an expression
that is then lifted to queries.

    Chars(N) = Lift(n -> 'a':'a'+n-1, (N,))

    unitknot[Chars(3)]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

Lifting lets us use rich statistical and data processing functions
from within our queries.

## Aggregate Queries

So far queries have been *elementwise*; that is, for each input
element, they produce zero or more output elements. Consider the
`Count` primitive; it returns the number of its input elements.

    unitknot[Lift(1:3) >> Count]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

An *aggregate* query such as `Count` is computed over the input as
a whole, and not for each individual element. The semantics of
aggregates require discussion. Consider `Lift(1:3) >> OneTo(It)`.

    OneTo(X) = Lift(:, (1, X))

    unitknot[Lift(1:3) >> OneTo(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  1 │
    3 │  2 │
    4 │  1 │
    5 │  2 │
    6 │  3 │
    =#

By appending `>> Sum` we could aggregate the entire input flow,
producing a single output element.

    unitknot[Lift(1:3) >> OneTo(It) >> Sum]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

What if we wanted to produce sums by the outer query, `Lift(1:3)`?
Since query composition (`>>`) is associative, adding parenthesis
around `OneTo(It) >> Sum` will not change the result.

    unitknot[Lift(1:3) >> (OneTo(It) >> Sum)]
    #=>
    │ It │
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
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  3 │
    3 │  6 │
    =#

Normally, one wouldn't need to use `Each` — for aggregates such as
`Sum` or `Count`, the query `Y >> Each(X >> Count)` is equivalent
to `Y >> Count(X)`. Hence, we could use the combinator form of
`Sum` to do this relative summation.

    unitknot[Lift(1:3) >> Sum(OneTo(It))]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  3 │
    3 │  6 │
    =#

Julia functions taking a vector argument, such as `mean`, can be
lifted to a combinator taking a plural query. When performed, the
plural output is converted into the function's vector argument.

    using Statistics
    Mean(X) = mean.(X)

    unitknot[Mean(Lift(1:3) >> Sum(OneTo(It)))]
    #=>
    │ It      │
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
    │ It      │
    ┼─────────┼
    │ 3.33333 │
    =#

In DataKnots, summary operations are expressed as aggregate query
primitives or as query combinators taking a plural query argument.
Moreover, custom aggregates can be constructed from native Julia
functions and lifted into the query algebra.

## Take

Unlike `Filter` which evaluates its argument for each input
element, the argument to `Take` is evaluated once, and in the
context of the input's *source*.

    unitknot[Lift(1:3) >> Each(Lift('a':'c') >> Take(It))]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ a  │
    3 │ b  │
    4 │ a  │
    5 │ b  │
    6 │ c  │
    =#

In this example, the argument of `Take` evaluates in the context
of `Lift(1:3)`. Therefore, `Take` will be performed three times,
where `It` has the values `1`, `2`, and `3`.

## Group

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
      │ char  data                                 │
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

## Query Parameters

With DataKnots, parameters can be provided so that static data can
be used within query expressions. By convention, we use upper
case, singular labels for query parameters.

    unitknot["Hello " .* Get(:WHO), WHO="World"]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

To make `Get` convenient, `It` provides a shorthand syntax.

    unitknot["Hello " .* It.WHO, WHO="World"]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

Query parameters are available anywhere in the query. They could,
for example be used within a filter.

    query = OneTo(6) >> Filter(It .> It.START)

    unitknot[query, START=3]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  5 │
    3 │  6 │
    =#

Parameters can also be defined as part of a query using `Given`.
This combinator takes set of pairs (`=>`) that map symbols
(`:name`) onto query expressions. The subsequent argument is then
evaluated in a naming context where the defined parameters are
available for reuse.

    unitknot[Given(:WHO => "World", "Hello " .* Get(:WHO))]
    #=>
    │ It          │
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
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  5 │
    3 │  6 │
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
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
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
      │ It    │
    ──┼───────┼
    1 │ Hello │
    2 │ Hello │
    3 │ Hello │
    =#

### Broadcasting over Queries

Broadcasting can be used to convert function calls into query
expressions. For broadcasting to build a query, at least one
argument must be a query.

Even when the argument isn't a query, the result often works
as expected.

    unitknot[iseven.(2)]
    #=>
    │ It   │
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
      │ It │
    ──┼────┼
    1 │ c  │
    2 │ c  │
    3 │ c  │
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
      │ It │
    ──┼────┼
    1 │ h  │
    2 │ b  │
    3 │ v  │
    =#
