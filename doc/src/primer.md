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

Any function could be used to build queries. Consider the function
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

Broadcasting a function over a query argument also makes queries.
For example, `double.(It)` is a query that doubles its input.

    unitknot[Lift(1:3) >> double.(It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Broadcast lifting applies to built-in operators.

    unitknot[Lift(1:3) >> (It .+ 1)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  3 │
    3 │  4 │
    =#

Unary operators can be broadcast as well.

    unitknot[Lift(1:3) >> (√).(It,)]
    #=>
      │ It      │
    ──┼─────────┼
    1 │ 1.0     │
    2 │ 1.41421 │
    3 │ 1.73205 │
    =#

When making a combinator that uses a function or an operator,
using `Lift` is recommended since it also lifts the arguments.

    Sqrt(X) = Lift(√, (X,))

    unitknot[Sqrt(2)]
    #=>
    │ It      │
    ┼─────────┼
    │ 1.41421 │
    =#

Vector-valued functions give rise to plural queries. Here, the
unit range constructor, which produces a vector output, is lifted
to a query combinator that builds plural queries.

    OneTo(X) = Lift(:, (1, X))

    unitknot[OneTo(3)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

This semi-automated lifting lets us access rich statistical and
data processing functions from within our queries.

## Aggregate Queries

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
barrier. For each input element, `Each` evaluates its argument,
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

## Unique Elements

Summary operations need not be limited to producing a single
output value. The `Unique` combinator takes a plural query for its
argument and produces sorted, unique elements for its output.

    unitknot[Unique(["b","a","c","a","c"])]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

This combinator has an aggregate primitive form.

    unitknot[Lift(["b","a","c","a","c"]) >> Unique]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

Of course, it's possible to count these unique values.

    unitknot[Lift(["b","a","c","a","c"]) >> Unique >> Count]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

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

    unitknot[Lift('a':'i') >> Drop(3) >> Take(3)]
    #=>
      │ It │
    ──┼────┼
    1 │ d  │
    2 │ e  │
    3 │ f  │
    =#

Unlike `Filter`, which processes input elementwise, `Take` and
`Drop` are aggregate and therefore consider their input as a
whole. This permits us to count backwards.

    unitknot[Lift('a':'f') >> Take(-3)]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

    unitknot[Lift('a':'f') >> Drop(-3)]
    #=>
      │ It │
    ──┼────┼
    1 │ d  │
    2 │ e  │
    3 │ f  │
    =#

Further unlike `Filter`, which evaluates its argument for each
element, the argument to `Take` is evaluated once, in the context
of the input's *source*.

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
can be labeled using Julia's `Pair` syntax.

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

Calculations can be performed using on records using field labels.

    unitknot[Lift(1:3) >> Stats >> (It.n¹ .+ It.n² .+ It.n³)]
    #=>
      │ It │
    ──┼────┼
    1 │  3 │
    2 │ 14 │
    3 │ 39 │
    =#

## Group

Before we can demonstrate `Group` we need an interesting dataset.
Let's create a flat list of numbers and two characteristics.

    DataRec = :data=> Record(:no => It, :even => iseven.(It),
                             :mod3 => Char.((It .+ 2) .% 3 .+ 97))
    DataSet = Lift(1:9) >> DataRec

    unitknot[DataSet]
    #=>
      │ data            │
      │ no  even   mod3 │
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

We could collect unique values of `mod3`. However, just looking at
the dataset, how could we find correlated values?

    unitknot[DataSet >> It.mod3 >> Unique]
    #=>
      │ mod3 │
    ──┼──────┼
    1 │ a    │
    2 │ b    │
    3 │ c    │
    =#

The `Group` combinator creates a new `Record`, one that buckets our
unique values together with correlated data.

    unitknot[DataSet >> Group(It.mod3)]
    #=>
      │ mod3  data                                 │
    ──┼────────────────────────────────────────────┼
    1 │ a     1, false, a; 4, true, a; 7, false, a │
    2 │ b     2, true, b; 5, false, b; 8, true, b  │
    3 │ c     3, false, c; 6, true, c; 9, false, c │
    =#

We could then list members of each group.

    unitknot[DataSet >>
             Group(It.mod3) >>
             Record(It.mod3, It.data.no)]
    #=>
      │ mod3  no      │
    ──┼───────────────┼
    1 │ a     1; 4; 7 │
    2 │ b     2; 5; 8 │
    3 │ c     3; 6; 9 │
    =#

Or perhaps summarize them.

    unitknot[DataSet >>
             Group(It.mod3) >>
             Record(It.mod3,
                    :count => Count(It.data),
                    :mean => mean.(It.data.no))]
    #=>
      │ mod3  count  mean │
    ──┼───────────────────┼
    1 │ a         3   4.0 │
    2 │ b         3   5.0 │
    3 │ c         3   6.0 │
    =#

It's possible to group by more than one parameter.

    unitknot[DataSet >>
             Group(It.even, It.mod3) >>
             Record(It.even, It.mod3, It.data.no)]
    #=>
      │ even   mod3  no   │
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

In DataKnots, query parameters permit external data to be used
within query expressions. Parameters that are defined with `Given`
can be used to remember values and reuse them.

## Julia Language Integration

The embedding of DataKnots queries into Julia's syntax works
relatively well, but is imperfect.

### NamedTuple Display & Access

Often named tuples show up in data, especially tables that are
modeled as a vector of named tuple. Consider this trivial dataset.

    knot = convert(DataKnot, (value = 7,))

When our display code sees a `NamedTuple` it provides special
display to show the column headers.

    knot
    #=>
    │ value │
    ┼───────┼
    │     7 │
    =#

Access to a `NamedTuple` values could happen though `getfield`.

    knot[getfield.(It, :value) .* 6]
    #=>
    │ It │
    ┼────┼
    │ 42 │
    =#

Since field access is so common, special treatment to automate
this is provided via the identity (`It`).

    knot[It.value .* 6]
    #=>
    │ It │
    ┼────┼
    │ 42 │
    =#

Both of these are there for convenience, they don't otherwise
impact the semantics of the queries involved. In balance, these
accommodations help the user with commonly encountered data.

### Composition Operator Precedence

DataKnots uses Julia's bitshift operator (`>>`) for composition.

This works visually, but the *precedence* of this operator is not
what would be best for DataKnots. Operators with higher precedence
include: syntax (`.`, `::`), exponentiation (`^`), and unary (`+`,
`-`, `√`). Unfortunately, typical binary operators such as
addition (`+`) have a lower precedence. This conflict of
expectations can sometimes cause confusion.

Consider the following query.

    unitknot[Lift(1:3) >> (It .+ It)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  4 │
    3 │  6 │
    =#

Suppose one forgets the parenthesis around `(It .+ It)`.

    unitknot[Lift(1:3) >> It .+ It]
    #-> ERROR: cannot apply + to Tuple{Array{Int,1},Nothing}⋮

Since `>>` has higher precedence than `.+`, `Lift(1:3) >> It` is
evaluated first, giving us, `Lift(1:3)`.

    unitknot[Lift(1:3) .+ It]
    #-> ERROR: cannot apply + to Tuple{Array{Int,1},Nothing}⋮

The desugared version might be illustrative.

    unitknot[Lift(+, (Lift(1:3), It))]
    #-> ERROR: cannot apply + to Tuple{Array{Int,1},Nothing}⋮

During broadcast, `Lift(1:3)` is converted to `1:3` and `It` is
converted to `nothing`. In this very specific case, there is no
operator that matches this signature, so we get an error.

### Implicit Value Lifting

So that it's easier to write DataKnots queries with Julia objects,
there are many cases where values are automatically lifted.

    unitknot[1:3]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

    unitknot["Hello"]
    #=>
    │ It    │
    ┼───────┼
    │ Hello │
    =#

Since both of those work splendidly, one might expect this to also
work, but it doesn't.

    unitknot[1:3 >> "Hello"]
    #-> ERROR: MethodError: no method matching >>(::Int, ::String)⋮

If we make the 1st argument of `>>` a query, things work.

    unitknot[Lift(1:3) >> "Hello"]
    #=>
      │ It    │
    ──┼───────┼
    1 │ Hello │
    2 │ Hello │
    3 │ Hello │
    =#

Broadcasting lets a function's arguments control how it is
applied. This permits bare constants (such as `"Hello"`) to be
used within a query expression without explicit lift, so long as
at least one other argument is already a query.

### Forgotten Lift

Sometimes forgetting a `Lift` doesn't result in an error, but
instead results with unexpected output. This depends quite a bit
based upon the exact function being used and the context.

Imagine one would like to create a combinator `OneToRand(X)` that
generates sequential numbers having random length. Julia has a
function `rand` that could generate a random length for us.

    using Random: seed!, rand
    seed!(3)
    rand(1:3)
    #-> 1

Let's lift this `rand` function to a combinator and try it.

    unitknot[rand.(1:3)]
    #=>
      │ It                            │
    ──┼───────────────────────────────┼
    1 │ 0.988432                      │
    2 │ 0.807622; 0.970091            │
    3 │ 0.140061; 0.509444; 0.0586974 │
    =#

That was unexpected. Here, `rand.(1:3)` was evaluated before it
was turned into a query. If we `Lift` the argument, it works.

    unitknot[rand.(Lift(1:3))]
    #=>
    │ It │
    ┼────┼
    │  1 │
    =#

Then, we could build our random sequence generator.

    OneToRand(X) = UnitRange.(1, rand.(Lift(:, (1, X))))

    unitknot[OneToRand(5)]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

Generally, we prefer to use broadcast notation when we know that
at least one argument will always be a query. However, when making
combinators, it's better to use `Lift` since it ensures all
arguments are lifted. This permits use of bare constants.

### When Implicit Lifting Fails

Implicit lifting of bare constants doesn't always work. For
example, in Julia 1.0.3, `Char` cannot be implicitly lifted.

    unitknot[Lift('a') .== 'a']
    #=>
    │ It    │
    ┼───────┼
    │ false │
    =#

This doesn't work since `Char` values are already converted to
one-element vectors by broadcasting.

    Base.Broadcast.broadcastable('a')
    #-> ['a']

Hence, to compare `Char` values, an explicit lift is needed.

    unitknot[Lift('a') .== Lift('a')]
    #=>
    │ It   │
    ┼──────┼
    │ true │
    =#

Luckily, the primary datatypes, numbers and strings, seem to lift
implicitly just fine. However, this phenomena may not be limited
to just `Char`. So, if the result isn't expected, perhaps explicit
lifts are required.
