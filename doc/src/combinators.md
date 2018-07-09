# Query Algebra

    using DataKnots
    using DataKnots.Combinators

    F = (It .+ 4) >> (It .* 6)
    #-> (It .+ 4) >> It .* 6

    query(3, F)
    #=>
    │ DataKnot │
    ├──────────┤
    │       42 │
    =#

    prepare(DataKnot(3) >> F)
    #=>
    chain_of(lift_block([3]),
             in_block(chain_of(tuple_of([], [as_block(), lift_block([4])]),
                               lift_to_block_tuple(+))),
             flat_block(),
             in_block(chain_of(tuple_of([], [as_block(), lift_block([6])]),
                               lift_to_block_tuple(*))),
             flat_block())
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

    query(Field(:name))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

    query(It.name)
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

    query(Field(:employee) >> Field(:salary))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    4 │ 202728 │
    5 │ 197736 │
    =#

    query(It.employee.salary)
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

    query(Count(It.employee))
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

    query(Count)
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

    query(Count(It.employee) >> Max)
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

    query(It.employee >> Filter(It.salary .> 200000))
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

    query(Count(It.employee) .> 2)
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

    query(Filter(Count(It.employee) .> 2))
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

    query(Filter(Count(It.employee) .> 2) >> Count)
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

    query(Record(It.name, :size => Count(It.employee)))
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

    query(It.employee >> Filter(It.salary .> It.S),
          S=200000)
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    query(
        Given(:S => Max(It.employee.salary),
            It.employee >> Filter(It.salary .== It.S)))
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    @query begin
        employee
        filter(salary>S)
    end where { S = 200000 }
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    @query given(
            S => max(employee.salary),
            employee.filter(salary==S))
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    query(It.employee.salary >> Sort)
    #=>
      │ salary │
    ──┼────────┤
    1 │ 170112 │
    2 │ 185364 │
    3 │ 197736 │
    4 │ 202728 │
    5 │ 260004 │
    =#

    @query employee.salary.sort()
    #=>
      │ salary │
    ──┼────────┤
    1 │ 170112 │
    2 │ 185364 │
    3 │ 197736 │
    4 │ 202728 │
    5 │ 260004 │
    =#

    query(It.employee.salary >> Desc >> Sort)
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 202728 │
    3 │ 197736 │
    4 │ 185364 │
    5 │ 170112 │
    =#

    @query employee.salary.desc().sort()
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 202728 │
    3 │ 197736 │
    4 │ 185364 │
    5 │ 170112 │
    =#

    query(It.employee >> Sort(It.salary))
    #=>
      │ employee          │
      │ name       salary │
    ──┼───────────────────┤
    1 │ DANA A     170112 │
    2 │ ANTHONY R  185364 │
    3 │ CHARLES S  197736 │
    4 │ JOSE S     202728 │
    5 │ GARRY M    260004 │
    =#

    @query employee.sort(salary)
    #=>
      │ employee          │
      │ name       salary │
    ──┼───────────────────┤
    1 │ DANA A     170112 │
    2 │ ANTHONY R  185364 │
    3 │ CHARLES S  197736 │
    4 │ JOSE S     202728 │
    5 │ GARRY M    260004 │
    =#

    query(It.employee >> Sort(It.salary >> Desc))
    #=>
      │ employee          │
      │ name       salary │
    ──┼───────────────────┤
    1 │ GARRY M    260004 │
    2 │ JOSE S     202728 │
    3 │ CHARLES S  197736 │
    4 │ ANTHONY R  185364 │
    5 │ DANA A     170112 │
    =#

    @query employee.sort(salary.desc())
    #=>
      │ employee          │
      │ name       salary │
    ──┼───────────────────┤
    1 │ GARRY M    260004 │
    2 │ JOSE S     202728 │
    3 │ CHARLES S  197736 │
    4 │ ANTHONY R  185364 │
    5 │ DANA A     170112 │
    =#

    query(It.employee.salary >> Take(3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    =#

    query(It.employee.salary >> Drop(3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 202728 │
    2 │ 197736 │
    =#

    query(It.employee.salary >> Take(-3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    =#

    query(It.employee.salary >> Drop(-3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 170112 │
    2 │ 202728 │
    3 │ 197736 │
    =#

    query(It.employee.salary >> Take(Count(thedb() >> It.employee) .÷ 2))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    =#

    query(It.employee >> Group(:grade => It.salary .÷ 100000))
    #=>
      │ DataKnot                                                    │
      │ grade  employee                                             │
    ──┼─────────────────────────────────────────────────────────────┤
    1 │     1  ANTHONY R, 185364; DANA A, 170112; CHARLES S, 197736 │
    2 │     2  GARRY M, 260004; JOSE S, 202728                      │
    =#

    @query employee.group(grade => salary ÷ 100000)
    #=>
      │ DataKnot                                                    │
      │ grade  employee                                             │
    ──┼─────────────────────────────────────────────────────────────┤
    1 │     1  ANTHONY R, 185364; DANA A, 170112; CHARLES S, 197736 │
    2 │     2  GARRY M, 260004; JOSE S, 202728                      │
    =#

    @query begin
        employee
        group(grade => salary ÷ 100000)
        record(
            grade,
            size => count(employee),
            low => min(employee.salary),
            high => max(employee.salary),
            avg => mean(employee.salary),
            employee.salary.sort())
    end
    #=>
      │ DataKnot                                                      │
      │ grade  size  low     high    avg       salary                 │
    ──┼───────────────────────────────────────────────────────────────┤
    1 │     1     3  170112  197736  184404.0  170112; 185364; 197736 │
    2 │     2     2  202728  260004  231366.0  202728; 260004         │
    =#

    usedb!(
        @VectorTree (department = [(name = [String],)],
                     employee = [(name = [String], department = [String], position = [String], salary = [Int])]) [
            (department = [
                "POLICE"
                "FIRE"
             ],
             employee = [
                "JAMES A"   "POLICE"    "SERGEANT"      110370
                "MICHAEL W" "POLICE"    "INVESTIGATOR"  63276
                "STEVEN S"  "FIRE"      "CAPTAIN"       123948
                "APRIL W"   "FIRE"      "PARAMEDIC"     54114
            ])
        ]
    )
    #=>
    │ DataKnot                                                                     …
    │ department    employee                                                       …
    ├──────────────────────────────────────────────────────────────────────────────…
    │ POLICE; FIRE  JAMES A, POLICE, SERGEANT, 110370; MICHAEL W, POLICE, INVESTIGA…
    =#

    @query begin
        record(
            department.graft(name, employee.index(department)),
            employee.graft(department, department.unique_index(name)))
    end
    #=>
    │ DataKnot                                                                     …
    │ department                                                                   …
    ├──────────────────────────────────────────────────────────────────────────────…
    │ POLICE, JAMES A, POLICE, SERGEANT, 110370; MICHAEL W, POLICE, INVESTIGATOR, 6…
    =#

    @query begin
        record(
            department.graft(name, employee.index(department)),
            employee.graft(department, department.unique_index(name)))
        employee.record(name, department_name => department.name)
    end
    #=>
      │ DataKnot                   │
      │ name       department_name │
    ──┼────────────────────────────┤
    1 │ JAMES A    POLICE          │
    2 │ MICHAEL W  POLICE          │
    3 │ STEVEN S   FIRE            │
    4 │ APRIL W    FIRE            │
    =#

    @query begin
        record(
            department.graft(name, employee.index(department)),
            employee.graft(department, department.unique_index(name)))
        department.record(name, size => count(employee), max_salary => max(employee.salary))
    end
    #=>
      │ DataKnot                 │
      │ name    size  max_salary │
    ──┼──────────────────────────┤
    1 │ POLICE     2      110370 │
    2 │ FIRE       2      123948 │
    =#

    @query begin
        weave(
            department.graft(name, employee.index(department)),
            employee.graft(department, department.unique_index(name)))
    end
    #=>
    │ DataKnot                       │
    │ department  employee           │
    ├────────────────────────────────┤
    │ [1]; [2]    [1]; [2]; [3]; [4] │
    =#

    @query begin
        weave(
            department.graft(name, employee.index(department)),
            employee.graft(department, department.unique_index(name)))
        employee.record(name, department_name => department.name)
    end
    #=>
      │ DataKnot                   │
      │ name       department_name │
    ──┼────────────────────────────┤
    1 │ JAMES A    POLICE          │
    2 │ MICHAEL W  POLICE          │
    3 │ STEVEN S   FIRE            │
    4 │ APRIL W    FIRE            │
    =#

    @query begin
        weave(
            department.graft(name, employee.index(department)),
            employee.graft(department, department.unique_index(name)))
        department.record(name, size => count(employee), max_salary => max(employee.salary))
    end
    #=>
      │ DataKnot                 │
      │ name    size  max_salary │
    ──┼──────────────────────────┤
    1 │ POLICE     2      110370 │
    2 │ FIRE       2      123948 │
    =#

    @query begin
        weave(
            department.graft(name, employee.index(department)),
            employee.graft(department, department.unique_index(name)))
        department
        employee
        department
        employee
        name
    end
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JAMES A   │
    2 │ MICHAEL W │
    3 │ JAMES A   │
    4 │ MICHAEL W │
    5 │ STEVEN S  │
    6 │ APRIL W   │
    7 │ STEVEN S  │
    8 │ APRIL W   │
    =#

    usedb!(
        @VectorTree (department = [&DEPT], employee = [&EMP]) [
            [1, 2]  [1, 2, 3, 4]
        ] where {
            DEPT = @VectorTree (name = [String], employee = [&EMP]) [
                "POLICE"    [1, 2]
                "FIRE"      [3, 4]
            ]
            ,
            EMP = @VectorTree (name = [String], department = [&DEPT], position = [String], salary = [Int]) [
                "JAMES A"   1   "SERGEANT"      110370
                "MICHAEL W" 1   "INVESTIGATOR"  63276
                "STEVEN S"  2   "CAPTAIN"       123948
                "APRIL W"   2   "PARAMEDIC"     54114
            ]
        }
    )
    #=>
    │ DataKnot                       │
    │ department  employee           │
    ├────────────────────────────────┤
    │ [1]; [2]    [1]; [2]; [3]; [4] │
    =#

    @query department.name
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

    @query department.employee.name
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JAMES A   │
    2 │ MICHAEL W │
    3 │ STEVEN S  │
    4 │ APRIL W   │
    =#

    @query employee.department.name
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ POLICE │
    3 │ FIRE   │
    4 │ FIRE   │
    =#

    @query employee.position
    #=>
      │ position     │
    ──┼──────────────┤
    1 │ SERGEANT     │
    2 │ INVESTIGATOR │
    3 │ CAPTAIN      │
    4 │ PARAMEDIC    │
    =#

    @query count(department)
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

    @query max(employee.salary)
    #=>
    │ salary │
    ├────────┤
    │ 123948 │
    =#

    @query department.count(employee)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        2 │
    =#

    @query max(department.count(employee))
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

    @query employee.filter(salary>100000).name
    #=>
      │ name     │
    ──┼──────────┤
    1 │ JAMES A  │
    2 │ STEVEN S │
    =#

    @query begin
        department
        filter(count(employee)>=2)
        count()
    end
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

    @query department.record(name, size => count(employee))
    #=>
      │ DataKnot     │
      │ name    size │
    ──┼──────────────┤
    1 │ POLICE     2 │
    2 │ FIRE       2 │
    =#

