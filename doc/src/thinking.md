# Thinking in Combinators

DataKnots is a Julia library for building database queries. In
DataKnots, queries are assembled algebraically: they either come
from a set of atomic *primitives* or are built from other queries
using *combinators*. In this conceptual guide, we show how to
build queries starting from smaller components and then combining
them algebraically to implement complex processing tasks.

To start working with DataKnots, we import the package:

    using DataKnots

## Constructing Queries

A `DataKnot`, or just *knot*, is a container having structured,
vectorized data.

For this guide, we'll use a trivial knot, `void` as our data
source. The `void` knot encapsulates the value `nothing`, which
will serve as the input for our queries.

    void = DataKnot(nothing)
    #=>
    │ It │
    ┼────┼
    │    │
    =#

### Constant Queries

Any Julia value could be converted to a *query* using the `Lift`
constructor. Queries constructed this way are constant: for each
input they receive, they produce the given value.  Consider the
query `Hello`, lifted from the string value `"Hello World"`.

    Hello = Lift("Hello World")

To query `void` with `Hello`, we use indexing notation
`void[Hello]`. In this case, `Hello` receives `nothing` from
`void` and produces the value, `"Hello World"`.

    void[Hello]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

A tuple lifted to a constant query is displayed as a table.

    void[Lift((name="DataKnots", version="0.1"))]
    #=>
    │ name       version │
    ┼────────────────────┼
    │ DataKnots  0.1     │
    =#

A vector lifted to a constant query will produce plural output.

    void[Lift('a':'c')]
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

### Composition & Identity

Two queries can be connected sequentially using the *composition*
combinator (`>>`). Consider the composition, `Lift(1:3) >> Hello`.
Since `Hello` produces a value for each input element, preceding
it with `Lift(1:3)` generates three copies of `"Hello World"`.

    void[Lift(1:3) >> Hello]
    #=>
      │ It          │
    ──┼─────────────┼
    1 │ Hello World │
    2 │ Hello World │
    3 │ Hello World │
    =#

If we compose two plural queries, `Lift(1:2)` and `Lift('a':'c')`,
the output will contain the elements of `'a':'c'` repeated twice.

    void[Lift(1:2) >> Lift('a':'c')]
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

    void[Hello >> It]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

The identity primitive, `It`, can be used to construct queries
which rely upon the output from previous processing.

    Increment = It .+ 1
    void[Lift(1:3) >> Increment]
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

### Julia Functions

Consider the function `double(x)` that, when applied to a
`Number`, produces a `Number`:

    double(x) = 2x
    double(3) #-> 6

What we want is an analogue to `double` which, instead of operating
on numbers, operates on queries. Such functions are called query
*combinators*. We can convert any Julia function to a query
combinator by passing the function and its arguments to `Lift`.

    Double(X) = Lift(double, (X,))

