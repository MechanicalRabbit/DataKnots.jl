# Working with Dynamically Typed Data

It's possible to use DataKnots with hierarchical data structures, such
as those provided via a JSON. The principle challenge is that DataKnots
doesn't know in advance about the schema to expect. In these cases, a
data conversion that provides this type information is required.

To start working with DataKnots and JSON, we import the packages:

    using DataKnots
    using JSON

Let's use a small slice of Chicago employee data in JSON format.

    data = JSON.parse("""
        { "departments": [
           { "name": "FIRE",
             "employees": [
              { "name": "DANIEL A",
                "position": "FIRE FIGHTER-EMT",
                "salary": 95484,
                "overtime": [
                 { "month": "2018-02", "amount": 108 }]},
              { "name": "JAMES A",
                "position": "FIRE ENGINEER-EMT",
                "salary": 103350,
                "overtime": [
                 { "month": "2018-01", "amount": 8776 },
                 { "month": "2018-03", "amount": 351 },
                 { "month": "2018-04", "amount": 10532 },
                 { "month": "2018-05", "amount": 351 },
                 { "month": "2018-06", "amount": 8776 },
                 { "month": "2018-07", "amount": 10532 }]},
              { "name": "ROBERT K",
                "position": "FIRE FIGHTER-EMT",
                "salary": 103272,
                "overtime": [
                 { "month": "2018-05", "amount": 1754 }]}]},
           { "name": "OEMC",
             "employees": [
              { "name": "LAKENYA A",
                "position": "CROSSING GUARD",
                "salary": null, "rate": 17.68 },
              { "name": "DORIS A",
                "position": "CROSSING GUARD",
                "salary": null, "rate": 19.38 },
              { "name": "BRENDA B",
                "position": "TRAFFIC CONTROL AIDE",
                "salary": 64392, "rate": null }]},
           { "name": "POLICE",
             "employees": [
              { "name": "ANTHONY A",
                "position": "POLICE OFFICER",
                "salary": 92510,
                "overtime": null},
              { "name": "JEFFERY A",
                "position": "SERGEANT",
                "salary": 101442, "rate": null,
                "overtime": [
                 { "month": "2018-05", "amount": 1319 }]},
              { "name": "NANCY A",
                "position": "POLICE OFFICER",
                "salary": 80016, "rate": null,
                "overtime": [
                 { "month": "2018-01", "amount": 173 },
                 { "month": "2018-02", "amount": 461 },
                 { "month": "2018-03", "amount": 461 },
                 { "month": "2018-04", "amount": 1056 },
                 { "month": "2018-05", "amount": 1933 }]},
              { "name": "ALBA M",
                "position": "POLICE CADET",
                "salary": null, "rate": 9.46,
                "overtime": []}]}]}
    """)
    #-> Dict{String, Any}("departments" => Any[Dict{String, Any}("name" =>…

