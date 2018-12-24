# # Tutorial: Simulated Data
#
# In this tutorial we simulate a random patient population
# from a health clinic dealing with hypertension and type 2
# diabetes. This tutorial assumes the reader has read
# "Thinking in Combinators".
#
# Let's start with some preliminary imports.

using JSON, UUIDs, Plots, Dates
using DataKnots
using Distributions
using Random: seed!, rand

seed!(42); # hide

# ## Lifting Random Generators
#
# For this simulation, we would like a random number of
# patients. To get a random integer from the base library,
# use the `rand` function with a `range` input, `rand(3:5)`.
# To perform a similar function in DataKnots, we follow three
# steps. First, lift the `rand` function into a *combinator*,
# `Rand`. Second, this combinator can be invoked to produce
# a *pipeline*, `R3to5`. Third, the pipeline is `run` to
# produce a dataknot having the random value.

Rand(r::AbstractVector) = Combinator(it -> rand(r))(It)
R3to5 = Rand(3:5)
run(R3to5)

# In this definition, the `Rand` combinator creates pipelines
# that ignore their implicit input, `It`. There are more
# interesting combinators that take their pipeline input into
# consideration. For simple cases, this indirection is
# burdensome, however, we bring the idea of being random into
# our combinator algebra where it can be combined with other
# concepts. For example, we could now produce output with a
# random number of entries (similar to `1:rand(3:5)`).

run(Range(Rand(3:5)))

# For each of our simulated patients, we need to assign
# them a biological sex.

@enum Sex male=1 female=2
rand_sex() = Sex(rand(Categorical([.492, .508])))
Rand(::Type{Sex}) = :sex => Combinator(rand_sex)()

run(Range(Rand(3:5)) >> Rand(Sex))