The query `Double(X)` evaluates `X` and then runs its output
through `double`. So, to do nothing but double the current input,
we could write `Double(It)`.

    void[Lift(1:3) >> Double(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Broadcasting a function over a query argument performs a `Lift`
implicitly, building a query component.

    void[Lift(1:3) >> double.(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Any existing function could be broadcast this way. For example, we
could broadcast `getfield` to get a field value from a tuple.

    void[Lift((x=1,y=2)) >> getfield.(It, :y)]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

Getting a field value is common enough to have its own notation.

    void[Lift((x=1,y=2)) >> It.y]
    #=>
    │ y │
    ┼───┼
    │ 2 │
    =#

Implicit lifting also applies to built-in Julia operators (`+`)
and values (`1`). The expression `It .+ 1` is a query component
that increments each of its input elements.

    void[Lift(1:3) >> (It .+ 1)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  3 │
    3 │  4 │
    =#

One can also define combinators as query expressions. However, be
sure to cast each argument using `Lift`.

    OneTo(N) = UnitRange.(1, Lift(N))

Note that the unit range constructor is vector-valued. Therefore,
the resulting combinator builds queries with plural output.

    void[OneTo(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

When Julia values and functions are lifted, the type signature is
inspected to discover how it should interact with query's flow. A
flow is *singular* if it could have at most one element; else, it
is *plural*. Furthermore, if a flow must have at least one element
then it is *mandatory*; else, it is *optional*.

| Type                | Singular | Mandatory |
|---------------------|----------|-----------|
| `Vector{T}`         | No       | No        |
| `Union{T, Missing}` | Yes      | No        |
| `{T}`               | Yes      | Yes       |

This conversion lets us access Julia's rich statistical and data
processing functions from our queries.

## Query Combinators

There are query operations which cannot be lifted from Julia
functions. We've met a few already, including the identity (`It`)
and query composition (`>>`). There are many others involving
aggregation, filtering, and paging.

### Aggregate Queries

So far queries have been *elementwise*; that is, for each input
element, they produce zero or more output elements. Consider the
`Count` primitive; it returns the number of its input elements.

    void[OneTo(3) >> Count]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

An *aggregate* query such as `Count` is relative to the input as a
whole, even if it might consider input elements. Let's consider
the query `OneTo(3) >> OneTo(It)`.

    void[OneTo(3) >> OneTo(It)]
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

By simply appending `>> Sum` we could aggregate the input.

    void[OneTo(3) >> OneTo(It) >> Sum]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

What if we wanted to produce sums by the outer query, `OneTo(3)`?
Since query composition (`>>`) is associative, adding parenthesis
around `OneTo(It) >> Sum` will not change the result.

    void[OneTo(3) >> (OneTo(It) >> Sum)]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

We need the `Each` combinator, which acts as an elementwise
*barrier*.  For each input element, `Each` evaluates its argument;
and then, it then collects the outputs.

    void[OneTo(3) >> Each(OneTo(It) >> Sum)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  3 │
    3 │  6 │
    =#

Following is an equivalent query, using the `Sum` combinator.
While `Sum(X)` performs a numerical aggregation, it is not an
aggregate query since it treats its input elementwise.

    void[OneTo(3) >> Sum(OneTo(It))]
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
    void[Mean(OneTo(3) >> Sum(OneTo(It)))]
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

    void[Lift(1:3) >> Sum(OneTo(It)) >> Mean]
    #=>
    │ It      │
    ┼─────────┼
    │ 3.33333 │
    =#

In DataKnots, summary operations are expressed as aggregate query
primitives or as query combinators taking a plural query argument.
Moreover, custom aggregates can be constructed from native Julia
functions and lifted into the query algebra.

### Filtering

The `Filter` combinator has one parameter, a predicate query that,
for each input element, decides if this element should be included
in the output.

    void[OneTo(6) >> Filter(It .> 3)]
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
    void[OneTo(6) >> KeepEven]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Filter can work in a nested context.

    void[Lift(1:3) >> Filter(Sum(OneTo(It)) .> 5)]
    #=>
      │ It │
    ──┼────┼
    1 │  3 │
    =#

The `Filter` combinator is elementwise. That is, its arguments are
evaluated for each input element. If the predicate is `true`, then
that element is reproduced, otherwise it is discarded.

### Paging Data

Like `Filter`, the `Take` and `Drop` combinators can be used to
choose elements from an input: `Drop` is used to skip over input,
while `Take` ignores input past a particular point.

    void[OneTo(9) >> Drop(3) >> Take(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  5 │
    3 │  6 │
    =#

Unlike `Filter`, the argument to `Take` is evaluated once, in the
context of the input's *origin*. In this next example, `Take` is
performed three times. Each time, `It` refers to the integer
elements of the outer loop, `OneTo(3)`.

    void[OneTo(3) >> Each(Lift('a':'c') >> Take(It))]
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

How do we grab the 1st half of an input stream? Let's define
`FirstHalf` as a combinator that builds a query returning the
first half of an input stream.

    FirstHalf(X) = Each(X >> Take(Count(X) .÷ 2))
    void[FirstHalf(OneTo(6))]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

We could construct and register a `FirstHalf` query primitive.

    DataKnots.Lift(::typeof(FirstHalf)) = DataKnots.Then(FirstHalf)

    void[OneTo(6) >> FirstHalf]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

Paging operations highlight a diversity of query operations. When
a query processes its input an element at a time, we call it
*elementwise*; else, it is *aggregate*. Further, when the argument
of a combinator uses the input's origin, we call it
*origin-aware*.

| Query       | Elementwise | Origin-Aware |
|-------------|-------------|--------------|
| `Count`     | No          | No           |
| `Take(N)`   | No          | Yes          |
| `Count(X)`  | Yes         | No           |
| `Filter(P)` | Yes         | No           |

Since both `Filter` and `Count` combinators are elementwise and
not origin-aware, they behave in quite similar ways. Conversely,
the `Take` combinator behaves more like the `Count` aggregate,
with its argument being origin-aware.

## Structuring Data

Thus far we've seen how queries can be composed in heavily nested
environments. DataKnots also supports nested data and contexts.

### Records & Labels

Data objects can be created using the `Record` combinator. Values
can be labeled using Julia's `Pair` syntax. The entire result as a
whole may also be named.

    GM = Record(:name => "GARRY M", :salary => 260004)
    void[GM]
    #=>
    │ name     salary │
    ┼─────────────────┼
    │ GARRY M  260004 │
    =#

Field access is possible via `Get` query constructor, which takes
a label's name. Here `Get(:name)` is an elementwise query that
returns the value of a given label when found.

    void[GM >> Get(:name)]
    #=>
    │ name    │
    ┼─────────┼
    │ GARRY M │
    =#

For syntactic convenience, `It` can be used for dotted access.

    void[GM >> It.name]
    #=>
    │ name    │
    ┼─────────┼
    │ GARRY M │
    =#

The `Label` combinator provides a name to any expression.

    void[Lift("Hello World") >> Label(:greeting)]
    #=>
    │ greeting    │
    ┼─────────────┼
    │ Hello World │
    =#

Alternatively, Julia's pair constructor (`=>`) and and a `Symbol`
denoted by a colon (`:`) can be used to label an expression.

    Hello =
      :greeting => Lift("Hello World")

    void[Hello]
    #=>
    │ greeting    │
    ┼─────────────┼
    │ Hello World │
    =#

Records can be plural. Here is a table of obvious statistics.

    Stats = Record(:n¹=>It, :n²=>It.*It, :n³=>It.*It.*It)
    void[Lift(1:3) >> Stats]
    #=>
      │ n¹  n²  n³ │
    ──┼────────────┼
    1 │  1   1   1 │
    2 │  2   4   8 │
    3 │  3   9  27 │
    =#

By accessing names, calculations can be performed on records.

    void[Lift(1:3) >> Stats >> (It.n¹ .+ It.n² .+ It.n³)]
    #=>
      │ It │
    ──┼────┼
    1 │  3 │
    2 │ 14 │
    3 │ 39 │
    =#

Using records, it is possible to represent complex, hierarchical
data. It is then possible to access and compute with this data.

### Query Parameters

With DataKnots, parameters can be provided so that static data can
be used within query expressions. By convention, we use upper
case, singular labels for query parameters.

    void["Hello " .* Get(:WHO), WHO="World"]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

To make `Get` convenient, `It` provides a shorthand syntax.

    void["Hello " .* It.WHO, WHO="World"]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

Query parameters are available anywhere in the query. They could,
for example be used within a filter.

    query = OneTo(6) >> Filter(It .> It.START)
    void[query, START=3]
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

    void[Given(:WHO => "World", "Hello " .* Get(:WHO))]
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

    void[GreaterThanAverage(OneTo(6))]
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

## Working With Data

Arrays of named tuples can be wrapped with `Lift` in order to
provide a series of tuples. Since DataKnots works fluidly with
Julia, any sort of Julia object may be used. In this case,
`NamedTuple` has special support so that it prints well.

    DATA = Lift([(name = "GARRY M", salary = 260004),
                  (name = "ANTHONY R", salary = 185364),
                  (name = "DANA A", salary = 170112)])

    void[:staff => DATA]
    #=>
      │ staff             │
      │ name       salary │
    ──┼───────────────────┼
    1 │ GARRY M    260004 │
    2 │ ANTHONY R  185364 │
    3 │ DANA A     170112 │
    =#

Access to slots in a `NamedTuple` is also supported by `Get`.

    void[DATA >> Get(:name)]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ GARRY M   │
    2 │ ANTHONY R │
    3 │ DANA A    │
    =#

Together with previous combinators, DataKnots could be used to
create readable queries, such as "who has the greatest salary"?

    void[:highest_salary =>
      Given(:MAX => Max(DATA >> It.salary),
            DATA >> Filter(It.salary .== Get(:MAX)))]
    #=>
      │ highest_salary  │
      │ name     salary │
    ──┼─────────────────┼
    1 │ GARRY M  260004 │
    =#

Records can even contain lists of subordinate records.

    DB =
      void[:department =>
        Record(:name => "FIRE", :staff => It.FIRE),
        FIRE=[(name = "JOSE S", salary = 202728),
              (name = "CHARLES S", salary = 197736)]]
    #=>
    │ department                              │
    │ name  staff                             │
    ┼─────────────────────────────────────────┼
    │ FIRE  JOSE S, 202728; CHARLES S, 197736 │
    =#

These subordinate records can then be summarized.

    void[:statistics =>
      DB >> Record(:dept => It.name,
                   :count => Count(It.staff))]
    #=>
    │ statistics  │
    │ dept  count │
    ┼─────────────┼
    │ FIRE      2 │
    =#

## Quirks & Hints

By *quirks* we mean perhaps unexpected consequences of embedding
DataKnots in Julia or deviations from how other languages work.
They are not necessarily bugs, nor could they be easily fixed.

The query `Count` is not the same as the query `Count(It)`. The
former is an aggregate that consumes its entire input, the latter
is an elementwise query that considers one input a time. Since it
could only receive one input element at a time, `Count(It)` is
always `1`. This is clearly less than ideal.

    void[OneTo(3) >> Count(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  1 │
    3 │  1 │
    =#

The `Count` aggregate only considers the number of elements in the
input. It does not check for values that are truthy.

    void[OneTo(5) >> iseven.(It) >> Count]
    #=>
    │ It │
    ┼────┼
    │  5 │
    =#

    void[OneTo(5) >> Filter(iseven.(It)) >> Count]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

Using the broadcast syntax to lift combinators is clever, but it
doesn't always work out. If an argument to the broadcast isn't a
`Query` then a regular broadcast will happen. For example,
`rand.(1:3)` is an array of arrays containing random numbers.
Wrapping an argument in `Lift` will address this challenge.

    using Random: seed!, rand
    seed!(0)
    void[Lift(1:3) >> rand.(Lift(7:9))]
    #=>
      │ It │
    ──┼────┼
    1 │  7 │
    2 │  9 │
    3 │  8 │
    =#

