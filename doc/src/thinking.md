# Thinking in DataKnots

In this introduction, we describe DataKnots as a language-embedded
library used for vectorized computation, rather than as a user-oriented
database query language. In this library, each `DataKnot` is a
container holding structured, often interrelated, vectorized data.
Each `Combinator` is variable-free algebraic expression that specifies
how to transform one DataKnot to another.

To start working with DataKnots, we import the package:

```julia
using DataKnots
```

## Constant Combinators

The DataKnots approach to computation is once indirect. One doesn't
combine data transformation functions directly, instead one expresses
the query with combinators.  These combinators are then converted into
lower-level data manipulation functions. In fact, constant expressions
are also seen as combinators, converted to functions that produce the
same output no matter what the input.

To explain, let's consider an example combinator query that produces a
`DataKnot` containing a singular string value, `"Hello World"`. 

```julia
query("Hello World")
```

This example can be rewritten to show how `"Hello World"` is implicitly
converted into its `Combinator` namesake. Hence, the `query()` argument
is not a constant value at all, but rather an combinator expression
which convert to a function that produces a constant value, 
`"Hello World"` for each of its inputs.

```julia
query(Combinator("Hello World"))
```

But, if `"Hello World"` expresses a query function, where is the
function's input? There is also an implicit `DataKnot` containing a
single element, `nothing`. Hence, this example can be rewritten:

```julia
query(DataKnot(nothing), Combinator("Hello World"))
```

There are other combinators. The identity combinator, `It` converts to
a query function that simply reproduces its input. This would permit us
to write our `"Hello World"` example once again:

```julia
query(query("Hello World"), It)
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


