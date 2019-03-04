
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
    Range(N) = Lift(:, (1, N))
    YesOrNo = Lift(() -> rand(Bool) ? "yes" : "no", ())
    run(Range(3) >> YesOrNo)
    #=>
      │ It  │
    ──┼─────┼
    1 │ no  │
    2 │ no  │
    3 │ yes │
    =#


`run(Range(3) >> (Const("Item #") .* string.(It)))`


For example, given a function `f(x)`, an analogous *combinator* `F` is
defined `F(x) = T⁻¹(f(T(x)))` where `T` is a translation that handles
carnality, composition and other pipeline semantics.

This is a scalar function that converts plural to singular,
it's an aggregate.

    fst(v) = isempty(v) ? missing : v[1]
    Fst(V) = Lift(fst, (V,))
    run(Fst(Lift([1,2,3])))

### Parameter Evaluation

Each pipeline constructor can choose how it wishes to evaluate its
parameters and treat its input. Most pipelines are *elementwise*,
that is, for each of their inputs, they evaluate their arguments
once and produce zero or more outputs.

For example, `Record` produces exactly one output per input.

    run(ChicagoData, 
        It.department 
        >> Record(It.name))
    #=>
      │ department │
      │ name       │
    ──┼────────────┼
    1 │ POLICE     │
    2 │ FIRE       │
    =#

The `Count()` pipeline constructor is also *elementwise*, for each
input, it evaluates its argument and produces an output. In this
example, `Count()` gets one input per department and produces the
count of employees in each of those departments.

    run(ChicagoData, 
        It.department 
        >> Count(It.employee))
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

By contrast, *aggregate* pipeline primitives are not elementwise.
For example, `Count` consumes its entire input to produce exactly
one output. 

    run(ChicagoData, 
        It.department 
        >> Count)
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

The `A >> B` pipeline composition operator has it's own logic, it
passes the output of `A` as the input of `B`, and merges each
output from `B` into a single stream.

    run(ChicagoData, 
        It.department 
        >> It.employee 
        >> It.name)
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ NANCY A   │
    3 │ DANIEL A  │
    =#

The `Take` and `Drop` pipeline constructors also deserve special
mention since they are neither elementwise nor aggregates. Their
argument is evaluated in the *origin* of the parent query. In this
next example, only the first name is returned since `3÷2` is `1`.

    Names = It.department.employee.name
    Halfway = Count(Names) .÷ 2
    run(ChicagoData, Names >> Take(Halfway))
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

The origin used can be changed using `Each` or `Record`. In this
case, `2÷2` is `1`, and `1÷2` is `0`. Hence, only the first name
is returned for `POLICE` and zero names are returned for `FIRE`.

    Names = :employee_names => It.employee.name
    Halfway = Count(Names) .÷ 2
    run(ChicagoData, 
        It.department
        >> Record(
             :dept_name => It.name,
             Names >> Take(Halfway)))
    #=>
      │ department                │
      │ dept_name  employee_names │
    ──┼───────────────────────────┼
    1 │ POLICE     JEFFERY A      │
    2 │ FIRE                      │
    =#

In both of these cases, if `Take` evaluated its arguments
*elementwise* then, `Halfway` would be an error.

### Incorrect Query Discussion

In cases thus far, query combinators evaluate their parameters in
the *target* context of their input. Consider a query returning
employees having salary greater than 100K.

    chicago[It.department.employee >> 
            Filter(It.salary .> 100000)]
   
Let's consider the `Input` and `Argument` separately.

    Input = It.department.employee
    Argument = It.salary .> 100000
    chicago[Input >> Filter(Argument)]
    #=>
        │ employee                    │
        │ name       position  salary │
      ──┼─────────────────────────────┼
      1 │ JEFFERY A  SERGEANT  101442 │
    =#

The `Input`, `It.department.employee` can be seen as a mapping
from an *origin*, the database as a whole, to a given *target*, 
a list of employees. By convention, we display the output of the
query when it is performed.

    chicago[Input]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

The `Argument`, `It.salary .> 100000`, cannot be performed in the
context of the database. It's input must have a `salary` slot.

    chicago[Argument]
    #-> ERROR: cannot find salary ⋮

That said, `Input` and `Argument` could be combined, since the
*target* of the `Input` query, employee records, has the required
`salary` slot.

    chicago[Input >> Argument]
    #=>
      │ It    │
    ──┼───────┼
    1 │  true │
    2 │ false │
    3 │ false │
    =#

It's this reason why we say that `Filter` is *elementwise*, that
is, it evaluates its arguments in the target context of its input,
producing zero or more rows for each input.

    chicago[Input >> Filter(Argument)]
    #=>
        │ employee                    │
        │ name       position  salary │
      ──┼─────────────────────────────┼
      1 │ JEFFERY A  SERGEANT  101442 │
    =#

Even the `Count()` combinator is elementwise. By department, let's
show how many employees have a salary greater than 100K.

    chicago[It.department >> Count(It.employee.salary .> 100000)]


### Thoughts on Take

This last query deserves a bit of explanation, but the reference
is a more appropriate place for this discussion. For now, we could
say the query above is equivalent to the following.

    Employee = It.department.employee
    chicago[
        Keep(:no => Count(Employee) .÷ 2) >>
        Each(Employee >> Take(It.no))]
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

That
said, it can be directly used in a straight-forward manner.

    [dept[:name] for dept in vt]
    #-> ["POLICE", "FIRE"]

Use `collect` to convert a `@VectorTree` into a standard
row-oriented structure.

    display(collect(vt))
    #=>
    2-element Array{NamedTuple{(:name, :employee_count),…},1}:
     (name = "POLICE", employee_count = 2)
     (name = "FIRE", employee_count = 1)
    =#

