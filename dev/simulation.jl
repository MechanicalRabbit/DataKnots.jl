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

seed!(0); # hide

# ## Lifting Generators
#
# For this simulation, we would like a random number of
# patients. This can be done using the `Range` combinator.
# In this example, the argument, `rand(3:5)` is immediately
# evaluated, and converted into a constant `Pipeline`.

run(Range(rand(3:5)))

# If we want a different random number for each pipeline
# input, we need to lift the `rand` function to a combinator.

Rand(r::AbstractVector) = Combinator(() -> rand(r))()
run(Range(3) >> Rand(1:9))

# Suppose each patient is assigned a random 5-digit Medical
# Record Number ("MRN"). This concept could be defined and
# independently tested.

RandMRN() =
  :mrn => Rand(10000:99999)
run(RandMRN())

# For each of our simulated patients, we need to assign them
# a biological sex as well. In pure Julia, this could be done
# with a `Sex` and a `rand_sex` function.

@enum Sex male=1 female=2
rand_sex() = Sex(rand(Categorical([.492, .508])))
RandSex() =
  :sex => Combinator(rand_sex)()
run(RandSex())

# With these primitives, we could start building our sample
# data set. What's important already is that the definition
# of Patient can be seen to be independent of its components.

RandPatient() =
  :patient => Record(RandMRN(), RandSex())
run(Range(Rand(3:5)) >> RandPatient())

