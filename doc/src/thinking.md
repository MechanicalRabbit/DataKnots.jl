# Thinking in DataKnots

DataKnots is a Julia library for constructing computational pipelines.
DataKnots permit the encapsulation of data transformation logic so that
they could be independently tested and reused in various contexts.

This library is named after the type of data objects it manipulates,
DataKnots. Each `DataKnot` is a container holding structured, often
interrelated, vectorized data. DataKnots come with an in-memory
column-oriented backend which can handle tabular data from a CSV file,
hierarchical data from JSON or XML, or even interlinked RDF graphs.
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

This `Hello` pipeline is constructed using the `Const` primitive,
which converts a Julia value into a pipeline component. This pipeline
can then be `run()` to produce a knot with the given value.

### Composition & Identity

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
operator, `>>`. This composed pipeline, `R3 >> Hello`, produces a
knot having 3 copies of the string value `"Hello World"`.

    run(R3 >> Hello)
    #=>
      │ DataKnot    │
    ──┼─────────────┤
    1 │ Hello World │
    2 │ Hello World │
    3 │ Hello World │
    =#

This output is produced because the `Hello` pipeline produces the same,
`"Hello World"` string constant for each input it receives. In this
case, it would receive 3 inputs, so it produces 3 outputs.

Consider the reverse composition, ``Hello >> R3``. In this case, the
``Hello`` pipeline produces a single value, which the ``Repeat``
combinator promptly ignores.

    run(Hello >> R3)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        2 │
    3 │        3 │
    =#

Composition of pipelines forms an algebra. The *identity* pipeline with
respect to composition is called `It`. This pipeline primitive can be
composed with any pipeline without changing the pipeline's operation.
Rather than ignoring its input, it faithfully reproduces it.

    run(R3 >> It)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

In this way, DataKnots implements a complete pipeline algebra. Each
pipeline component, such as `Hello` and `R3` can be independently
defined, tested and refined. Their algebraic combination is then
possible without explicit variable passing.

### Sequence Flattening & Collapsing

When pipelines that produce plural values are combined, the output is
flattened into a single sequence. Consider `Nonsense` defined to return
a sequence having two strings, `"Horse"` and `"Feathers"`:

    Nonsense = Const(["Horse", "Feathers"]);
    run(Nonsense)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │ Horse    │
    2 │ Feathers │
    =#

The repetition of this sequence 3 times would produce a knot having
have 6 entries, not a nested list.

    run(R3 >> Nonsense)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │ Horse    │
    2 │ Feathers │
    3 │ Horse    │
    4 │ Feathers │
    5 │ Horse    │
    6 │ Feathers │
    =#

Pipeline combinators have significant latitude as to what they accept
and what they produce. For example, aggregates, such as `ThenCount` may
collapse a plural input into a singular output, which represents the
cardinality of its input.

    query(Repeat(3) >> ThenCount)
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

It's this flattening and collapsing behavior that sees pipelines as a
processing a stream of values.

### Lifting Functions to Pipelines

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

It's possible to define a pipeline component that depends upon its
input stream. Let's define `Inc` as a combinator that increments a
numeric input. First, we'll define a regular Julia function that
handles a single value.

    inc(x) = x+1;
    inc(2) #-> 3

Second, we can lift this function to a combinator which takes a single
argument, the pipeline being incremented.

    Inc(X) = Lift(inc)(X);

Then, this can be applied in a query.

    run(Inc(Repeat(3)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

Since this sort of operation is common enough, Julia's *broadcast*
syntax (using a period) is overloaded to make simple lifting easy.
Any scalar function can be automatically lifted as follows:

    run(inc.(Repeat(3)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

In this example, the value being incremented was passed into `Inc`,
while `Inc` itself ignored the incoming data stream. With the identity,
`It`, this becomes possible. By convention, a function that uses the
incoming stream for input is prefixed with `Then`.

    ThenInc = Inc(It)
    run(Repeat(3) >> ThenInc)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

This automatic lifting also applies to built-in Julia operators.
In this case, the expression `It .+ 1` is a pipeline component
that increments each one of its input values.

    run(Repeat(3) >> It .+ 1)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

Lifting of operations, either manually or automatic, converts normal
Julia functions which work on individual values into combinators that
work within a pipeline. Note that the operation of the lifted
combinator operates on pipelines, its only when the pipeline is run
that the wrapped function is invoked.


