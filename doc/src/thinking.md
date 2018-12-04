# Thinking in DataKnots

DataKnots are a Julia library for working with computational pipelines.
Each `DataKnot` is a container holding structured, often interrelated,
vectorized data. Each `Pipeline` can be seen as a data knot
transformation. Pipelines are assembled algebraically using pipeline
*primitives*, which represent relationships among data, and
*combinators*, which encapsulate logic.

To start working with DataKnots, we import the package:

    using DataKnots

## Constructing Pipelines

Consider a pipeline `Hello` that produces a `DataKnot` containing a
string value, `"Hello World"`. It is built using the `Const` primitive,
which converts a Julia string value into a pipeline component. This
pipeline can then be `run()` to produce its output.

    Hello = Const("Hello World")
    run(Hello)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

Consider another pipeline, `Range(3)`. It is built with the `Range`
combinator. When `run()`, it emits a sequence of integers from `1`
to `3`.

    run(Range(3))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        2 │
    3 │        3 │
    =#

Observe that `Hello` pipeline produces a *singular* value, while the
`Range(3)` pipeline is *plural*. In the output notation for plural
knots, indices are in the first column with values in remaining columns.

### Composition & Identity

With DataKnots, composition with independently developed data
processing components is straightforward. Two pipelines could be
connected using the composition combinator `>>`. Since the constant
`Hello` pipeline does not depend upon its input, the composition
`Range(3) >> Hello` would emit 3 copies of `"Hello World"`.

    run(Range(3) >> Hello)
    #=>
      │ DataKnot    │
    ──┼─────────────┤
    1 │ Hello World │
    2 │ Hello World │
    3 │ Hello World │
    =#

The *identity* with respect to pipeline composition is called `It`.
This primitive can be composed with any pipeline without changing the
pipeline's output.

    run(Hello >> It)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

The identity, `It`, can be used to construct pipelines which rely upon
the output from previous processing. For example, one could define a
pipeline `Increment` as `It .+ 1`.

    Increment = It .+ 1
    run(Range(3) >> Increment)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

When pipelines that produce plural values are combined, the output is
flattened into a single sequence. The following expression calculates
`Range(1)`, `Range(2)` and `Range(3)` and then merges the outputs.

    run(Range(3) >> Range(It))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        1 │
    3 │        2 │
    4 │        1 │
    5 │        2 │
    6 │        3 │
    =#

In DataKnots, pipelines are built algebraically, using pipeline
composition, identity and other combinators. This lets us define
sophisticated pipeline components and remix them in creative ways.

### Lifting Julia Functions

With DataKnots, any native Julia expression can be lifted so that it
could be used to build a `Pipeline`. Consider the Julia function
`double()` that, when applied to a `Number`, produces a `Number`:

    double(x) = 2x
    double(3) #-> 6

What we want is an analogue to `double` that, instead of operating on
numbers, operates on pipelines. Such functions are called pipeline
combinators. We can convert any Julia function to a pipeline
`Combinator` as follows:

    Double(X) = Combinator(double)(X)

When given an argument, the combinator `Double` can then be used to
build a pipeline that produces the doubled value.

    run(Double(21))
    #=>
    │ DataKnot │
    ├──────────┤
    │       42 │
    =#

