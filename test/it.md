# `It`

The combinator `It` returns its input unchanged.

    using QueryCombinators

    It
    #-> It

    execute(It, "Chicago")
    #-> "Chicago"

`It` serves as a unit of composition.

    Lake = Data(["Erie", "Huron", "Michigan", "Ontario", "Superior"])
    execute(Lake)
    #-> ["Erie", "Huron", "Michigan", "Ontario", "Superior"]

    Q = Lake >> It
    execute(Q)
    #-> ["Erie", "Huron", "Michigan", "Ontario", "Superior"]

    Q = It >> Lake
    execute(Q)
    #-> ["Erie", "Huron", "Michigan", "Ontario", "Superior"]

