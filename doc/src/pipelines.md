# Query Algebra

    using DataKnots

    db = DataKnot(3)

    F = (It .+ 4) >> (It .* 6)
    #-> (It .+ 4) >> It .* 6

    run(db >> F)
    #=>
    │ DataKnot │
    ├──────────┤
    │       42 │
    =#

    using DataKnots: prepare

    prepare(DataKnot(3) >> F)
    #=>
    chain_of(lift_block([3], REG),
             in_block(chain_of(tuple_of([], [as_block(), lift_block([4], REG)]),
                               lift_to_block_tuple(+))),
             flat_block(),
             in_block(chain_of(tuple_of([], [as_block(), lift_block([6], REG)]),
                               lift_to_block_tuple(*))),
             flat_block())
    =#

    using DataKnots: @VectorTree

    db = DataKnot(
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

    run(db >> Field(:name))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

    run(db >> It.name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

    run(db >> Field(:employee) >> Field(:salary))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    4 │ 202728 │
    5 │ 197736 │
    =#

    run(db >> It.employee.salary)
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    4 │ 202728 │
    5 │ 197736 │
    =#

    run(db >> Count(It.employee))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        3 │
    2 │        2 │
    =#

    run(db >> Count)
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

    run(db >> Count(It.employee) >> Max)
    #=>
    │ DataKnot │
    ├──────────┤
    │        3 │
    =#

    run(db >> It.employee >> Filter(It.salary .> 200000))
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    run(db >> Count(It.employee) .> 2)
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │     true │
    2 │    false │
    =#

    run(db >> Filter(Count(It.employee) .> 2))
    #=>
      │ DataKnot                                                   │
      │ name    employee                                           │
    ──┼────────────────────────────────────────────────────────────┤
    1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │
    =#

    run(db >> Filter(Count(It.employee) .> 2) >> Count)
    #=>
    │ DataKnot │
    ├──────────┤
    │        1 │
    =#

    run(db >> Record(It.name, :size => Count(It.employee)))
    #=>
      │ DataKnot     │
      │ name    size │
    ──┼──────────────┤
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

    run(db >> It.employee >> Filter(It.salary .> It.S),
          S=200000)
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    run(
        db >> Given(:S => Max(It.employee.salary),
                    It.employee >> Filter(It.salary .== It.S)))
    #=>
      │ employee        │
      │ name     salary │
    ──┼─────────────────┤
    1 │ GARRY M  260004 │
    2 │ JOSE S   202728 │
    =#

    run(db >> It.employee.salary >> Take(3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    3 │ 170112 │
    =#

    run(db >> It.employee.salary >> Drop(3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 202728 │
    2 │ 197736 │
    =#

    run(db >> It.employee.salary >> Take(-3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    =#

    run(db >> It.employee.salary >> Drop(-3))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 170112 │
    2 │ 202728 │
    3 │ 197736 │
    =#

    run(db >> It.employee.salary >> Take(Count(db >> It.employee) .÷ 2))
    #=>
      │ salary │
    ──┼────────┤
    1 │ 260004 │
    2 │ 185364 │
    =#

