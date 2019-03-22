# Primer

DataKnots is a Julia library for building database queries. In
DataKnots, queries are assembled algebraically: they either come
from a set of atomic *primitives* or are built from other queries
using *combinators*. This is a conceptual guide.

To start working with DataKnots, we import the package:

    using DataKnots

## The Unit Knot

A `DataKnot`, or just *knot*, is a container having structured,
vectorized data. The `unitknot` is a trivial knot used as the
starting point for constructing other knots.

    unitknot
    #=>
    │ It │
    ┼────┼
    │    │
    =#

The unit knot has a single value, `nothing`. You could get the
value of any knot using Julia's `get` function.

    show(get(unitknot))
    #-> nothing

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

We call queries constructed this way *primitives*, as they do not
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

Any function could be integrated into a DataKnots query. Consider
the function `double(x)` that, when applied to a `Number`,
produces a `Number`:

    double(x) = 2x
    double(3) #-> 6

What we want is an analogue to `double` which, instead of
operating on numbers, operates on queries. Such functions are
called query *combinators*. We can convert any function to a
combinator by passing the function and its arguments to `Lift`.

    Double(X) = Lift(double, (X,))

In this case, `double` expects a scalar value. Therefore, for a
query `X`, the combinator `Double(X)` evaluates `X` and then runs
each output element though `double`. Thus, the query `Double(It)`
would simply double its input.

    unitknot[Lift(1:3) >> Double(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Broadcasting a function over a query argument performs a `Lift`
implicitly, building a query component.

    unitknot[Lift(1:3) >> double.(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Any existing function could be broadcast this way. For example, we
could broadcast `getfield` to get a field value from a tuple.

    unitknot[Lift((x=1,y=2)) >> getfield.(It, :y)]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

Getting a field value is common enough to have its own notation,
properties of `It`, such as `It.y`, are used for field access.

    unitknot[Lift((x=1,y=2)) >> It.y]
    #=>
    │ y │
    ┼───┼
    │ 2 │
    =#

Implicit lifting also applies to built-in Julia operators (`+`)
and values (`1`). The expression `It .+ 1` is a query component
that increments each of its input elements.

    unitknot[Lift(1:3) >> (It .+ 1)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  3 │
    3 │  4 │
    =#

In Julia, broadcasting lets the function's arguments control how
the function is applied. When a function is broadcasted over
queries, the result is a query. However, to make sure it works, we
need to ensure that at least one argument is a query, and we can
do this by wrapping at least one argument with `Lift`.

    OneTo(N) = UnitRange.(1, Lift(N))

Note that the unit range constructor is vector-valued. Therefore,
the resulting combinator builds queries with plural output.

    unitknot[OneTo(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

This automated lifting lets us access rich statistical and data
processing functions from within our queries.

## Aggregate Queries

There are query operations which cannot be lifted from Julia
functions. We've met a few already, including the identity (`It`)
and query composition (`>>`). There are many others involving
aggregation, filtering, and paging.

So far queries have been *elementwise*; that is, for each input
element, they produce zero or more output elements. Consider the
`Count` primitive; it returns the number of its input elements.

    unitknot[OneTo(3) >> Count]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

An *aggregate* query such as `Count` is computed over the input as
a whole, and not for each individual element. The semantics of
aggregates require discussion. Consider `OneTo(3) >> OneTo(It)`.

    unitknot[OneTo(3) >> OneTo(It)]
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

    unitknot[OneTo(3) >> OneTo(It) >> Sum]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

What if we wanted to produce sums by the outer query, `OneTo(3)`?
Since query composition (`>>`) is associative, adding parenthesis
around `OneTo(It) >> Sum` will not change the result.

    unitknot[OneTo(3) >> (OneTo(It) >> Sum)]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

We need the `Each` combinator, which acts as an elementwise
*barrier*. For each input element, `Each` evaluates its argument,
and then collects the outputs.

    unitknot[OneTo(3) >> Each(OneTo(It) >> Sum)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  3 │
    3 │  6 │
    =#

Following is an equivalent query, using the `Sum` combinator.
Here, `Sum(X)` produces the same output as `Each(X >> Sum)`.
Although `Sum(X)` performs numerical aggregation, it is not an
aggregate query since its input is treated elementwise.

    unitknot[OneTo(3) >> Sum(OneTo(It))]
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
    unitknot[Mean(OneTo(3) >> Sum(OneTo(It)))]
    #=>
    │ It      │
    ┼─────────┼
    │ 3.33333 │
    =#

To use `Mean` as a query primitive, we use `Then` to build a query
that aggregates elements from its input. Next, we register this
query so it is used when `Mean` is treated as a query.

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

## Filtering

The `Filter` combinator has one parameter, a predicate query that,
for each input element, decides if this element should be included
in the output.

    unitknot[OneTo(6) >> Filter(It .> 3)]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  5 │
    3 │  6 │
    =#

Being a combinator, `Filter` builds a query component, which could
then be composed with any data generating query.

    KeepEven = Filter(iseven.(It))
    unitknot[OneTo(6) >> KeepEven]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Filter can work in a nested context.

    unitknot[Lift(1:3) >> Filter(Sum(OneTo(It)) .> 5)]
    #=>
      │ It │
    ──┼────┼
    1 │  3 │
    =#

The `Filter` combinator is elementwise. Furthermore, the predicate
argument is evaluated for each input element. If the predicate
evaluation is `true` for a given element, then that element is
reproduced, otherwise it is discarded.

## Paging Data

Like `Filter`, the `Take` and `Drop` combinators can be used to
choose elements from an input: `Drop` is used to skip over input,
while `Take` ignores input past a particular point.

    unitknot[OneTo(9) >> Drop(3) >> Take(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  5 │
    3 │  6 │
    =#

Unlike `Filter`, which evaluates its argument for each element,
the argument to `Take` is evaluated once, in the context of the
input's *source*.

    unitknot[OneTo(3) >> Each(Lift('a':'c') >> Take(It))]
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
of `OneTo(3)`. Therefore, `Take` will be performed three times,
where `It` has the values `1`, `2`, and `3`.

## Records & Labels

Data objects can be created using the `Record` combinator. Values
can be labeled using Julia's `Pair` syntax. The entire result as a
whole may also be named.

    GM = Record(:name => "GARRY M", :salary => 260004)
    unitknot[GM]
    #=>
    │ name     salary │
    ┼─────────────────┼
    │ GARRY M  260004 │
    =#

Field access is possible via `Get` query constructor, which takes
a label's name. Here `Get(:name)` is an elementwise query that
returns the value of a given label when found.

    unitknot[GM >> Get(:name)]
    #=>
    │ name    │
    ┼─────────┼
    │ GARRY M │
    =#

For syntactic convenience, `It` can be used for dotted access.

    unitknot[GM >> It.name]
    #=>
    │ name    │
    ┼─────────┼
    │ GARRY M │
    =#

The `Label` combinator provides a name to any expression.

    unitknot[Lift("Hello World") >> Label(:greeting)]
    #=>
    │ greeting    │
    ┼─────────────┼
    │ Hello World │
    =#

Alternatively, Julia's pair constructor (`=>`) and and a `Symbol`
denoted by a colon (`:`) can be used to label an expression.

    Hello =
      :greeting => Lift("Hello World")

    unitknot[Hello]
    #=>
    │ greeting    │
    ┼─────────────┼
    │ Hello World │
    =#

Records can be used to make tables. Here are some statistics.

    Stats = Record(:n¹=>It, :n²=>It.*It, :n³=>It.*It.*It)
    unitknot[Lift(1:3) >> Stats]
    #=>
      │ n¹  n²  n³ │
    ──┼────────────┼
    1 │  1   1   1 │
    2 │  2   4   8 │
    3 │  3   9  27 │
    =#

By accessing names, calculations can be performed on records.

    unitknot[Lift(1:3) >> Stats >> (It.n¹ .+ It.n² .+ It.n³)]
    #=>
      │ It │
    ──┼────┼
    1 │  3 │
    2 │ 14 │
    3 │ 39 │
    =#

Using records, it is possible to represent complex, hierarchical
data. It is then possible to access and compute with this data.

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

In DataKnots, query parameters permit external data to be used
within query expressions. Parameters that are defined with `Given`
can be used to remember values and reuse them.
