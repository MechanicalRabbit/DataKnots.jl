# Optimal Layouts

To represent complex structures on a fixed width screen, we can use a source
code layout engine.

    using DataKnots.Layouts

For example, let us represent a simple tree structure.

    struct Node
        name::Symbol
        arms::Vector{Node}
    end

    Node(name) = Node(name, [])

    tree =
        Node(:a, [Node(:an, [Node(:anchor, [Node(:anchorage), Node(:anchorite)]),
                               Node(:anchovy),
                               Node(:antic, [Node(:anticipation)])]),
                   Node(:arc, [Node(:arch, [Node(:archduke), Node(:archer)])]),
                   Node(:awl)])
    #-> Node(:a, Main.layouts.md.Node[ … ])

We override the function `Layouts.tile()` and use `Layouts.literal()` with
combinators `*` (horizontal composition), `/` (vertical composition), and `|`
(choice) to generate the layout expression.

    function Layouts.tile(tree::Node)
        if isempty(tree.arms)
            return Layouts.literal("Node($(repr(tree.name)))")
        end
        arm_lts = [Layouts.tile(arm) for arm in tree.arms]
        v_lt = h_lt = nothing
        for (k, arm_lt) in enumerate(arm_lts)
            if k == 1
                v_lt = arm_lt
                h_lt = Layouts.nobreaks(arm_lt)
            else
                v_lt = v_lt * Layouts.literal(",") / arm_lt
                h_lt = h_lt * Layouts.literal(", ") * Layouts.nobreaks(arm_lt)
            end
        end
        return Layouts.literal("Node($(repr(tree.name)), [") *
               (v_lt | h_lt) *
               Layouts.literal("])")
    end

Now we can use function `pretty_print()` to render a nicely formatted
representation of the tree.

    pretty_print(stdout, tree)
    #=>
    Node(:a, [Node(:an, [Node(:anchor, [Node(:anchorage), Node(:anchorite)]),
                         Node(:anchovy),
                         Node(:antic, [Node(:anticipation)])]),
              Node(:arc, [Node(:arch, [Node(:archduke), Node(:archer)])]),
              Node(:awl)])
    =#

We can control the width of the output.

    pretty_print(IOContext(stdout, :displaysize => (24, 60)), tree)
    #=>
    Node(:a, [Node(:an, [Node(:anchor, [Node(:anchorage),
                                        Node(:anchorite)]),
                         Node(:anchovy),
                         Node(:antic, [Node(:anticipation)])]),
              Node(:arc, [Node(:arch, [Node(:archduke),
                                       Node(:archer)])]),
              Node(:awl)])
    =#

We can easily display the original and the optimized layouts.

    Layouts.tile(tree)
    #=>
    literal("Node(:a, [")
    * (literal("Node(:an, [")
       * (literal("Node(:anchor, [")
       ⋮
    =#

    Layouts.best(Layouts.fit(stdout, Layouts.tile(tree)))
    #=>
    literal("Node(:a, [")
    * (literal("Node(:an, [")
       * (literal("Node(:anchor, [Node(:anchorage), Node(:anchorite)]),")
       ⋮
    =#

For some built-in data structures, automatic layout is already provided.

    data = [
        (name = "RICHARD A", position = "FIREFIGHTER", salary = 90018),
        (name = "DEBORAH A", position = "POLICE OFFICER", salary = 86520),
        (name = "KATHERINE A", position = "PERSONAL COMPUTER OPERATOR II", salary = 60780)
    ]

    pretty_print(data)
    #=>
    [(name = "RICHARD A", position = "FIREFIGHTER", salary = 90018),
     (name = "DEBORAH A", position = "POLICE OFFICER", salary = 86520),
     (name = "KATHERINE A",
      position = "PERSONAL COMPUTER OPERATOR II",
      salary = 60780)]
    =#

Finally, we can format and print Julia expressions.

    Q = :(
        Employee
        >> ThenFilter(Department >> Name .== "POLICE")
        >> ThenSort(Salary >> Desc)
        >> ThenSelect(Name, Position, Salary)
        >> ThenTake(10)
    )

    print_code(Q)
    #=>
    Employee
    >> ThenFilter(Department >> Name .== "POLICE")
    >> ThenSort(Salary >> Desc)
    >> ThenSelect(Name, Position, Salary)
    >> ThenTake(10)
    =#

