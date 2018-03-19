# Query Algebra

    using DataKnots

    F = (it .+ 4) >> (it .* 6)
    #-> (it .+ 4) >> it .* 6

    query(3, F)
    #=>
    │ DataKnot │
    ├──────────┤
    │       42 │
    =#

    usedb!(
        @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [
            "POLICE"    ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
            "FIRE"      ["JOSE S" 202728; "CHARLES S" 197736]
        ])
    #=>
      │ DataKnot                                                   │
      │ name    employee                                           │
    ──┼────────────────────────────────────────────────────────────┤
    1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │
    2 │ FIRE    JOSE S, 202728; CHARLES S, 197736                  │
    =#

    query(field(:name))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

    query(it.name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

    @query name
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

    query(field(:employee) >> field(:salary))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    4 │ 202728 │
    5 │ 197736 │
    =#

    query(it.employee.salary)
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    4 │ 202728 │
    5 │ 197736 │
    =#

    @query employee.salary
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    4 │ 202728 │
    5 │ 197736 │
    =#

    query(count(it.employee))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        3 │
    2 │        2 │
    =#

    @query count(employee)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        3 │
    2 │        2 │
    =#

    query(count)
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

    @query count()
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

    query(count(it.employee) >> maximum)
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

    @query count(employee).max()
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

    query(it.employee >> filter(it.salary .> 200000))
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    @query employee.filter(salary>200000)
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    @query begin
        employee
        filter(salary>200000)
    end
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    query(count(it.employee) .> 2)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │     true │
    2 │    false │
    =#

    @query count(employee)>2
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │     true │
    2 │    false │
    =#

    query(filter(count(it.employee) .> 2))
    #=>
      │ DataKnot                                                   │
      │ name    employee                                           │
    ──┼────────────────────────────────────────────────────────────┤
    1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │
    =#

    @query filter(count(employee)>2)
    #=>
      │ DataKnot                                                   │
      │ name    employee                                           │
    ──┼────────────────────────────────────────────────────────────┤
    1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │
    =#

    query(filter(count(it.employee) .> 2) >> count)
    #=>
    │ DataKnot │
    ├──────────┤
    │        1 │
    =#

    @query begin
        filter(count(employee)>2)
        count()
    end
    #=>
    │ DataKnot │
    ├──────────┤
    │        1 │
    =#

    query(record(it.name, :size => count(it.employee)))
    #=>
      │ DataKnot     │
      │ name    size │
    ──┼──────────────┤
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

    @query record(name, size => count(employee))
    #=>
      │ DataKnot     │
      │ name    size │
    ──┼──────────────┤
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