If the argument to the combinator is plural, than the pipeline
constructed is also plural. When `run()` the following pipeline first
evaluates the argument, `Range(3)` to produce three input values.
These values are then passed though the underlying function, `double`.
The results are then collected and converted into a plural output knot.

    run(Double(Range(3)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

Sometimes it's handy to use pipeline composition, rather than passing
by combinator arguments. To build a pipeline component that doubles its
input, the `Double` combinator could use `It` as its argument. This
pipeline could then later be reused with various inputs.

    ThenDouble = Double(It)
    run(Range(3) >> ThenDouble)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

Since this lifting operation is common enough, Julia's *broadcast*
syntax (using a period) is overloaded to make simple lifting easy.
Any scalar function can be used as a combinator as follows:

    run(double.(Range(3)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

DataKnots' automatic lifting also applies to built-in Julia operators.
In this example, the expression `It .+ 1` is a pipeline component that
increments each one of its input values.

    run(Range(3) >> It .+ 1)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

When a Julia function returns a vector, a lifted combinator creates
pipelines having plural output. In fact, the `Range` combinator used in
these examples could be created as follows:

```julia
Range(X) = Combinator(Range, x -> 1:x)(X)
```

In DataKnots, pipeline combinators can be constructed directly from
native Julia functions. This lets us take advantage of Julia's rich
statistical and data processing functions.

### Aggregates

Some pipeline combinators transform a plural pipeline into a singular
pipeline; we call them *aggregate* combinators. Consider the pipeline,
`Count(Range(3))`. It is built by applying the `Count` combinator to
the `Range(3)` pipeline. It outputs a singular value `3`, the number of
entries produced by `Range(3)`.

    run(Count(Range(3)))
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

`Count` can also be used as a pipeline primitive.

    run(Range(3) >> Count)
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

It's possible to use aggregates within a plural pipeline. In this
example, as the outer `Range` goes from `1` to `3`, the `Sum` aggregate
would calculate its output from `Range(1)`, `Range(2)` and `Range(3)`.

    run(Range(3) >> Sum(Range(It)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        3 │
    3 │        6 │
    =#

However, if we rewrite the pipeline to use `Sum` as a pipeline
primitive, we get a different result.

    run(Range(3) >> Range(It) >> Sum)
    #=>
    │ DataKnot │
    ├──────────┤
    │       10 │
    =#

Since pipeline composition (`>>`) is associative, just adding
parenthesis around `Range(It) >> Sum` would not change the result.

    run(Range(3) >> (Range(It) >> Sum))
    #=>
    │ DataKnot │
    ├──────────┤
    │       10 │
    =#

Instead of using parenthesis, we need to wrap `Range(It) >> Sum` with
the `Each` combinator. This combinator builds a pipeline that processes
its input elementwise.

    run(Range(3) >> Each(Range(It) >> Sum))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        3 │
    3 │        6 │
    =#

Like scalar functions, aggregates can be lifted to *Combinator* form
with the `aggregate=true` keyword argument. This constructor produces
an aggregate combinator that operates on an incoming pipeline. For
example, the `Mean` aggregate combinator could be defined as:

    using Statistics
    Mean(X) = Combinator(Mean, mean, aggregate=true)(X)

Then, one could create a mean of sums as follows:

    run(Mean(Range(3) >> Sum(Range(It))))
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ 3.333333335 │
    =#

To use `Mean` as a pipeline primitive, there are two additional steps.
First, a zero-argument version is required, `Mean()`. Second, an
automatic conversion of the symbol `Mean` to a pipeline is required.
The former is done by `Then`, the latter by Julia's built-in `convert`.

    Mean() = Then(Mean)
    convert(::Type{Pipeline}, ::typeof(Mean)) = Mean()

Once these are done, one could take the sum of means as follows:

    run(Range(3) >> Sum(Range(It)) >> Mean)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ 3.333333335 │
    =#

In DataKnots, aggregate operations are naturally expressed as pipeline
combinators and do not need explicit grouping. Nested aggregation just
works. Moreover, custom aggregates can be easily constructed as native
Julia functions and lifted into the query language.

## Filtering & Paging

Unsurprisingly, data filtering and paging of DataKnots' pipelines are
also done with *combinators*. The `Filter` combinator takes one
parameter, a predicate pipeline that for each input decides whether it
should be included in the output.

    run(Range(6) >> Filter(It .> 3))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        4 │
    2 │        5 │
    3 │        6 │
    =#

The `Take` and `Drop` combinators can be used to slice an input stream:
`Drop` is used to skip over input, `Take` ignores output past a
particular point.

    run(Range(9) >> Drop(3) >> Take(3))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        4 │
    2 │        5 │
    3 │        6 │
    =#

Sometimes it's helpful to encapsulate filter logic as a `Pipeline`
component so it could be reused. Consider `KeepEven` that would keep
only even values.

    KeepEven = Filter(iseven.(It))
    run(Range(6) >> KeepEven)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

Since `Take` is a combinator, its argument could also be a full blown
pipeline. This next example, `FirstHalf` is a combinator that builds a
pipeline returning the first half of an input stream.

    FirstHalf(X) = Each(X >> Take(Count(X) .÷ 2))
    run(FirstHalf(Range(6)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        2 │
    3 │        3 │
    =#

Using `Then`, this combinator could be used with pipeline composition:

    run(Range(6) >> Then(FirstHalf))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        2 │
    3 │        3 │
    =#

The `TakeFirst` combinator is similar to `Take(1)`, only that it
returns a singular, rather than plural knot.

    run(Range(3) >> TakeFirst())
    #=>
    │ DataKnot │
    ├──────────┤
    │        1 │
    =#

In DataKnots, filtering and paging operations can be used to build
interesting components that can then be reused within queries.

### Query Parameters

With DataKnots, parameters can be provided so that static data can
be used within query expressions. By convention, we use upper case,
singular labels for query parameters.

    run("Hello " .* Lookup(:WHO), WHO="World")
    #=>
    │ WHOKnot    │
    ├─────────────┤
    │ Hello World │
    =#

To make `Lookup` convenient, `It` provides a shorthand syntax.

    run("Hello " .* It.WHO, WHO="World")
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

Query parameters are available anywhere in the query. They could,
for example be used within a filter.

    query = Range(6) >> Filter(It .> It.START)
    run(query, START=3)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        4 │
    2 │        5 │
    3 │        6 │
    =#

Parameters can also be defined as part of a query using `Given`. This
combinator takes set of pairs (`=>`) that map symbols (`:name`) onto
query expressions. The subsequent argument is then evaluated in a
naming context where the defined parameters are available for reuse.

    run(Given(:WHO => "World",
        "Hello " .* Lookup(:WHO)))
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

Query parameters can be especially useful when managing aggregates, or
with expressions that one may wish to repeat more than once.

    GreaterThanAverage(X) =
      Given(:AVG => Mean(X),
            X >> Filter(It .> Lookup(:AVG)))

    run(Range(6) >> Then(GreaterThanAverage))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        4 │
    2 │        5 │
    3 │        6 │
    =#

In DataKnots, query parameters passed in to the `run` command permit
external data to be used within query expressions. Parameters that are
defined with `Given` can be used to remember values and reuse them.

### Records & Labels

Internally, DataKnots use a column-oriented storage mechanism that
handles hierarchies and graphs. Data objects in this model can be
created using the `Record` combinator.

    GM = Record(:name => "GARRY M", :salary => 260004)
    run(GM)
    #=>
    │ DataKnot        │
    │ name     salary │
    ├─────────────────┤
    │ GARRY M  260004 │
    =#

Field access is also possible via `Lookup` or via the `It` shortcut.

    run(GM >> It.name)
    #=>
    │ name    │
    ├─────────┤
    │ GARRY M │
    =#

As seen in the output above, field names also act as display labels.
It is possible to provide a name to any expression with the `Label`
combinator. Labeling doesn't affect the actual output, only the field
name given to the expression and its display.

    run(Const("Hello World") >> Label(:greeting)
    #=>
    │ greeting    │
    ├─────────────┤
    │ Hello World │
    =#

Alternatively, Julia's pair constructor (`=>`) and and a `Symbol`
denoted by a colon (`:`) can be used to label an expression.

    Hello = :greeting => Const("Hello World")
    run(Hello)
    #=>
    │ greeting    │
    ├─────────────┤
    │ Hello World │
    =#

When a record is created, it can use the label from which it
originates. In this case, the `:greeting` label from the `Hello` is
used to make the field label used within the `Record`. The record
itself is also expressly labeled.

    run(:seasons => Record(Hello))
    #=>
    │ seasons     │
    │ greeting    │
    ├─────────────┤
    │ Hello World │
    =#

Records can be plural. Here is a table of obvious statistics.

    Stats = Record(:n¹=>It, :n²=>It.*It, :n³=>It.*It.*It)
    run(Range(3) >> Stats)
    #=>
      │ DataKnot   │
      │ n¹  n²  n³ │
    ──┼────────────┤
    1 │  1   1   1 │
    2 │  2   4   8 │
    3 │  3   9  27 │
    =#

Calculations could be run on record sets as follows:

    run(Range(3) >> Stats >> (It.n² .+ It.n³))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │       12 │
    3 │       36 │
    =#

Any values can be used within a Record, including other records and
plural values.

    run(:work_schedule =>
     Record(:staff => Record(:name => "Jim Rockford",
                             :phone => "555-2368"),
            :workday => Const(["Su", "M","Tu", "F"])))
    #=>
    │ work_schedule                            │
    │ staff                       workday      │
    ├──────────────────────────────────────────┤
    │ │ name          phone    │  Su; M; Tu; F │
    │ ├────────────────────────┤               │
    │ │ Jim Rockford  555-2386 │               │
    =#

In DataKnots, records provide rich ways to structure data to form
hierarchies and other rich data structures.

## Working With Data

Arrays of named tuples can be wrapped with `Const` in order to provide
a series of tuples. Since DataKnots works fluidly with Julia, any sort
of Julia object may be used.

    DATA =[(name = "GARRY M", salary = 260004),
           (name = "ANTHONY R", salary = 185364),
           (name = "DANA A", salary = 170112)]

    run(Const(DATA))
    #=>
      │ DataKnot                              │
    ──┼───────────────────────────────────────┤
    1 │ (name = "GARRY M", salary = 260004)   │
    2 │ (name = "ANTHONY R", salary = 185364) │
    3 │ (name = "DANA A", salary = 170112)    │
    =#

Access to slots in a named tuple is also done with `Lookup`.

    run(Const(DATA) >> Lookup(:name))
    #=>
      │ DataKnot  │
    ──┼───────────┤
    1 │ GARRY M   │
    2 │ ANTHONY R │
    3 │ DANA A    │
    =#

Since DataKnots is based upon sequential processing, there is no array
indexing primitive. That said, it isn't hard to make one.

    Index(I) = Drop(I .- 1) >> TakeFirst()
    run(Const(It.DATA) >> Index(2) >> It.name)
    #=>
    │ DataKnot  │
    ┼───────────┤
    │ ANTHONY R │
    =#

Together with previous combinators, DataKnots could be used to create
readable queries, such as "who has the greatest salary"?

    run(Const(DATA)
        >> Given(:max => Max(It.salary),
             Filter(It.salary .== Lookup(:max))
             >> It.name
             >> TakeFirst()))
    #=>
    │ DataKnot │
    ┼──────────┤
    │ GARRY M  │
    =#

External data can be turned into plural `Record` knots.

    POLICE = [(name = "GARRY M", salary = 260004),
              (name = "ANTHONY R", salary = 185364),
              (name = "DANA A", salary = 170112)]

    DB =
     :staff =>
       Const(POLICE) >> Record(It.name, It.salary))

    run(DB)
    #=>
      │ staff             │
      │ name       salary │
    ──┼───────────────────┤
    1 │ GARRY M    260004 │
    2 │ ANTHONY R  185364 │
    3 │ DANA A     170112 │
    =#

Records can even contain lists of subordinate records.

    FIRE   = [(name = "JOSE S", salary = 202728),
              (name = "CHARLES S", salary = 197736)]

    DB =
     :department =>
      Record(
       :name => "FIRE",
       :staff => Const(FIRE) >> Record(It.name, It.salary))

    run(DB)
    #=>
    │ department                              │
    │ name  staff                             │
    ├─────────────────────────────────────────┤
    │ FIRE  JOSE S, 202728; CHARLES S, 197736 │
    =#

These subordinate records can be summarized.

    run(DB >> Record(:dept => It.name,
                     :count => Count(It.staff)))
    #=>
    │ DataKnot    │
    │ dept  count │
    ├─────────────┤
    │ FIRE      2 │
    =#
