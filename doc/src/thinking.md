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

## Pipeline Basics



## Constant Combinators

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


