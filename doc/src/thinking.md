# Thinking in DataKnots

DataKnots is a Julia library for constructing computational pipelines.
DataKnots permit the encapsulation of data transformation logic so that
they could be independently tested and reused in various contexts.

This library is named after the type of data objects it manipulates,
DataKnots. Each `DataKnot` is a container holding structured, often
interrelated, vectorized data. DataKnots come with an in-memory
column-oriented backend which can handle tabular data from a CSV file,
hierarchical data from JSON or XML, or even interlinked YAML graphs.
DataKnots could also be federated to handle external data sources such
as SQL databases or GraphQL enabled websites.

Computations on DataKnots are expressed using `Pipeline` expressions.
Pipelines are constructed algebraically using pipeline primitives and
combinators. Primitives represent data and relationships among data
from a given data source. Combinators are components that encapsulate
logic. DataKnots provide a rich library of these pipeline components,
and new ones could be coded in Julia. Importantly, any Julia function
could be *lifted* to a pipeline component, providing easy and tight
integration of Julia functions within DataKnot expressions.

To start working with DataKnots, we import the package:

    using DataKnots

## Introduction to DataKnots

Consider an example pipeline `Hello` that produces a `DataKnot`
containing a singular string value, `"Hello World"`:

    Hello = Const("Hello World");
    run(Hello)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

This `Hello` pipeline is constructed using the `Const` primitive, which
converts a Julia value into a pipeline component. This pipeline can
then be `run()` to produce a knot with the given value.

### Pipeline Composition

With DataKnots, composition of independently developed data processing
components is straightforward. Above we've defined the pipeline `Hello`.

Let's define another pipeline `R3` to mean the repetition of a
subsequent expression 3 times. This is realized with the `Repeat()`
combinator to produce a `DataKnot` with a plural output, the sequence
`1`, `2` and `3`.

    R3 = Repeat(3);
    run(R3)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        2 │
    3 │        3 │
    =#

These two pipelines can then be combined using the composition
operator, `>>`. This composed pipeline, `R3 >> Hello`, produces a knot
with 3 copies of the string value `"Hello World"`.

    run(R3 >> Hello)
    #=>
      │ DataKnot    │
    ──┼─────────────┤
    1 │ Hello World │
    2 │ Hello World │
    3 │ Hello World │
    =#

Notice that each of the two components, `Hello` and `R3` could be
independently defined, tested and refined. Their algebraic combination
is then possible without explicit variable passing.

### Sequences & Counting

When pipelines that produce plural values are combined, the output is
flattened into a single sequence. For example, consider `Hello` defined
to return a sequence having two strings, `"Hello"` and `"World"`:

    Hello = Const(["Hello", "World"]);
    run(Hello)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │ Hello    │
    2 │ World    │
    =#

Then, the repetition of this sequence 3 times would have 6 entries, not
a nested list. It's this flattening that keeps pipelines composable so
that intermediate components can be added or removed.

    run(R3 >> Hello)
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

Aggregate combinators collapse plural values into singular ones. For
example, the `Count` combinator converts any pipeline which produces a
sequence into a pipeline producing a singular, numeric cardinality.

    query(Repeat(3) >> Count)
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

The operation of `Count` doesn't directly count the outputs of the
preceding pipeline. Instead, `Count` constructs a new pipeline, and the
new pipeline's runtime operation is what does the actual counting.

### Lifting & Identity

With DataKnots, any native Julia expression can be *lifted* so that it
may be used to construct a `Pipeline`.

Since any scalar value can be seen as a function with no arguments, it
could be *lifted* into its pipeline form. This permits us to define
`Hello` yet again.

    hello() = "Hello World";
    Hello = Lift(hello);
    query(Hello)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#


