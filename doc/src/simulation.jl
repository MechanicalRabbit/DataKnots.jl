# # Tutorial: Simulated Data
#
# In this tutorial we simulate a random patient population from a
# health clinic dealing with hypertension and type 2 diabetes. This
# tutorial assumes the reader has read "Thinking in Combinators" and
# wishes to use `DataKnots`.

using DataKnots

# ## Getting Started
#
# For this simulation, we don't have a data source. To create rows for
# a data set, we define the `OneTo` combinator that wraps Julia's
# `UnitRange`. Let's then create a list of 3 `patient` rows.

OneTo(N) = UnitRange.(1, Lift(N))
run(:patient => OneTo(3))

# Known data is boring in a simulation. What's interesting is
# pseudorandom data. To make that data repeatable, we need to fix the
# `seed`. We can then lift the `rand` function to a combinator that
# takes anything that's a vector.

using Random: seed!, rand
seed!(1)
Rand(r::AbstractVector) = Lift(rand, (r,));

# Suppose each patient is assigned a random 5-digit Medical Record
# Number ("MRN"). Let's define and test this concept.

RandMRN() =
  :mrn => Rand(10000:99999)
run(RandMRN())

# Sometimes it's useful to use categorical distributions. We can also
# use distributions within our `Rand` combinator. Let's suppose that
# 49.2% of patients are male and 50.8% are female. Hence, we could
# randomly choose 1 = Male, or 2 = Female as follows.

using Distributions
SexDist = Categorical([.492, .508])
Rand(d::Distribution) = Lift(rand, (d,))
run(Rand(SexDist))

# While this is nice, it makes it challenging to remember which is a
# male or a female. Julia has an enumerated type for this purpose and
# we can lift this as well.

@enum Sex male=1 female=2
RandSex() = 
  :sex => Lift(Sex, (Rand(SexDist),))
run(RandSex())

# With these primitives, we could start building our sample
# data set. What's important already is that the definition
# of Patient can be seen to be independent of its components.

RandPatient() =
  :patient => Record(RandMRN(), RandSex())
run(OneTo(Rand(3:5)) >> RandPatient())

