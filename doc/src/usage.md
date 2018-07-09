# Usage Guide

## What is a DataKnot?

A DataKnot is an in-memory column store.  It may contain tabular data, a
collection of interrelated tables, or hierarchical data such as JSON or XML.
It can also serve as an interface to external data sources such as SQL
databases.

To start working with DataKnots, we import the package:

    using DataKnots


## Querying tabular data

In this section, we demonstrate how to use DataKnots.jl to query tabular data.

First, we load some sample data from a CSV file.  We use the (???) data set,
which is packaged as a part of DataKnots.jl.

```julia
# Path to ???.csv.
DATA = joinpath(Base.find_package("DataKnots"),
                "test/data/???.csv")

usedb!(data = LoadCSV(DATA))
```

This command loads tabular data from ???.csv and adds it to the current
database under the name `data`.  We can now query it.

*Show the whole dataset.*

```julia
@query data
#=>
...
=#
```

*Show all the salaries.*

```julia
@query data.salary
#=>
...
=#
```

*Show the number of rows in the dataset.*

```julia
@query count(data)
#=>
...
=#
```

*Show the mean salary.*

```julia
@query mean(data.salary)
#=>
...
=#
```

*Show all employees with annual salary higher than 100000.*

```julia
@query data.filter(salary>100000)
#=>
...
=#
```

*Show the number of employees with annual salary higher than 100000.*

```julia
@query count(data.filter(salary>100000))
#=>
...
=#
```

*Show the top ten employees ordered by salary.*

```julia
@query data.sort(salary.desc()).select(name, salary).take(10)
#=>
...
=#
```

A long query could be split into several lines.

```julia
@query begin
    data
    sort(salary.desc())
    select(name, salary)
    take(10)
end
#=>
...
=#
```

DataKnots.jl implements an algebra of *query combinators*.  In this algebra,
its elements are *queries*, which represents relationships among classes and
data types.  This algebra's operations are *combinators*, which are applied
to construct query expressions.

