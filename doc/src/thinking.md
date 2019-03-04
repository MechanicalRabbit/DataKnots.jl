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
vectorized data. For this conceptual guide, we'll start with a
trivial knot, `void` as our initial data source.

    void = DataKnot(nothing)
    #=>
    │ It │
    ┼────┼
    │    │
    =#

This `void` knot has a single value, `nothing`, displayed as a
empty output cell. The underlying value of a knot can be obtained
using the `get()` function; and here, we get `nothing`.

    show(get(void))
    #-> nothing

### Constant Queries

Consider a *constant* query `Hello` that outputs a string value,
`"Hello World"`. We use `Lift` to construct constant queries.

    Hello = Lift("Hello World")

To query `void` with `Hello` we use Julia's `getindex` syntax.

    void[Hello]
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

Consider another query, `Twos`, created by applying `Lift` to a
vector having two values, `"One"` and `"Two"`. When we query
`void` with `Twos` query we get two outputs. 

    Twos = Lift(["One","Two"])
    void[Twos]
    #=>
      │ It  │
    ──┼─────┼
    1 │ One │
    2 │ Two │
    =#

In the context of a query invocation, `Lift` syntax can often be
removed, permitting us to write queries more informally:

    void["Howdy!"]
    #=>
    │ It     │
    ┼────────┼
    │ Howdy! │
    =#

When `void` is queried with the unit range `5:7`, the output
includes values `5` though `7`.

    void[5:7]
    #=>
      │ It │
    ──┼────┼
    1 │  5 │
    2 │  6 │
    3 │  7 │
    =#

There is one specific value of note, `missing`.  The output of
querying `void` with `missing` provides an empty knot.

    void[missing]
    #=>
    │ It │
    ┼────┼
    =#

DataKnots track cardinality. If a knot has at most one value, we
say that it is *singular*, else, it is *plural*. In the output of
plural knots, indices are in the first column and values are in
remaining columns.

### Composition & Identity

Two queries can be connected sequentially using the composition
combinator (`>>`). Consider the composition `Lift(1:3) >> Hello`.
Since `Lift(1:3)` emits 3 values and `Hello` emits `"Hello World"`
for each of its inputs, their composition emits 3 copies of
`"Hello World"`.

    void[Lift(1:3) >> Hello]
    #=>
      │ It          │
    ──┼─────────────┼
    1 │ Hello World │
    2 │ Hello World │
    3 │ Hello World │
    =#

When queries that produce plural output are combined, the output
is flattened into a single sequence. The following expression
calculates `Lift(7:9)` twice and then flattens the output.

    void[Lift(1:2) >> Lift(7:9)]
    #=>
      │ It │
    ──┼────┼
    1 │  7 │
    2 │  8 │
    3 │  9 │
    4 │  7 │
    5 │  8 │
    6 │  9 │
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

The identity, `It`, can be used to construct queries which rely
upon the output from previous processing.

    Increment = It .+ 1
    void[Lift(1:3) >> Increment]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  3 │
    3 │  4 │
    =#

In DataKnots, queries are built algebraically, using query
composition, identity and other combinators. This lets us define
sophisticated query components and remix them in creative ways.

### Lifting Julia Functions

With DataKnots, any native Julia expression can be *lifted* to
build a `Query`. Consider the Julia function `double()` that, when
applied to a `Number`, produces a `Number`:

    double(x) = 2x
    double(3) #-> 6

What we want is an analogue to `double` that, instead of operating
on numbers, operates on queries. Such functions are called query
combinators. We can convert any Julia function to a query
combinator by passing the function and its arguments to `Lift`.

    Double(X) = Lift(double, (X,))

When given an argument, the combinator `Double` can then be used
to build a query that produces a doubled value.

    void[Double(21)]
    #=>
    │ It │
    ┼────┼
    │ 42 │
    =#

