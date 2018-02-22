#
# Operations on index vectors.
#

"""
    dereference()

Dereferences an index vector.
"""
dereference() =
    Query(dereference) do env, input
        input isa SomeIndexVector || error("expected an index vector; got $input")
        dereference(input, env.refs)
    end

