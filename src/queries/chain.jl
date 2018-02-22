#
# Identity and composition.
#

"""
    pass()

Identity map.
"""
pass() =
    Query(pass) do env, input
        input
    end


"""
    chain_of(q₁, q₂ … qₙ)

Sequentially applied q₁, q₂ … qₙ.
"""
chain_of(qs...) =
    Query(chain_of, qs...) do env, input
        _chain_of(env, input, qs...)
    end

_chain_of(env, input) = input
_chain_of(env, input, q1, more...) =
    _chain_of(env, q1(env, input), more...)

