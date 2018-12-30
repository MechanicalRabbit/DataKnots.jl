# # Tutorial: Simulated Data
#
# In this tutorial we simulate a random patient population from a
# health clinic dealing with hypertension and type 2 diabetes. We
# assume the reader has read "Thinking in Combinators" and wishes to
# use `DataKnots` for this simulation.

using DataKnots

# ## Getting Started
#
# For this simulation, we don't have a data source. To create rows for
# a data set, we define the `OneTo` combinator that wraps Julia's
# `UnitRange`. Let's then create a list of 3 `patient` rows.

OneTo(N) = Lift(UnitRange, (1, N))
run(:patient => OneTo(3))

# Known data is boring in a simulation. Instead we need pseudorandom
# data. To make that data repeatable, let's fix the `seed`. We can then
# lift the `rand` function to a DataKnot combinator and use it to pick
# a random number from 3 to 5.

using Random: seed!, rand
seed!(1)
Rand(r::AbstractVector) = Lift(rand, (r,))
run(Rand(3:5))

# Suppose each patient is assigned a random 5-digit Medical Record
# Number ("MRN"). Let's define and test this concept.

RandMRN =
  :mrn => Rand(10000:99999)
run(RandMRN)

# To assign a sex to each patient, we will use categorical
# distributions. Let's define a random male/female sex distribution.

using Distributions
SexDist = Categorical([.492, .508])
Rand(d::Distribution) = Lift(rand, (d,))
run(Rand(SexDist))

# While this picks `1` or `2` for us, remembering which is male and
# which is female can be a challenge.  Julia has an enumerated type for
# this purpose and we can lift this as well.

@enum Sex male=1 female=2
RandSex =
  :sex => Lift(Sex, (Rand(SexDist),))
run(RandSex)

# Patients should also be assigned an age. Given that our simulated
# patients are adults, with average age of 60, we could use Julia's
# tuncated normal distribution. Since we want whole-numbered ages,
# we further truncate this result to an integer value.

AgeDist = TruncatedNormal(60,20,18,104)
RandAge =
  :age => Integer.(trunc.(Rand(AgeDist)))

# With these primitives, we could start building our sample data set.
# Notice how `RandMRN` and `RandSex` are independently designed/tested
# and then arranged subsequently to build a set of random patients.

RandPatient =
  :patient => Record(RandMRN, RandSex, RandAge)
run(OneTo(Rand(3:5)) >> RandPatient)

#
# ## Context & Covariance
#
# For some synthetic attributes, such as `height`, depend upon others,
# such as `sex`. This can be modeled using parameters.
#

