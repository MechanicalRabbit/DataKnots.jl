# Lifting Scalar Functions to Combinators

    using DataKnots

    using DataKnots:
        @VectorTree

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

    run(db >> It.employee.name)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ GARRY M   │
    2 │ ANTHONY R │
    3 │ DANA A    │
    4 │ JOSE S    │
    5 │ CHARLES S │
    =#

    TitleCase = Lift(titlecase, (It,))

    run(db >> It.employee.name >> TitleCase)
    #=>
      │ DataKnot  │
    ──┼───────────┤
    1 │ Garry M   │
    2 │ Anthony R │
    3 │ Dana A    │
    4 │ Jose S    │
    5 │ Charles S │
    =#

    Split = Lift(split, (It,))

    run(db >> It.employee.name >> Split)
    #=>
       │ DataKnot │
    ───┼──────────┤
     1 │ GARRY    │
     2 │ M        │
     3 │ ANTHONY  │
     4 │ R        │
     5 │ DANA     │
     6 │ A        │
     7 │ JOSE     │
     8 │ S        │
     9 │ CHARLES  │
    10 │ S        │
    =#

    run(db >> (
        :employee =>
          It.employee >>
            Record(:name =>
              It.name >> Split)))
    #=>
      │ employee   │
      │ name       │
    ──┼────────────┤
    1 │ GARRY; M   │
    2 │ ANTHONY; R │
    3 │ DANA; A    │
    4 │ JOSE; S    │
    5 │ CHARLES; S │
    =#

    Repeat(V,N) = Lift(fill, (V, N))
    run(db >> Record(It.name, Repeat("Go!", 3)))
    #=>
      │ DataKnot              │
      │ name    #2            │
    ──┼───────────────────────┤
    1 │ POLICE  Go!; Go!; Go! │
    2 │ FIRE    Go!; Go!; Go! │
    =#

