# Thinking in DataKnots

DataKnots is a Julia library for working with computational pipelines.
Each `DataKnot` is a container holding structured, often interrelated,
vectorized data. Each `Pipeline` is a computation on data knots.
Pipelines are assembled algebraically using pipeline primitives, which
represent relationships among data, and combinators, which encapsulate
logic.

To start working with DataKnots, we import the package:

    using DataKnots

## Introduction to DataKnots

Consider a pipeline `Hello` that produces a `DataKnot` containing a
singular string value, `"Hello World"`. It is built using the `Const`
primitive, which converts a Julia string value into a pipeline
component. This pipeline can then be `run()` to produce a knot with the
value, `"Hello World"`.

    Hello = Const("Hello World")
    run(Hello)
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

Pipelines can also produce a plural `DataKnot`. Consider the pipeline
`Range(3)` built with the `Range` combinator. When `run()`, it emits a
sequence of integers from `1` to `3`.

    run(Range(3))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        1 │
    2 │        2 │
    3 │        3 │
    =#

In this notation, indicies are in the first column and values are in
the second column. Hence, the 3rd item in the output is `3`.

### Composition & Identity

With DataKnots, composition of independently developed data processing
components is straightforward. Two pipelines could be connected using
the composition combinator `>>`. Since the constant `Hello` pipeline
does not depend upon its input, the composition `Range(3) >> Hello`
would emit 3 copies of `"Hello World"`.

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
the output from previous processing. For example, one could define
`Increment` using broadcast addition (`.+`), which applies the given
operation to each of its inputs.

    Increment = It .+ 1
    run(Range(3) >> Increment)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

In DataKnots, pipelines are built algebraically, using pipeline
composition, identity and other combinators. This lets us define
sophisticated pipeline components and remix them in creative ways.

### Calling Julia Functions

With DataKnots, any native Julia expression can be *lifted* to a
combinator form where it may be used to build a `Pipeline`. Consider
the Julia function `double()`, lifted to combinator `Double`, and then
used to build a pipeline component, `Double(It)`.

    double(x) = 2x
    const Double = Lift(double)
    run(Range(3) >> Double(It))
    #=>
      │ DataKnot │

    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

In this composition, the output of `Range(3)` becomes the input to
`Double(It)`. When the composition is `run()`, each of the three
values `1-3` is sent to the `double` function. The results are then
collected and converted into an output knot.

Equivalently, this could be written.

    run(Double(Range(3)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

Since this sort of operation is common enough, Julia's *broadcast*
syntax (using a period) is overloaded to make simple lifting easy.
Any scalar function can be automatically lifted as follows:

    run(Range(3) >> double.(It))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

This automatic lifting also applies to built-in Julia operators.
In this case, the expression `It .+ 1` is a pipeline component
that increments each one of its input values.

    run(Range(3) >> It .+ 1)
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

    run(Range(3) >> Nonsense)
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

    query(Range(3) >> ThenCount)
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

It's this flattening and collapsing behavior that sees pipelines as a
processing a stream of values.

    hello(name) = "Hello $name"
    const Hello = Lift(hello)
    run(Hello("World"))
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ Hello World │
    =#

It is possible to define a pipeline component that takes arguments.
For example, let's create a combinator that increments its argument.
First, we'll define a regular Julia function that increments a numeric
value.
