# Thinking in DataKnots

DataKnots is a Julia library for working with computational pipelines.
Each `DataKnot` is a container holding structured, often interrelated,
vectorized data. Each `Pipeline` can be seen as a data knot
transformation. Pipelines are assembled algebraically using pipeline
*primitives*, which represent relationships among data, and
*combinators*, which encapsulate logic.

This description requires some explanation. To start working with
DataKnots, we import the package:

    using DataKnots

## Introduction to DataKnots

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

With DataKnots, any native Julia expression can be *lifted* to a
combinator form where it may be used to build a `Pipeline`. Consider
the Julia function `double()` that, when applied to a `Number`,
produces a `Number`:

    double(x) = 2x
    double(3) #-> 6

What we want is an analogue that, when applied to a `Pipeline`,
produces a new `Pipeline` component. Such functions are called
pipeline *combinators*. We can convert any Julia function to a
pipeline combinator using `Lift`:

    const Double = lift(double)

This combinator can then be used to build a pipeline.  For every
argument of the underlying Julia function, a `Pipeline` argument
must be provided to the analogous combinator.

    run(Double(Range(3)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

When this pipeline is `run()`, the `Range(3)` pipeline produces three
output values. These output values are then passed though our
underlying function, `double`. The results are then collected and
converted into an output knot.

Combinators can be used to make pipelines with late binding. In this
next example, `ThenDouble` is a pipeline that uses the `It` primitive
to depend upon the previous pipeline's output. It could then be
composed using `>>` to connect it to `Range(3)`.

    ThenDouble = Double(It)
    run(Range(3) >> ThenDouble)
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

    run(double.(Range(3)))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        4 │
    3 │        6 │
    =#

This automatic lifting also applies to built-in Julia operators.
In this case, the expression `It .+ 1` is a pipeline component that
increments each one of its input values.

    run(Range(3) >> It .+ 1)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        3 │
    3 │        4 │
    =#

When a Julia function returns a vector, the combinator constructed by
`Lift` creates pipelines having plural output. In fact, the `Range`
combinator used in these examples could be created as follows:

    const Range = Lift(x -> 1:x)

In DataKnots, pipeline combinators can be constructed directly from
native Julia functions. This lets us take advantage of Julia's rich
statistical and data processing functions.

### Aggregates & Scope

With DataKnots, aggregation is also based on combinators, specifically
ones that take a plural pipeline and build a singular one. Consider the
the `Count` combinator with `Range(3)` as its argument. The resulting
pipeline, `Count(Range(3))` produces a singular value having the count
of the entries, `3`.

    run(Count(Range(3))
    #=>
    │ DataKnot    │
    ├─────────────┤
    │ 3           │
    =#

