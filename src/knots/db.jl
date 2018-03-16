#
# Current database.
#

let DB_STK = DataKnot[convert(DataKnot, nothing)]

    global thedb, usedb!, unusedb!

    thedb() = DB_STK[end]

    function usedb!(db)
        db = convert(DataKnot, db)
        push!(DB_STK, db)
        db
    end

    function unusedb!()
        db = pop!(DB_STK)
        @assert !isempty(DB_STK)
        db
    end
end

function usedb(fn, db)
    usedb!(db)
    try
        return fn()
    finally
        unusedb!()
    end
end

