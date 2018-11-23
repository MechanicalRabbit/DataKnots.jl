# Thinking in DataKnots

DataKnots is a Julia library for constructing computational pipelines.
DataKnots permit the encapsulation of data transformation logic so
that they could be independently tested and reused in various contexts.

This library is named after the type of data objects it manipulates,
DataKnots. Each `DataKnot` is a container holding structured, often
interrelated, vectorized data. DataKnots come with an in-memory
column-oriented backend which can handle tabular data from a CSV file,
hierarchical data from JSON or XML, or even interlinked YAML graphs.
DataKnots could also be federated to handle external data sources such
as SQL databases or GraphQL enabled websites.

Computations on DataKnots are expressed using `Pipeline` expressions.
Pipelines are constructed algebraically using pipeline primitives and
combinators. Primitives represent relationships among data from a given
data source. Combinators are components that encapsulate logic.
DataKnots provide a rich library of these pipeline components, and new
ones could be coded in Julia. Importantly, any Julia function could be
*lifted* to a pipeline component, providing easy and tight integration
of Julia functions within DataKnot expressions.

To start working with DataKnots, we import the package:

```julia
using DataKnots
```

## Basic Expressions

Let's consider an example `Pipeline` that produces a `DataKnot`
containing a singular string value, `"Hello World"`.

```julia
Hello = Const("Hello World")
run(Hello)
```
```
│ DataKnot    │
├─────────────┤
│ Hello World │
```

In this example, `Const` creates a pipeline that, for each of its
inputs, produces a constant value for its output.  Then, `run()` seeds
the pipeline with a default data source, a `DataKnot` having a single
element, `nothing`. Since there is one input, `Hello` produces an
output `DataKnot` with one string value `"Hello World"`.

The next example produces an output `DataKnot` with 3 values:
`1`, `2` and `3`.

```julia
R3 = Repeat(3)
run(R3)
```
```
  │ DataKnot │
──┼──────────┤
1 │        1 │
2 │        2 │
3 │        3 │
```

These two combinators can be combined using pipeline concatination
operator, ``>>``. This next example produces a knot with 3 copies of
the string value `"Hello World"`.

```julia
run(R3 >> Hello)
```

```
  │ DataKnot    │
──┼─────────────┤
1 │ Hello World │
2 │ Hello World │
3 │ Hello World │
```

While both these pipelines and their combination are both trivial,
what's important is that each pipeline they can be independently
defined and then combined together.

## Counting & Flattening

When expressions that produce plural values are combined, their output
flattens results into a single sequence.  For example, the following
pipeline produces 6 outputs, the sequence `1`, `2` repeated 3 times.

```julia
run(Repeat(3) >> Repeat(2))
```
```
  │ DataKnot │
──┼──────────┤
1 │        1 │
2 │        2 │
3 │        1 │
4 │        2 │
5 │        1 │
6 │        2 │
```

Aggregate combinators, such as `Count` collapse plural values into
single values.

```julia
query(Repeat(3) >> Count)
```
```
│ DataKnot │
├──────────┤
│        3 │
```


## Lifting Functions to Combinators

In fact, any scalar value can be seen as a function, just one that
ignores its input. Given such a function, it could be *lifted* into its
combinator form.

```julia
hello_world(x) = "Hello World"
HelloWorld = Lift(hello_world, It)
query(HelloWorld)
```

The `Lift()` function takes the function being lifted into a combinator
as the 1st argument. The 2nd and remaining arguments are the combinator
expressions used to convert. In Julia, anonymous functions can be used
to make this lifting far more convenient.

```julia
query(Lift(x -> "Hello World", It))
```


