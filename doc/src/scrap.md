
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
