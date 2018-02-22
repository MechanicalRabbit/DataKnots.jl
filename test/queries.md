# Query Algebra

The `Queries` module provides a simple combinator algebra of vector functions.

    using QueryCombinators.Planar
    using QueryCombinators.Queries


## Lifting scalar functions

Any scalar function could be lifted to a vector function by applying it to each
element of the input vector.

    q = lift(titlecase)
    #-> lift(titlecase)

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> ["Garry M", "Anthony R", "Dana A"]

We could also lift a scalar function of several arguments and then apply it to
a tuple vector.

    q = lift_to_tuple(>)
    #-> lift_to_tuple(>)

    q(@Planar (Int, Int) [260004 200000; 185364 200000; 170112 200000])
    #-> Bool[true, false, false]


## Tuple functions

To create tuple vectors, we use the combinator `tuple_of()`. Its parameters
are used to generate the columns of the tuple.

    q = tuple_of(:title => lift(titlecase), :last => lift(last))
    #-> tuple_of([:title, :last], lift(titlecase), lift(last))

    q(["GARRY M", "ANTHONY R", "DANA A"]) |> display
    #=>
    TupleVector of 3 × (title = String, last = Char):
     (title = "Garry M", last = 'M')
     (title = "Anthony R", last = 'R')
     (title = "Dana A", last = 'A')
    =#

In the opposite direction, `column()` extracts a column of a tuple vector.

    q = column(1)
    #-> column(1)

    q(@Planar (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112])
    #-> ["GARRY M", "ANTHONY R", "DANA A"]

We can also identify the column by name.

    q = column(:salary)
    #-> column(:salary)

    q(@Planar (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112])
    #-> [260004, 185364, 170112]

Finally, we can apply an arbitrary transformation to a single column of a tuple vector.

    q = in_tuple(:name, lift(titlecase))
    #-> in_tuple(:name, lift(titlecase))

    q(@Planar (name = String, salary = Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]) |> display
    #=>
    TupleVector of 3 × (name = String, salary = Int):
     (name = "Garry M", salary = 260004)
     (name = "Anthony R", salary = 185364)
     (name = "Dana A", salary = 170112)
    =#


## Block functions

Primitive `as_block()` wraps the elements of the input vector to one-element blocks.

    q = as_block()
    #-> as_block()

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> @Planar [String] ["GARRY M", "ANTHONY R", "DANA A"]

In the opposite direction, primitive `flat_block()` flattens a block vector whose elements
are also blocks.

    q = flat_block()
    #-> flat_block()

    q(@Planar [[String]] [[["GARRY M"], ["ANTHONY R", "DANA A"]], [missing, ["JOSE S"], ["CHARLES S"]]])
    #-> @Planar [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]]

Finally, we can apply an arbitrary transformation to every element of a block vector.

    q = in_block(lift(titlecase))
    #-> in_block(lift(titlecase))

    q(@Planar [String] [["GARRY M", "ANTHONY R", "DANA A"], ["JOSE S", "CHARLES S"]])
    #-> @Planar [String] [["Garry M", "Anthony R", "Dana A"], ["Jose S", "Charles S"]]


## Index functions

Any index vector could be dereferenced using the `dereference()` primitive.

    q = dereference()
    #-> dereference()

    q(@Planar &DEPT [1, 1, 1, 2] where {DEPT = ["POLICE", "FIRE"]})
    #-> ["POLICE", "POLICE", "POLICE", "FIRE"]


## Composition

We can compose a sequence of transformations using `chain_of()` combinator.

    q = chain_of(
            column(:employee),
            in_block(lift(titlecase)))
    #-> chain_of(column(:employee), in_block(lift(titlecase)))

    q(@Planar (department = String, employee = [String]) [
        "POLICE"    ["GARRY M", "ANTHONY R", "DANA A"]
        "FIRE"      ["JOSE S", "CHARLES S"]])
    #-> @Planar [String] [["Garry M", "Anthony R", "Dana A"], ["Jose S", "Charles S"]]

The empty chain `chain_of()` has an alias `pass()`

    q = pass()
    #-> pass()

    q(["GARRY M", "ANTHONY R", "DANA A"])
    #-> ["GARRY M", "ANTHONY R", "DANA A"]