We can convert this to a DataKnot. This shows our data converted as a
single `Dict` value.

    knot = convert(DataKnot, data)
    #=>
    ┼─────────────────────────────────────────────────────────────────────┼
    │ Dict{String, Any}(\"departments\"=>Any[Dict{String, Any}(\"name\"=>…│
    =#

Out of the box, `DataKnots` knows about `Dict` (and `NamedTuple`)
objects, hence we can extract the value of the top level dictionary.

    knot[It.departments]
    #=>
    │ departments                                                         │
    ┼─────────────────────────────────────────────────────────────────────┼
    │ Any[Dict{String, Any}(\"name\"=>\"FIRE\", \"employees\"=>Any[Dict{S…│
    =#

Unfortunately, this is as far as we can go. We can see from this display
that we have a `Vector` of `Any` that happens to contain `Dict` objects.
However, when our query is compiled, this information isn't available.

## Providing Type Information

To let us query this structure, we need to provide DataKnots detail
about what sort of objects to expect. This can be done with `Is`.

    Convert = It.departments >> Is(Vector{Any})
    #-> It.departments >> Is(Vector{Any})

    knot[Convert]
    #=>
      │ departments                                                       │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ Dict{String, Any}(\"name\"=>\"FIRE\", \"employees\"=>Any[Dict{Str…│
    2 │ Dict{String, Any}(\"name\"=>\"OEMC\", \"employees\"=>Any[Dict{Str…│
    3 │ Dict{String, Any}(\"name\"=>\"POLICE\", \"employees\"=>Any[Dict{S…│
    =#

While JSON schemas use plural forms of a noun to represent containers,
in DataKnots everything is a flow. Hence, it is our preference to
relabel this output to use a singular form of the noun.

    Convert >>= Label(:department)
    #-> It.departments >> Is(Vector{Any}) >> Label(:department)

    knot[Convert]
    #=>
      │ department                                                        │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ Dict{String, Any}(\"name\"=>\"FIRE\", \"employees\"=>Any[Dict{Str…│
    2 │ Dict{String, Any}(\"name\"=>\"OEMC\", \"employees\"=>Any[Dict{Str…│
    3 │ Dict{String, Any}(\"name\"=>\"POLICE\", \"employees\"=>Any[Dict{S…│
    =#

Here we have a flow with 3 `Dict` objects that encode each `department`
records. Let's suppose we want to return the `name` of each department.

    knot[Convert >> It.name]
    #=>
    ERROR: cannot find "name" at
    (0:N) × Any
    =#

Unfortunately, this is an error, since the `Vector` could contain `Any`
object. To address this, we could use `Is(Dict{String,Any})`.

    Convert >>= Is(Dict{String,Any})
    #=>
    It.departments >>
    Is(Vector{Any}) >>
    Label(:department) >>
    Is(Dict{String, Any})
    =#

    knot[Convert >> It.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ FIRE   │
    2 │ OEMC   │
    3 │ POLICE │
    =#

Even though the query results here look OK, DataKnots sees the flow as
containing `Any` object.

    show(as=:shape, knot[Convert >> It.name])
    #=>
    3-element DataKnot:
      name  0:N × Any
    =#

So, it's prudent to also expressly provide a type for `name`. While
we're at it, let's start building our `Record` object.

    Convert >>= Record(
        :name => It.name >> Is(String),
        :employee => It.employees)
    #=>
    It.departments >>
    Is(Vector{Any}) >>
    Label(:department) >>
    Is(Dict{String, Any}) >>
    Record(:name => It.name >> Is(String), :employee => It.employees)
    =#

    knot[Convert >> It.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ FIRE   │
    2 │ OEMC   │
    3 │ POLICE │
    =#

The list of `employee` records follows a similar pattern. It's a
`Vector{Any}` containing `Dict{String,Any}`. We can use `Collect` to
rewrite our `employee` slot to have this type information.

    Convert >>= Collect(
        :employee => It.employee >> Is(Vector{Any}) >>
                     Is(Dict{String,Any}))
    #=>
    It.departments >>
    Is(Vector{Any}) >>
    Label(:department) >>
    Is(Dict{String, Any}) >>
    Record(:name => It.name >> Is(String), :employee => It.employees) >>
    Collect(:employee =>
                It.employee >> Is(Vector{Any}) >> Is(Dict{String, Any}))
    =#

    knot[Convert]
    #=>
      │ department                                                        │
      │ name    employee                                                  │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ FIRE    Dict{String, Any}(\"name\"=>\"DANIEL A\", \"position\"=>\…│
    2 │ OEMC    Dict{String, Any}(\"name\"=>\"LAKENYA A\", \"rate\"=>17.6…│
    3 │ POLICE  Dict{String, Any}(\"name\"=>\"ANTHONY A\", \"position\"=>…│
    =#

At this point, we could actually do some queries.

    knot[Convert >> Record(It.name, :count => Count(It.employee))]
    #=>
      │ department    │
      │ name    count │
    ──┼───────────────┼
    1 │ FIRE        3 │
    2 │ OEMC        3 │
    3 │ POLICE      4 │
    =#

Next up. Let's convert employee records.

## Handling Missing and Nothing

So that we can think about how to convert each `employee` record, let's
look at the employees in a particular department.

    police = knot[Convert >> Filter(It.name .== "POLICE") >> It.employee]
    #=>
      │ employee                                                          │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ Dict{String, Any}(\"name\"=>\"ANTHONY A\", \"position\"=>\"POLICE…│
    2 │ Dict{String, Any}(\"name\"=>\"JEFFERY A\", \"rate\"=>nothing, \"p…│
    3 │ Dict{String, Any}(\"name\"=>\"NANCY A\", \"rate\"=>nothing, \"pos…│
    4 │ Dict{String, Any}(\"name\"=>\"ALBA M\", \"rate\"=>9.46, \"positio…│
    =#

Let's start with a provisional record query for each employee.

    AsEmployee = Record(
        It.name >> Is(String),
        It.position >> Is(String),
        It.salary, It.rate, It.overtime)

    police[AsEmployee]
    #=>
      │ employee                                                          │
      │ name       position        salary  rate        overtime           │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   92510  missing                        │
    2 │ JEFFERY A  SERGEANT        101442              Any[Dict{String, A…│
    3 │ NANCY A    POLICE OFFICER   80016              Any[Dict{String, A…│
    4 │ ALBA M     POLICE CADET                  9.46  Any[]              │
    =#

This data is showing `missing` for `rate` on some lines, but an empty
slot on others. We could broadcast `typeof` to see what data types
actually appear in the current data set.

    police[AsEmployee >> Record(
            typeof.(It.rate), typeof.(It.salary), typeof.(It.overtime))]
    #=>
      │ employee                      │
      │ #A       #B       #C          │
    ──┼───────────────────────────────┼
    1 │ Missing  Int64    Nothing     │
    2 │ Nothing  Int64    Vector{Any} │
    3 │ Nothing  Int64    Vector{Any} │
    4 │ Float64  Nothing  Vector{Any} │
    =#

Here we can see that some of these values are `nothing`. This happens
when the `JSON` loader encounters a `null` value. In these cases, it may
be helpful to treat them as being `missing`.

    AsEmployee >>=
       Collect(:rate => something.(It.rate, missing),
               :salary => something.(It.salary, missing),
               :overtime => something.(It.overtime, missing))

    police[AsEmployee >> Record(
            typeof.(It.rate), typeof.(It.salary), typeof.(It.overtime))]
    #=>
      │ employee                      │
      │ #A       #B       #C          │
    ──┼───────────────────────────────┼
    1 │ Missing  Int64    Missing     │
    2 │ Missing  Int64    Vector{Any} │
    3 │ Missing  Int64    Vector{Any} │
    4 │ Float64  Missing  Vector{Any} │
    =#

For `overtime` we might further treat omitted entries as an empty
vector, so that we an apply a consistent data type.

    AsEmployee >>=
       Collect(:overtime => coalesce.(It.overtime, Ref(Any[])))

    police[AsEmployee >> Record(
            typeof.(It.rate), typeof.(It.salary), typeof.(It.overtime))]
    #=>
      │ employee                      │
      │ #A       #B       #C          │
    ──┼───────────────────────────────┼
    1 │ Missing  Int64    Vector{Any} │
    2 │ Missing  Int64    Vector{Any} │
    3 │ Missing  Int64    Vector{Any} │
    4 │ Float64  Missing  Vector{Any} │
    =#

Even though our data may be looking alright, it's still incomplete since
DataKnots doesn't know about the expected data types.

    show(as=:shape, police[AsEmployee])
    #=>
    4-element DataKnot:
      employee    0:N
      ├╴name      1:1 × String
      ├╴position  1:1 × String
      ├╴salary    1:1 × Any
      ├╴rate      1:1 × Any
      └╴overtime  1:1 × Any
    =#

We can address this using the `Is` combinator.

    AsEmployee >>=
       Collect(It.rate >> Is(Union{Float64, Missing}),
               It.salary >> Is(Union{Int64, Missing}),
               It.overtime >> Is(Vector{Any}))

    police[AsEmployee]
    #=>
      │ employee                                                          │
      │ name       position        salary  rate  overtime                 │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   92510                                 │
    2 │ JEFFERY A  SERGEANT        101442        Dict{String, Any}(\"amou…│
    3 │ NANCY A    POLICE OFFICER   80016        Dict{String, Any}(\"amou…│
    4 │ ALBA M     POLICE CADET            9.46                           │
    =#

As it turns out, in this particular dataset, `overtime` is thankfully
uncomplicated.  It is a dictionary with two keys, `month` and `amount`.

    police[AsEmployee >> It.overtime]
    #=>
      │ overtime                                                    │
    ──┼─────────────────────────────────────────────────────────────┼
    1 │ Dict{String, Any}(\"amount\"=>1319, \"month\"=>\"2018-05\") │
    2 │ Dict{String, Any}(\"amount\"=>173, \"month\"=>\"2018-01\")  │
    3 │ Dict{String, Any}(\"amount\"=>461, \"month\"=>\"2018-02\")  │
    4 │ Dict{String, Any}(\"amount\"=>461, \"month\"=>\"2018-03\")  │
    5 │ Dict{String, Any}(\"amount\"=>1056, \"month\"=>\"2018-04\") │
    6 │ Dict{String, Any}(\"amount\"=>1933, \"month\"=>\"2018-05\") │
    =#

We can provide type information, and build a Record object.

    AsEmployee >>=
       Collect(It.overtime >> Is(Dict{String, Any}) >>
                              Record(It.amount >> Is(Int64),
                                     It.month >> Is(String)))

    police[AsEmployee >> It.overtime]
    #=>
      │ overtime        │
      │ amount  month   │
    ──┼─────────────────┼
    1 │   1319  2018-05 │
    2 │    173  2018-01 │
    3 │    461  2018-02 │
    4 │    461  2018-03 │
    5 │   1056  2018-04 │
    6 │   1933  2018-05 │
    =#

This can be seen together as follows.

    police[AsEmployee]
    #=>
      │ employee                                                          │
      │ name       position        salary  rate  overtime{amount,month}   │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   92510                                 │
    2 │ JEFFERY A  SERGEANT        101442        1319, 2018-05            │
    3 │ NANCY A    POLICE OFFICER   80016        173, 2018-01; 461, 2018-…│
    4 │ ALBA M     POLICE CADET            9.46                           │
    =#

Finally, we can attach the remaining aspects of our employee query to
the main data conversion query.

    Convert >>= Collect(It.employee >> AsEmployee)

It's also customary to wrap the final conversion query as a
single record.

    Convert = Record(Convert)

Once this is done, we can apply the conversion to our test data,
and look at the shape of its output.

    show(as=:shape, knot[Convert])
    #=>
    1-element DataKnot:
      #               1:1
      └╴department    0:N
        ├╴name        1:1 × String
        └╴employee    0:N
          ├╴name      1:1 × String
          ├╴position  1:1 × String
          ├╴salary    0:1 × Int64
          ├╴rate      0:1 × Float64
          └╴overtime  0:N
            ├╴amount  1:1 × Int64
            └╴month   1:1 × String
    =#

The `Convert` query can also be printed in whole, enabling one to look
at the composite of all of these individual transformations. (TODO: note
that `[]` in the query below should be `Ref([])`, but it is not being
reproduced properly.)

    Convert
    #=>
    Record(It.departments >>
           Is(Vector{Any}) >>
           Label(:department) >>
           Is(Dict{String, Any}) >>
           Record(:name => It.name >> Is(String),
                  :employee => It.employees) >>
           Collect(:employee => It.employee >>
                                Is(Vector{Any}) >>
                                Is(Dict{String, Any})) >>
           Collect(It.employee >>
                   Record(It.name >> Is(String),
                          It.position >> Is(String),
                          It.salary,
                          It.rate,
                          It.overtime) >>
                   Collect(:rate => something.(It.rate, missing),
                           :salary => something.(It.salary, missing),
                           :overtime =>
                               something.(It.overtime, missing)) >>
                   Collect(:overtime => coalesce.(It.overtime, [])) >>
                   Collect(It.rate >> Is(Union{Missing, Float64}),
                           It.salary >> Is(Union{Missing, Int64}),
                           It.overtime >> Is(Vector{Any})) >>
                   Collect(It.overtime >>
                           Is(Dict{String, Any}) >>
                           Record(It.amount >> Is(Int64),
                                  It.month >> Is(String)))))
    =#

One final note. There is a difference between these two expressions.

    knot[Convert][Count(It.department)]
    #=>
    ┼───┼
    │ 3 │
    =#

    knot[Convert >> Count(It.department)]
    #=>
    ┼───┼
    │ 3 │
    =#

The former runs the full conversion against the entire input, and then,
upon that output runs another simpler query to count the number of
departments. The latter, combines the conversion with the counting, and
during query optimization, eliminates conversion that isn't needed.

    chicago = knot[Convert]
    #=>
    │ department{name,employee{name,position,salary,rate,overtime{amount,…│
    ┼─────────────────────────────────────────────────────────────────────┼
    │ FIRE, [DANIEL A, FIRE FIGHTER-EMT, 95484, missing, [108, 2018-02]; …│
    =#

Hence, the statement above converts the entirety of the input data, and
stores it in an in-memory `DataKnot` called `chicago`. Note that it
mirrors the original JSON, with a single top-level dictionary.

## Querying our Dataset

With this hierarchical data converted, it can now be queried. Let's
first count the number of employees by department.

    chicago[It.department >>
            Record(It.name, :count => Count(It.employee))]
    #=>
      │ department    │
      │ name    count │
    ──┼───────────────┼
    1 │ FIRE        3 │
    2 │ OEMC        3 │
    3 │ POLICE      4 │
    =#

This can also be queried using our `@query` macro.

    @query chicago department{name, count=>count(employee)}
    #=>
      │ department    │
      │ name    count │
    ──┼───────────────┼
    1 │ FIRE        3 │
    2 │ OEMC        3 │
    3 │ POLICE      4 │
    =#

To find employees having greater than average salary within
their department, we write:

    using Statistics: mean

    @query chicago begin
        department
        let avg_salary => mean(employee.salary)
            employee
            filter(salary > avg_salary)
        end
    end
    #=>
      │ employee                                                          │
      │ name       position           salary  rate  overtime{amount,month…│
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ JAMES A    FIRE ENGINEER-EMT  103350        8776, 2018-01; 351, 2…│
    2 │ ROBERT K   FIRE FIGHTER-EMT   103272        1754, 2018-05         │
    3 │ ANTHONY A  POLICE OFFICER      92510                              │
    4 │ JEFFERY A  SERGEANT           101442        1319, 2018-05         │
    =#

Without a macro, this query could be written:

    chicago[
       It.department >>
       Keep(:avg_salary => mean.(It.employee.salary)) >>
       It.employee >>
       Filter(It.salary .> It.avg_salary)
    ]
    #=>
      │ employee                                                          │
      │ name       position           salary  rate  overtime{amount,month…│
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ JAMES A    FIRE ENGINEER-EMT  103350        8776, 2018-01; 351, 2…│
    2 │ ROBERT K   FIRE FIGHTER-EMT   103272        1754, 2018-05         │
    3 │ ANTHONY A  POLICE OFFICER      92510                              │
    4 │ JEFFERY A  SERGEANT           101442        1319, 2018-05         │
    =#
