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

  using DataKnots

## Combining Pipelines

With DataKnots, composition of independently developed data processing
components is easy. Consider an example pipeline, `Hello` that produces
a `DataKnot` containing a singular string value, `"Hello World"`:

  Hello = Const("Hello World")
  run(Hello)
  #=>
  │ DataKnot    │
  ├─────────────┤
  │ Hello World │
  =#

The next example uses `Repeat()` to produce a `DataKnot` with a plural
output, the sequence `1`, `2` and `3`. In the output display of plural
knots, the index is shown in the first column.

  R3 = Repeat(3)
  run(R3)
  #=>
    │ DataKnot │
  ──┼──────────┤
  1 │        1 │
  2 │        2 │
  3 │        3 │
  =#

These two combinators can then be combined using pipeline concatination
operator, ``>>``. This next example produces a knot with 3 copies of
the string value `"Hello World"`.

  run(R3 >> Hello)
  #=>
    │ DataKnot    │
  ──┼─────────────┤
  1 │ Hello World │
  2 │ Hello World │
  3 │ Hello World │
  =#

Notice that each of the two component pipelines, `Hello` and `R3` could
be independently defined and tested. Their algebraic combination was
then possible without using any sort of variable.

## Sequences & Counting

When expressions that produce plural values are combined, the
pipeline's output is flattened into a single sequence. For example,
consider `Hello` defined to return a sequence having two strings,
`"Hello"` and `"World"`:

  Hello = Const(["Hello", "World"])
  run(Hello)
  #=>
    │ DataKnot │
  ──┼──────────┤
  1 │ Hello    │
  2 │ World    │
  =#

Then, the repetition of this sequence 3 times would have 6 entries,
rather than a nested output.

  run(Repeat(3) >> Hello)
  #=>
    │ DataKnot │
  ──┼──────────┤
  1 │ Hello    │
  2 │ World    │
  3 │ Hello    │
  4 │ World    │
  5 │ Hello    │
  6 │ World    │
  =#

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


