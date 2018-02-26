#
# Operations on index vectors.
#

"""
    dereference()

Dereferences an index vector.
"""
dereference() = Query(dereference)

function dereference(env::QueryEnvironment, input::AbstractVector)
    input isa SomeIndexVector || error("expected an index vector; got $input")
    dereference(input, env.refs)
end

