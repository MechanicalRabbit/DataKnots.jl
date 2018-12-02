
DataKnots are a graph-oriented column-store interface together with a
computational method based on *query combinators*. Computations can be
executed in-memory or federated to external data sources such as SQL
databases. The DataKnots model handles tabular data, interrelated
tables, or hierarchical data such as JSON or XML.

Query combinators are variable-free algebraic expressions that express
a transformation from one DataKnot to another. The elements of this
algebra are *queries*, which represents relationships among classes and
data types. This algebra's operations are *combinators*, which are
applied to construct query expressions.

DataKnots is extensible. Users of DataKnots can build new combinators
from other combinators. Query combinators can also be constructed
natively using Julia, using the DataKnots implementation interfaces.
Finally, most Julia functions can be *lifted* into combinators.

DataKnots is both a library and a language. As a library, DataKnots
uses a language-embedded approach, where *Combinator* and *DataKnot*
are data types. There is also a user-facing syntax that could be
portable across other implementation languages.

DataKnots are a graph-oriented column-store interface together with an
algebraic computation method we call *query combinators*. A `DataKnot`
is a strongly-typed set of named, perhaps interrelated and
self-referential vectorized tuples. A `Combinator` is a variable-free
algebraic expression that transforms one DataKnot to another.

Many modern query libraries express queries using bound variables and
lambda functions. By contrast, DataKnots provides an algebraic
system for construting query pipelines.

DataKnots provies a rich pipeline algebra which does not rely upon
lambda functions or bound variables.

DataKnots can be adapted to a specific domain by expressing
domain-specific concepts as new primitives and combinators. These
pipelines can then be remixed, reducing complex expressions into
readable prose.

By expressing domain-specific concepts as new primitives and
combinators, DataKnots permits complexity to be encapsulated
and easily mixed.

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

It's easy to imagine a pipeline as a mapping of input data to output
data. In DataKnots, it's similar and in many cases, indistinguishable.
However, to support complex cases, a pipeline doesn't take raw input
data. Instead, it takes an input data *generator* and returns an output
data generator. Hence, the ``>>`` combinator connects two pipelines and
returns a composite pipeline. It's the composite pipeline which
transforms the input data generator to an output data generator.  In
DataKnots, we call these generators `queries` -- but, they are an
implementation detail.

The real picture of `>>` is more involved what `F` gets is a data
generator `x(t)` it transforms it to generator `y(t)` then G tranforms
`y(t)` to `z(t)` in DataKnots, we call data generators queries.
What `>>` does is applying two transformations sequentially.

For another example, consider how random `"yes"`/`"no"` generation
could be easily incorporated into a DataKnots' processing pipeline.

    using DataKnots
    using Random: seed!, rand
    seed!(0)
    YesOrNo = Lift(() -> rand(Bool) ? "yes" : "no")
    run(Range(3) >> YesOrNo)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │ no       │
    2 │ no       │
    3 │ yes      │
    =#
