# Tutorial

DataKnots is an embedded query language designed so that
accidental programmers can more easily analyze complex data.
This tutorial shows how typical query operations can be
performed upon a simplified in-memory dataset.

## Getting Started

Consider a tiny cross-section of public data from Chicago,
represented as nested `Vector` and `NamedTuple` objects.

    department_data = [
      (name = "POLICE",
       employee = [
        (name = "ANTHONY A", position = "POLICE OFFICER", salary = 72510),
        (name = "JEFFERY A", position = "SERGEANT", salary = 101442),
        (name = "NANCY A", position = "POLICE OFFICER", salary = 80016)]),
      (name = "FIRE",
       employee = [
        (name = "DANIEL A", position = "FIREFIGHTER-EMT", salary = 95484),
        (name = "ROBERT K", position = "FIREFIGHTER-EMT", salary = 103272)])]

This hierarchical dataset contains a list of departments, with
each department containing associated employees.

To query this dataset, we convert it into a `DataKnot`, or *knot*.

    using DataKnots

    chicago = DataKnot(:department => department_data)

## Our First Query

Let's say we want to return the list of department names from this
dataset. We query the `chicago` knot using Julia's index notation
with `It.department.name`.

    department_names = chicago[It.department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The output, `department_names`, is also a DataKnot. The content of
this output knot could be accessed via `get` function.

    get(department_names)
    #-> ["POLICE", "FIRE"]

## Navigation

In DataKnot queries, `It` means "the current input". The dotted
notation lets one navigate a hierarchical dataset. Let's continue
our dataset exploration by listing employee names.

    chicago[It.department.employee.name]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ ANTHONY A │
    2 │ JEFFERY A │
    3 │ NANCY A   │
    4 │ DANIEL A  │
    5 │ ROBERT K  │
    =#

Navigation context matters. For example, `employee` tuples are not
directly accessible from the root of the dataset. When a field
label, such as `employee`, can't be found, an appropriate error
message is displayed.

    chicago[It.employee]
    #-> ERROR: cannot find "employee" ⋮

Instead, `employee` tuples can be queried by navigating through
`department` tuples. When tuples are returned, they are displayed
as a table.

    chicago[It.department.employee]
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER    72510 │
    2 │ JEFFERY A  SERGEANT         101442 │
    3 │ NANCY A    POLICE OFFICER    80016 │
    4 │ DANIEL A   FIREFIGHTER-EMT   95484 │
    5 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

Notice that nested vectors traversed during navigation are
flattened into a single output vector.

## Composition & Identity

Dotted navigation, such as `It.department.name`, is a syntax
shorthand for the `Get()` primitive together with query
composition (`>>`).

    chicago[Get(:department) >> Get(:name)]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The `Get()` primitive returns values that match a given label.
Query composition (`>>`) chains two queries serially, with the
output of the first query as input to the second.

    chicago[Get(:department) >> Get(:employee)]
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER    72510 │
    2 │ JEFFERY A  SERGEANT         101442 │
    3 │ NANCY A    POLICE OFFICER    80016 │
    4 │ DANIEL A   FIREFIGHTER-EMT   95484 │
    5 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

The `It` query simply reproduces its input, which makes it the
identity with respect to composition (`>>`). Hence, `It` can be
woven into any composition without changing the result.

    chicago[It >> Get(:department) >> Get(:name)]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

This motivates our clever use of `It` as a syntax shorthand.

    chicago[It.department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

In DataKnots, queries are either *primitives*, such as `Get` and
`It`, or built from other queries with *combinators*, such as
composition (`>>`). Let's explore some other combinators.

## Context & Counting

To count the number of departments in this `chicago` dataset we
write the query `Count(It.department)`. Observe that the argument
provided to `Count()`, `It.department`, is itself a query.

    chicago[Count(It.department)]
    #=>
    ┼───┼
    │ 2 │
    =#

We could also count the total number of employees across all
departments.

    chicago[Count(It.department.employee)]
    #=>
    ┼───┼
    │ 5 │
    =#

What if we wanted to count employees by department? Using query
composition (`>>`), we can perform `Count` in a nested context.

    chicago[It.department >> Count(It.employee)]
    #=>
    ──┼───┼
    1 │ 3 │
    2 │ 2 │
    =#

In this output, we see that one department has `3` employees,
while the other has `2`.

## Record Construction

Let's improve the previous query by including each department's
name alongside employee counts. This can be done by using the
`Record` combinator.

    chicago[
        It.department >>
        Record(It.name,
               Count(It.employee))]
    #=>
      │ department │
      │ name    #B │
    ──┼────────────┼
    1 │ POLICE   3 │
    2 │ FIRE     2 │
    =#

To label a record field we use Julia's `Pair` syntax, (`=>`).

    chicago[
        It.department >>
        Record(It.name,
               :size => Count(It.employee))]
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

This is syntax shorthand for the `Label` primitive.

    chicago[
        It.department >>
        Record(It.name,
               Count(It.employee) >> Label(:size))]
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

Rather than building a record from scratch, one could add a field
to an existing record using `Collect`.

    chicago[It.department >>
            Collect(:size => Count(It.employee))]
    #=>
      │ department                                                                │
      │ name    employee{name,position,salary}                               size │
    ──┼───────────────────────────────────────────────────────────────────────────┼
    1 │ POLICE  ANTHONY A, POLICE OFFICER, 72510; JEFFERY A, SERGEANT, 1014…    3 │
    2 │ FIRE    DANIEL A, FIREFIGHTER-EMT, 95484; ROBERT K, FIREFIGHTER-EMT…    2 │
    =#

If a label is set to `nothing` then that field is excluded.
This would let us restructure a record as we see fit.

    chicago[It.department >>
            Collect(:size => Count(It.employee),
                    :employee => nothing)]
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

Records can be nested. The following listing includes, for each
department, employees' name and salary.

    chicago[
        It.department >>
        Record(It.name,
               It.employee >>
               Record(It.name,
                      It.salary))]
    #=>
      │ department                                                  │
      │ name    employee{name,salary}                               │
    ──┼─────────────────────────────────────────────────────────────┼
    1 │ POLICE  ANTHONY A, 72510; JEFFERY A, 101442; NANCY A, 80016 │
    2 │ FIRE    DANIEL A, 95484; ROBERT K, 103272                   │
    =#

In this output, commas separate tuple fields and semi-colons
separate vector elements.

## Reusable Queries

Queries can be reused. Let's define `DeptSize` to be a query
that computes the number of employees in a department.

    DeptSize =
        :size =>
            Count(It.employee)

This query can be used in different ways.

    chicago[Max(It.department >> DeptSize)]
    #=>
    ┼───┼
    │ 3 │
    =#

    chicago[
        It.department >>
        Record(It.name, DeptSize)]
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

## Filtering Data

Let's extend the previous query to only show departments with more
than one employee. This can be done using the `Filter` combinator.

    chicago[
        It.department >>
        Record(It.name, DeptSize) >>
        Filter(It.size .> 2)]
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     3 │
    =#

To use regular operators in query expressions, we need to use
broadcasting notation, such as `.>` rather than `>` ; forgetting
the period is an easy mistake to make.

    chicago[
        It.department >>
        Record(It.name, DeptSize) >>
        Filter(It.size > 2)]
    #=>
    ERROR: MethodError: no method matching isless(::Int64, ::DataKnots.Navigation)
    ⋮
    =#

## Incremental Composition

Combinators let us construct queries incrementally. Let's explore
our Chicago data starting with a list of employees.

    Q = It.department.employee

    chicago[Q]
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER    72510 │
    2 │ JEFFERY A  SERGEANT         101442 │
    3 │ NANCY A    POLICE OFFICER    80016 │
    4 │ DANIEL A   FIREFIGHTER-EMT   95484 │
    5 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

Let's extend this query to show if the salary is over 100k.

    Q >>= Collect(:gt100k => It.salary .> 100000)

The query definition is tracked automatically.

    Q
    #=>
    It.department.employee >> Collect(:gt100k => It.salary .> 100000)
    =#

Let's run `Q` again.

    chicago[Q]
    #=>
      │ employee                                   │
      │ name       position         salary  gt100k │
    ──┼────────────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER    72510   false │
    2 │ JEFFERY A  SERGEANT         101442    true │
    3 │ NANCY A    POLICE OFFICER    80016   false │
    4 │ DANIEL A   FIREFIGHTER-EMT   95484   false │
    5 │ ROBERT K   FIREFIGHTER-EMT  103272    true │
    =#

We can now filter the dataset to include only high-paid employees.

    Q >>= Filter(It.gt100k)
    #=>
    It.department.employee >>
    Collect(:gt100k => It.salary .> 100000) >>
    Filter(It.gt100k)
    =#

Let's run `Q` again.

    chicago[Q]
    #=>
      │ employee                                   │
      │ name       position         salary  gt100k │
    ──┼────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT         101442    true │
    2 │ ROBERT K   FIREFIGHTER-EMT  103272    true │
    =#

Well-tested queries may benefit from a `Tag` so that their
definitions are suppressed in larger compositions.

    HighlyCompensated = Tag(:HighlyCompensated, Q)
    #-> HighlyCompensated

    chicago[HighlyCompensated]
    #=>
      │ employee                                   │
      │ name       position         salary  gt100k │
    ──┼────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT         101442    true │
    2 │ ROBERT K   FIREFIGHTER-EMT  103272    true │
    =#

This tagging can make subsequent compositions easier to read.

    Q = HighlyCompensated >> It.name
    #=>
    HighlyCompensated >> It.name
    =#

    chicago[Q]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ ROBERT K  │
    =#

## Aggregate Queries

We've demonstrated the `Count` combinator, but `Count` could also
be used as a query. In this next example, `Count` receives
employees as input, and produces their number as output.

    chicago[It.department.employee >> Count]
    #=>
    ┼───┼
    │ 5 │
    =#

Previously we've only seen *elementwise* queries, which emit an
output for each of its input elements. The `Count` query is an
*aggregate*, which means it emits an output for its entire input.

We may wish to count employees by department. Contrary to
expectation, adding parentheses will not change the output.

    chicago[It.department >> (It.employee >> Count)]
    #=>
    ┼───┼
    │ 5 │
    =#

To count employees in *each* department, we use the `Each()`
combinator, which evaluates its argument elementwise.

    chicago[It.department >> Each(It.employee >> Count)]
    #=>
    ──┼───┼
    1 │ 3 │
    2 │ 2 │
    =#

Alternatively, we could use the `Count()` combinator to get the
same result.

    chicago[It.department >> Count(It.employee)]
    #=>
    ──┼───┼
    1 │ 3 │
    2 │ 2 │
    =#

Which form of `Count` to use depends upon what is notationally
convenient. For incremental construction, being able to simply
append `>> Count` is often very helpful.

    Q = It.department.employee
    chicago[Q >> Count]
    #=>
    ┼───┼
    │ 5 │
    =#

We could then refine the query, and run the exact same command.

    Q >>= Filter(It.salary .> 100000)
    chicago[Q >> Count]
    #=>
    ┼───┼
    │ 2 │
    =#

## Summarizing Data

To summarize data, we could use query combinators such as `Min`,
`Max`, and `Sum`. Let's compute some salary statistics.

    Salary = It.department.employee.salary

    chicago[
        Record(
            :count => Count(Salary),
            :min => Min(Salary),
            :max => Max(Salary),
            :sum => Sum(Salary))]
    #=>
    │ count  min    max     sum    │
    ┼──────────────────────────────┼
    │     5  72510  103272  452724 │
    =#

Just as `Count` has an aggregate query form, so do `Min`, `Max`,
and `Sum`. The previous query could be written in aggregate form.

    chicago[
        Record(
            :count => Salary >> Count,
            :min => Salary >> Min,
            :max => Salary >> Max,
            :sum => Salary >> Sum)]
    #=>
    │ count  min    max     sum    │
    ┼──────────────────────────────┼
    │     5  72510  103272  452724 │
    =#

Let's calculate salary statistics by department.

    Salary = It.employee.salary

    chicago[
        It.department >>
        Record(
            It.name,
            :count => Count(Salary),
            :min => Min(Salary),
            :max => Max(Salary),
            :sum => Sum(Salary))]
    #=>
      │ department                           │
      │ name    count  min    max     sum    │
    ──┼──────────────────────────────────────┼
    1 │ POLICE      3  72510  101442  253968 │
    2 │ FIRE        2  95484  103272  198756 │
    =#

Summary combinators can be used to define domain specific
measures, such as `PayGap` and `AvgPay`.

    Salary = It.employee.salary
    PayGap = :paygap => Max(Salary) .- Min(Salary)
    AvgPay = :avgpay => Sum(Salary) ./ Count(It.employee)

    chicago[
        It.department >>
        Record(It.name, PayGap, AvgPay)]
    #=>
      │ department              │
      │ name    paygap  avgpay  │
    ──┼─────────────────────────┼
    1 │ POLICE   28932  84656.0 │
    2 │ FIRE      7788  99378.0 │
    =#

`Unique` is another combinator producing a summary value. Here, we
use `Unique` to return distinct positions by department.

    chicago[It.department >>
            Record(It.name,
                   Unique(It.employee.position))]
    #=>
      │ department                       │
      │ name    position                 │
    ──┼──────────────────────────────────┼
    1 │ POLICE  POLICE OFFICER; SERGEANT │
    2 │ FIRE    FIREFIGHTER-EMT          │
    =#

## Grouping Data

So far, we've navigated and summarized data by exploiting its
hierarchical organization: the whole dataset $\to$ department
$\to$ employee. But what if we want a query that isn't supported
by the existing hierarchy? For example, how could we calculate the
number of employees for each *position*?

A list of distinct positions could be obtained using `Unique`.

    chicago[It.department.employee.position >> Unique]
    #=>
      │ position        │
    ──┼─────────────────┼
    1 │ FIREFIGHTER-EMT │
    2 │ POLICE OFFICER  │
    3 │ SERGEANT        │
    =#

However, `Unique` is not sufficient because positions are not
associated to the respective employees. To associate employee
records to their positions, we use `Group` combinator:

    chicago[It.department.employee >> Group(It.position)]
    #=>
      │ position         employee{name,position,salary}                           │
    ──┼───────────────────────────────────────────────────────────────────────────┼
    1 │ FIREFIGHTER-EMT  DANIEL A, FIREFIGHTER-EMT, 95484; ROBERT K, FIREFIGHTER-…│
    2 │ POLICE OFFICER   ANTHONY A, POLICE OFFICER, 72510; NANCY A, POLICE OFFICE…│
    3 │ SERGEANT         JEFFERY A, SERGEANT, 101442                              │
    =#

The query `Group(It.position)` rearranges the dataset into a new
hierarchy: position $\to$ employee. We can use the new arrangement
to show employee names for each unique position.

    chicago[It.department.employee >>
            Group(It.position) >>
            Record(It.position, It.employee.name)]
    #=>
      │ position         name               │
    ──┼─────────────────────────────────────┼
    1 │ FIREFIGHTER-EMT  DANIEL A; ROBERT K │
    2 │ POLICE OFFICER   ANTHONY A; NANCY A │
    3 │ SERGEANT         JEFFERY A          │
    =#

We could further use summary combinators, which lets us answer the
original question: What is the number of employees for each
position?

    chicago[
        It.department.employee >>
        Group(It.position) >>
        Record(It.position,
               :count => Count(It.employee))]
    #=>
      │ position         count │
    ──┼────────────────────────┼
    1 │ FIREFIGHTER-EMT      2 │
    2 │ POLICE OFFICER       2 │
    3 │ SERGEANT             1 │
    =#

Moreover, we could reuse the previously defined employee measures.

    Salary = It.employee.salary
    PayGap = :paygap => Max(Salary) .- Min(Salary)
    AvgPay = :avgpay => Sum(Salary) ./ Count(It.employee)

    chicago[
        It.department.employee >>
        Group(It.position) >>
        Record(It.position, PayGap, AvgPay)]
    #=>
      │ position         paygap  avgpay   │
    ──┼───────────────────────────────────┼
    1 │ FIREFIGHTER-EMT    7788   99378.0 │
    2 │ POLICE OFFICER     7506   76263.0 │
    3 │ SERGEANT              0  101442.0 │
    =#

One could group by any query; here we group employees based upon a
salary threshold.

    GT100K = :gt100k => (It.salary .> 100000)

    chicago[
        It.department.employee >>
        Group(GT100K) >>
        Record(It.gt100k, It.employee.name)]
    #=>
      │ gt100k  name                         │
    ──┼──────────────────────────────────────┼
    1 │  false  ANTHONY A; NANCY A; DANIEL A │
    2 │   true  JEFFERY A; ROBERT K          │
    =#

We could also group by several queries.

    chicago[
        It.department.employee >>
        Group(It.position, GT100K) >>
        Record(It.position, It.gt100k, It.employee.name)]
    #=>
      │ position         gt100k  name               │
    ──┼─────────────────────────────────────────────┼
    1 │ FIREFIGHTER-EMT   false  DANIEL A           │
    2 │ FIREFIGHTER-EMT    true  ROBERT K           │
    3 │ POLICE OFFICER    false  ANTHONY A; NANCY A │
    4 │ SERGEANT           true  JEFFERY A          │
    =#

## Broadcasting over Queries

Any function could be applied to query arguments using Julia's
broadcasting notation.

    chicago[
        It.department.employee >>
        titlecase.(It.name)]
    #=>
    ──┼───────────┼
    1 │ Anthony A │
    2 │ Jeffery A │
    3 │ Nancy A   │
    4 │ Daniel A  │
    5 │ Robert K  │
    =#

Broadcasting can also used with operators. For example, let's
compute and display a 2% Cost Of Living Adjustment ("COLA").

    COLA = trunc.(Int, It.salary .* 0.02)

    chicago[
        It.department.employee >>
        Record(It.name,
               :old_salary => It.salary,
               :COLA       => "+" .* string.(COLA),
               :new_salary => It.salary .+ COLA)]
    #=>
      │ employee                                 │
      │ name       old_salary  COLA   new_salary │
    ──┼──────────────────────────────────────────┼
    1 │ ANTHONY A       72510  +1450       73960 │
    2 │ JEFFERY A      101442  +2028      103470 │
    3 │ NANCY A         80016  +1600       81616 │
    4 │ DANIEL A        95484  +1909       97393 │
    5 │ ROBERT K       103272  +2065      105337 │
    =#

Functions taking a vector argument, such as `mean`, can also be
applied to queries. In this example, `mean` computes the average
employee salary by department.

    using Statistics: mean

    chicago[
        It.department >>
        Record(
            It.name,
            :mean_salary => mean.(It.employee.salary))]
    #=>
      │ department          │
      │ name    mean_salary │
    ──┼─────────────────────┼
    1 │ POLICE      84656.0 │
    2 │ FIRE        99378.0 │
    =#

## Keeping Values

Suppose we'd like to list employee names together with their
department. The naive approach won't work because `department` is
not available in the context of an employee.

    chicago[
        It.department >>
        It.employee >>
        Record(It.name, It.department.name)]
    #-> ERROR: cannot find "department" ⋮

This can be overcome by using `Keep` to label an expression's
result, so that it is available within subsequent computations.

    chicago[
        It.department >>
        Keep(:dept_name => It.name) >>
        It.employee >>
        Record(It.name, It.dept_name)]
    #=>
      │ employee             │
      │ name       dept_name │
    ──┼──────────────────────┼
    1 │ ANTHONY A  POLICE    │
    2 │ JEFFERY A  POLICE    │
    3 │ NANCY A    POLICE    │
    4 │ DANIEL A   FIRE      │
    5 │ ROBERT K   FIRE      │
    =#

This pattern also emerges when a filter condition uses a parameter
calculated in a parent context. For example, let's list employees
with a higher than average salary for their department.

    chicago[
        It.department >>
        Keep(:mean_salary => mean.(It.employee.salary)) >>
        It.employee >>
        Filter(It.salary .> It.mean_salary)]
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT         101442 │
    2 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

## Query Parameters

Parameters let us reuse complex queries without changing their
definition. Here we construct a query that depends upon the
parameter `AMT`, which is capitalized by convention.

    PaidOverAmt =
        It.department >>
        It.employee >>
        Filter(It.salary .> It.AMT) >>
        It.name

Query parameters are passed as keyword arguments.

    chicago[AMT=100000, PaidOverAmt]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ ROBERT K  │
    =#

What if we want to return employees who have a greater than average
salary? This average could be computed first.

    MeanSalary = mean.(It.department.employee.salary)

    mean_salary = chicago[MeanSalary]
    #=>
    ┼─────────┼
    │ 90544.8 │
    =#

Then, this value could be passed as our parameter.

    chicago[PaidOverAmt, AMT=mean_salary]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    3 │ ROBERT K  │
    =#

This approach performs composition outside of the query language.
To evaluate a query and immediately use it as a parameter within
the same query expression, we could use the `Given` combinator.

    chicago[Given(:AMT => MeanSalary, PaidOverAmt)]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    3 │ ROBERT K  │
    =#

## Query Functions

Let's make a function `EmployeesOver` that produces employees with
a salary greater than the given threshold. The threshold value
`AMT` is evaluated and then made available in the context of each
employee with the `Given` combinator.

    EmployeesOver(X) =
        Given(:AMT => X,
            It.department >>
            It.employee >>
            Filter(It.salary .> It.AMT))

    chicago[EmployeesOver(100000)]
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT         101442 │
    2 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

`EmployeesOver` can take a query as an argument. For example,
let's find employees with higher than average salary.

    MeanSalary = mean.(It.department.employee.salary)

    chicago[EmployeesOver(MeanSalary)]
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT         101442 │
    2 │ DANIEL A   FIREFIGHTER-EMT   95484 │
    3 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

Note that this combination is yet another query that could be
further refined.

    chicago[EmployeesOver(MeanSalary) >> It.name]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    3 │ ROBERT K  │
    =#

Alternatively, this query function could have been defined using
`Keep`. We use `Given` because it doesn't leak parameters.
Specifically, `It.AMT` is not available outside `EmployeesOver()`.

    chicago[EmployeesOver(MeanSalary) >> It.AMT]
    #-> ERROR: cannot find "AMT" ⋮

## Paging Data

Sometimes query results can be quite large. In this case it's
helpful to `Take` or `Drop` items from the input. Let's start by
listing all 5 employees of our toy database.

    Employee = It.department.employee
    chicago[Employee]
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER    72510 │
    2 │ JEFFERY A  SERGEANT         101442 │
    3 │ NANCY A    POLICE OFFICER    80016 │
    4 │ DANIEL A   FIREFIGHTER-EMT   95484 │
    5 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

To return only the first 2 records, we use `Take`.

    chicago[Employee >> Take(2)]
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   72510 │
    2 │ JEFFERY A  SERGEANT        101442 │
    =#

A negative index counts records from the end of the input. So, to
return all the records but the last two, we write:

    chicago[Employee >> Take(-2)]
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   72510 │
    2 │ JEFFERY A  SERGEANT        101442 │
    3 │ NANCY A    POLICE OFFICER   80016 │
    =#

To skip the first two records, returning the rest, we use `Drop`.

    chicago[Employee >> Drop(2)]
    #=>
      │ employee                          │
      │ name      position         salary │
    ──┼───────────────────────────────────┼
    1 │ NANCY A   POLICE OFFICER    80016 │
    2 │ DANIEL A  FIREFIGHTER-EMT   95484 │
    3 │ ROBERT K  FIREFIGHTER-EMT  103272 │
    =#

To return the 1st half of the employees in the database, we could
use `Take` with an argument that computes how many to take.

    chicago[Employee >> Take(Count(Employee) .÷ 2)]
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   72510 │
    2 │ JEFFERY A  SERGEANT        101442 │
    =#

## Extracting Data

Given any `DataKnot`, its content can be extracted using `get`.
For singular output, `get` returns a scalar value.

    get(chicago[Count(It.department)])
    #-> 2

For plural output, `get` returns a `Vector`.

    get(chicago[It.department.employee.name])
    #-> ["ANTHONY A", "JEFFERY A", "NANCY A", "DANIEL A", "ROBERT K"]

For more complex outputs, `get` may return a `@VectorTree`, which
is an `AbstractVector` specialized for column-oriented storage.

    query = It.department >>
            Record(It.name,
                   :size => Count(It.employee))
    vt = get(chicago[query])
    display(vt)
    #=>
    @VectorTree of 2 × (name = (1:1) × String, size = (1:1) × Int64):
     (name = "POLICE", size = 3)
     (name = "FIRE", size = 2)
    =#

## The `@query` Notation

Queries could be written using a convenient path-like notation
provided by the `@query` macro. In this notation:

* bare identifiers are translated to navigation with `Get`;
* query combinators, such as `Count(X)`, use lower-case names;
* the period (`.`) is used for query composition (`>>`);
* aggregate queries, such as `Count`, require parentheses;
* records can be constructed using curly brackets, `{}`; and
* functions and operators are lifted automatically.

The `@query` Notation        | Equivalent Query
-----------------------------|------------------------------------
`department`                 | `Get(:department)`
`count(department)`          | `Count(Get(:department))`
`department.count()`         | `Get(:department) >> Count`
`department.employee`        | `Get(:department) >> Get(:employee)`
`department.count(employee)` | `Get(:department) >> Count(Get(:employee))`
`department{name}`           | `Get(:department) >> Record(Get(:name))`

A `@query` macro with one argument creates a query object.

    @query department.name
    #-> Get(:department) >> Get(:name)

This query object could be used to query a `DataKnot` as usual.

    chicago[@query department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

Alternatively, we can provide the input dataset as an argument
to `@query`.

    @query chicago department.name
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

Queries could also be composed by placing the query components in
a `begin`/`end` block.

    @query begin
        department
        count(employee)
    end
    #-> Get(:department) >> Count(Get(:employee))

Curly brackets `{}` are used to construct `Record` queries.

    @query department{name, count(employee)}
    #-> Get(:department) >> Record(Get(:name), Count(Get(:employee)))

    @query chicago department{name, count(employee)}
    #=>
      │ department │
      │ name    #B │
    ──┼────────────┼
    1 │ POLICE   3 │
    2 │ FIRE     2 │
    =#

Combinators, such as `Filter` and `Keep`, are available, using
lower-case names. Operators and functions are automatically lifted
to queries.

    using Statistics: mean

    @query chicago begin
               department
               keep(avg_salary => mean(employee.salary))
               employee
               filter(salary > avg_salary)
               {name, salary}
           end
    #=>
      │ employee          │
      │ name       salary │
    ──┼───────────────────┼
    1 │ JEFFERY A  101442 │
    2 │ ROBERT K   103272 │
    =#

In `@query` notation, query aggregates, such as `Count` and
`Unique`, are lower-case and require parentheses.

    @query chicago department.employee.position.unique().count()
    #=>
    ┼───┼
    │ 3 │
    =#

Query parameters are passed as keyword arguments to `@query`.

    @query chicago begin
        department
        employee
        filter(salary>threshold)
    end threshold=90544.8
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT         101442 │
    2 │ DANIEL A   FIREFIGHTER-EMT   95484 │
    3 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

To embed regular Julia variables and expressions from within a
`@query`, use the interpolation syntax (`$`).

    threshold = 90544.8

    @query chicago begin
               department.employee
               filter(salary>$threshold)
               {name, salary,
                over => salary - $(trunc(Int, threshold))}
           end
    #=>
      │ employee                 │
      │ name       salary  over  │
    ──┼──────────────────────────┼
    1 │ JEFFERY A  101442  10898 │
    2 │ DANIEL A    95484   4940 │
    3 │ ROBERT K   103272  12728 │
    =#

We can use `@query` to define reusable queries and combinators.

    salary = @query department.employee.salary

    stats(x) = @query {min=>min($x),
                       max=>max($x),
                       count=>count($x)}

    @query chicago stats($salary)
    #=>
    │ min    max     count │
    ┼──────────────────────┼
    │ 72510  103272      5 │
    =#

## Importing & Exporting Data

We can import directly from systems that support the `Tables.jl`
interface. Here is a tabular variant of the chicago dataset.

    using CSV

    employee_data = """
        name,department,position,salary,rate
        "JEFFERY A","POLICE","SERGEANT",101442,
        "NANCY A","POLICE","POLICE OFFICER",80016,
        "ANTHONY A","POLICE","POLICE OFFICER",72510,
        "ALBA M","POLICE","POLICE CADET",,9.46
        "JAMES A","FIRE","FIRE ENGINEER-EMT",103350,
        "DANIEL A","FIRE","FIREFIGHTER-EMT",95484,
        "ROBERT K","FIRE","FIREFIGHTER-EMT",103272,
        "LAKENYA A","OEMC","CROSSING GUARD",,17.68
        "DORIS A","OEMC","CROSSING GUARD",,19.38
        "BRENDA B","OEMC","TRAFFIC CONTROL AIDE",64392,
        """ |> IOBuffer |> CSV.File

    chicago′ = DataKnot(:employee => employee_data)

    chicago′[It.employee]
    #=>
       │ employee                                                   │
       │ name       department  position              salary  rate  │
    ───┼────────────────────────────────────────────────────────────┼
     1 │ JEFFERY A  POLICE      SERGEANT              101442        │
     2 │ NANCY A    POLICE      POLICE OFFICER         80016        │
     3 │ ANTHONY A  POLICE      POLICE OFFICER         72510        │
     4 │ ALBA M     POLICE      POLICE CADET                   9.46 │
     5 │ JAMES A    FIRE        FIRE ENGINEER-EMT     103350        │
     6 │ DANIEL A   FIRE        FIREFIGHTER-EMT        95484        │
     7 │ ROBERT K   FIRE        FIREFIGHTER-EMT       103272        │
     8 │ LAKENYA A  OEMC        CROSSING GUARD                17.68 │
     9 │ DORIS A    OEMC        CROSSING GUARD                19.38 │
    10 │ BRENDA B   OEMC        TRAFFIC CONTROL AIDE   64392        │
    =#

This tabular data could be filtered to show employees that are
paid more than average. Let's also prune the `rate` column.

    using Statistics: mean

    highly_compensated =
        chicago′[Keep(:avg_salary => mean.(It.employee.salary)) >>
                 It.employee >>
                 Filter(It.salary .> It.avg_salary) >>
                 Collect(:rate => nothing)]
    #=>
      │ employee                                         │
      │ name       department  position           salary │
    ──┼──────────────────────────────────────────────────┼
    1 │ JEFFERY A  POLICE      SERGEANT           101442 │
    2 │ JAMES A    FIRE        FIRE ENGINEER-EMT  103350 │
    3 │ DANIEL A   FIRE        FIREFIGHTER-EMT     95484 │
    4 │ ROBERT K   FIRE        FIREFIGHTER-EMT    103272 │
    =#

We can then export this data.

    using DataFrames

    highly_compensated |> DataFrame
    #=>
    4×4 DataFrames.DataFrame
    │ Row │ name      │ department │ position          │ salary │
    │     │ String    │ String     │ String            │ Int64⍰ │
    ├─────┼───────────┼────────────┼───────────────────┼────────┤
    │ 1   │ JEFFERY A │ POLICE     │ SERGEANT          │ 101442 │
    │ 2   │ JAMES A   │ FIRE       │ FIRE ENGINEER-EMT │ 103350 │
    │ 3   │ DANIEL A  │ FIRE       │ FIREFIGHTER-EMT   │ 95484  │
    │ 4   │ ROBERT K  │ FIRE       │ FIREFIGHTER-EMT   │ 103272 │
    =#

## Restructuring Imported Data

After importing tabular data, it is sometimes helpful to
restructure hierarchically to make queries more convenient. We've
seen earlier how this could be done with `Group` combinator.

    chicago′[It.employee >> Group(It.department)]
    #=>
      │ department  employee{name,department,position,salary,rate}                │
    ──┼───────────────────────────────────────────────────────────────────────────┼
    1 │ FIRE        JAMES A, FIRE, FIRE ENGINEER-EMT, 103350, missing; DANIEL A, …│
    2 │ OEMC        LAKENYA A, OEMC, CROSSING GUARD, missing, 17.68; DORIS A, OEM…│
    3 │ POLICE      JEFFERY A, POLICE, SERGEANT, 101442, missing; NANCY A, POLICE…│
    =#

With a some labeling, this hierarchy could be transformed so that
its structure is compatible with our initial `chicago` dataset.

    Restructure =
        :department =>
            It.employee >>
            Group(It.department) >>
            Record(
               :name => It.department,
               :employee =>
                   It.employee >>
                   Collect(:department => nothing))

    chicago′[Restructure]
    #=>
      │ department                                                                │
      │ name    employee{name,position,salary,rate}                               │
    ──┼───────────────────────────────────────────────────────────────────────────┼
    1 │ FIRE    JAMES A, FIRE ENGINEER-EMT, 103350, missing; DANIEL A, FIREFIGHTE…│
    2 │ OEMC    LAKENYA A, CROSSING GUARD, missing, 17.68; DORIS A, CROSSING GUAR…│
    3 │ POLICE  JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE OFFICER, 80…│
    =#

Using `Collect` we could save this restructured dataset as a
top-level field, `department`.

    chicago″ = chicago′[Restructure >> Collect]
    #=>
    │ employee{name,department,position,sa… department{name,employee{name,positio…│
    ┼─────────────────────────────────────────────────────────────────────────────┼
    │ JEFFERY A, POLICE, SERGEANT, 101442,… FIRE, [JAMES A, FIRE ENGINEER-EMT, 10…│
    =#

Then, queries that originally worked with our hierarchical
`chicago` dataset would now work with this imported and then
restructured `chicago″` data. For example, we could once again
compute the average employee salary by department.

    using Statistics: mean

    chicago″[
        It.department >>
        Record(
            It.name,
            :mean_salary => mean.(It.employee.salary))]
    #=>
      │ department          │
      │ name    mean_salary │
    ──┼─────────────────────┼
    1 │ FIRE       100702.0 │
    2 │ OEMC        64392.0 │
    3 │ POLICE      84656.0 │
    =#

