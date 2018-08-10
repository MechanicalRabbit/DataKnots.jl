#
# Operations on index vectors.
#

"""
    dereference()

Dereferences an index vector.
"""
dereference() = Query(dereference)

function dereference(rt::Runtime, input::AbstractVector)
    @ensure_fits input ClassShape(:*)
    dereference(input, rt.refs)
end


"""
    store(name)

Converts the input vector to an index.
"""
store(name::Symbol) = Query(store, name)

function store(rt::Runtime, input::AbstractVector, name::Symbol)
    merge!(rt.refs, [Pair{Symbol,AbstractVector}(name, input)])
    IndexVector(name, OneTo{Int}(length(input)))
end

