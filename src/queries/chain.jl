#
# Identity and composition.
#

"""
    pass()

Identity map.
"""
pass() = Query(pass)

pass(env::QueryEnvironment, input::AbstractVector) =
    input


"""
    chain_of(q₁, q₂ … qₙ)

Sequentially applies q₁, q₂ … qₙ.
"""
chain_of() = pass()

chain_of(q) = q

chain_of(qs...) =
    Query(chain_of, collect(qs))

chain_of(qs::Vector) =
    Query(chain_of, qs)

function chain_of(env::QueryEnvironment, input::AbstractVector, qs)
    output = input
    for q in qs
        output = q(env, output)
    end
    output
end