In combinator form, `Double` can be used within query composition.
To build a query component that doubles its input, the `Double`
combinator could have `It` as its argument.

    void[Lift(1:3) >> Double(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Since this use of native Julia functions as combinators is common
enough, Julia's *broadcast* syntax (using a period) is overloaded
to make translation convenient. Any native Julia function, such as
`double`, can be used as a combinator as follows:

    void[Lift(1:3) >> double.(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Automatic lifting also applies to built-in Julia operators. For
example, the expression `It .+ 1` is a query component that
increments each one of its input values.

    void[Lift(1:3) >> (It .+ 1)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  3 │
    3 │  4 │
    =#

One can define combinators in terms of expressions.

    OneTo(N) = UnitRange.(1, Lift(N))

When a lifted function is vector-valued, the resulting combinator
builds plural queries.

    void[OneTo(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

In DataKnots, query combinators can be constructed directly from
native Julia functions. This lets us take advantage of Julia's
rich statistical and data processing functions.

### Aggregates

Some query combinators transform a plural query into a singular
query; we call them *aggregate* combinators. Consider the
operation of the `Count` combinator.

    void[Count(OneTo(3))]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

As a convenience, `Count` can also be used as a query primitive.

    void[OneTo(3) >> Count]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

It's possible to use aggregates within a plural query. In this
example, as the outer `OneTo` goes from `1` to `3`, the `Sum`
aggregate would calculate its output from `OneTo(1)`, `OneTo(2)`
and `OneTo(3)`.

    void[OneTo(3) >> Sum(OneTo(It))]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  3 │
    3 │  6 │
    =#

However, if we rewrite the query to use `Sum` as a query
primitive, we get a different result.

    void[OneTo(3) >> OneTo(It) >> Sum]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

Since query composition (`>>`) is associative, adding parenthesis
around `OneTo(It) >> Sum` will not change the result.

    void[OneTo(3) >> (OneTo(It) >> Sum)]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

Instead of using parenthesis, we need to wrap `OneTo(It) >> Sum`
with the `Each` combinator. This combinator builds a query that
processes its input *elementwise*.

    void[OneTo(3) >> Each(OneTo(It) >> Sum)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  3 │
    3 │  6 │
    =#

Native Julia language aggregates, such as `mean`, can be easily
lifted. DataKnots automatically converts a plural query into an
input vector required by the native aggregate.

    using Statistics
    Mean(X) = Lift(mean, (X,))
    void[Mean(OneTo(3) >> Sum(OneTo(It)))]
    #=>
    │ It      │
    ┼─────────┼
    │ 3.33333 │
    =#

To use `Mean` as a query primitive, there are two steps. First, we
use `Then` to build a query that aggregates from its input.
Second, we register a `Lift` to this query when the combinator's
name is mentioned in a query expression.

    DataKnots.Lift(::typeof(Mean)) = DataKnots.Then(Mean)

Once these are done, one could take an average of sums as follows:

    void[Lift(1:3) >> Sum(OneTo(It)) >> Mean]
    #=>
    │ It      │
    ┼─────────┼
    │ 3.33333 │
    =#

In DataKnots, aggregate operations are naturally expressed as
query combinators. Moreover, custom aggregates can be easily
constructed as native Julia functions and lifted into the query
algebra.

## Filtering & Slicing Data

DataKnots comes with combinators for rearranging data. Consider
`Filter`, which takes one parameter, a predicate query that for
each input value decides if that value should be included in the
output.

    void[OneTo(6) >> Filter(It .> 3)]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  5 │
    3 │  6 │
    =#

Contrast this with the built-in Julia function `filter()`.

    filter(x -> x > 3, 1:6) #-> [4, 5, 6]

Where `filter()` returns a filtered dataset, the `Filter`
combinator returns a query component, which could then be composed
with any data generating query.

    KeepEven = Filter(iseven.(It))
    void[OneTo(6) >> KeepEven]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Similar to `Filter`, the `Take` and `Drop` combinators can be used
to slice an input stream: `Drop` is used to skip over input,
`Take` ignores output past a particular point.

    void[OneTo(9) >> Drop(3) >> Take(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  5 │
    3 │  6 │
    =#

Since `Take` is a combinator, its argument could also be a full
blown query. This next example, `FirstHalf` is a combinator that
builds a query returning the first half of an input stream.

    FirstHalf(X) = Each(X >> Take(Count(X) .÷ 2))
    void[FirstHalf(OneTo(6))]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

Using `Then`, this combinator could be used as a query primitive.

    DataKnots.Lift(::typeof(FirstHalf)) = DataKnots.Then(FirstHalf)
    void[OneTo(6) >> FirstHalf]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

In DataKnots, filtering and slicing are realized as query
components. They are attached to data processing queries using the
composition combinator. This brings common data processing
concepts into our query algebra.

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

### Records & Labels

Internally, DataKnots use a column-oriented storage mechanism that
handles hierarchies and graphs. Data objects in this model can be
created using the `Record` combinator.

    GM = Record(:name => "GARRY M", :salary => 260004)
    void[GM]
    #=>
    │ name     salary │
    ┼─────────────────┼
    │ GARRY M  260004 │
    =#

Field access is also possible via `Get` or via the `It` shortcut.

    void[GM >> It.name]
    #=>
    │ name    │
    ┼─────────┼
    │ GARRY M │
    =#

As seen in the output above, field names also act as display
labels. It is possible to provide a name to any expression with
the `Label` combinator. Labeling doesn't affect the actual output,
only the field name given to the expression and its display.

    void[Lift("Hello World") >> Label(:greeting)]
    #=>
    │ greeting    │
    ┼─────────────┼
    │ Hello World │
    =#

Alternatively, Julia's pair constructor (`=>`) and and a `Symbol`
denoted by a colon (`:`) can be used to label an expression.

    Hello = :greeting => Lift("Hello World")
    void[Hello]
    #=>
    │ greeting    │
    ┼─────────────┼
    │ Hello World │
    =#

When a record is created, it can use the label from which it
originates. In this case, the `:greeting` label from the `Hello`
is used to make the field label used within the `Record`. The
record itself is also expressly labeled.

    void[:seasons => Record(Hello)]
    #=>
    │ seasons     │
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

Calculations could be performed on record sets as follows:

    void[Lift(1:3) >> Stats >> (It.n² .+ It.n³)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │ 12 │
    3 │ 36 │
    =#

Any values can be used within a Record, including other records
and plural values.

    void[:work_schedule =>
     Record(:staff => Record(:name => "Jim Rockford",
                             :phone => "555-2368"),
            :workday => Lift(["Su", "M","Tu", "F"]))]
    #=>
    │ work_schedule                        │
    │ staff                   workday      │
    ┼──────────────────────────────────────┼
    │ Jim Rockford, 555-2368  Su; M; Tu; F │
    =#

In DataKnots, records are used to generate tabular data. Using
nested records, it is possible to represent complex, hierarchical
data.

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

## Quirks

By *quirks* we mean unexpected consequences of embedding DataKnots
in Julia. They are not necessarily bugs, nor could they be easily
fixed.

Using the broadcast syntax to lift combinators is a clever
shortcut, but it doesn't always work out. If an argument to the
broadcast isn't a `Query` then a regular broadcast will happen.
For example, `rand.(1:3)` is an array of arrays containing random
numbers. Wrapping an argument in `Lift` will address this
challenge. The following will generate 3 random numbers from `1`
to `3`.

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

