# # Tutorial: Simulated Data
#
# In this tutorial we simulate a random patient population from a
# health clinic dealing with hypertension and type 2 diabetes. We
# assume the reader has read "Thinking in Combinators" and wishes to
# use `DataKnots` for this simulation.

using DataKnots

# ## Basic Patient Record
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

# To assign an age to patients, we use Julia's truncated normal
# distribution. Since we wish whole-numbered ages, we truncate to
# the nearest integer value.

AgeDist = TruncatedNormal(60,20,18,104)
Trunc(X) = Int.(floor.(X))
RandAge =
  :age => Trunc((Rand(AgeDist)))

# With these primitives, we could start building our sample data set.
# Notice how `RandMRN` and `RandSex` are independently designed/tested
# and then arranged subsequently to build a set of random patients.

RandPatient =
  :patient => Record(RandMRN, RandSex, RandAge)
run(OneTo(Rand(2:5)) >> RandPatient)

#
# ## Parameters & Covariance
#
# Some synthetic attributes, such as `height`, depend upon others,
# such as `sex`. The average U.S. height is 177cm or 163cm based upon
# sex of the subject; the normal distribution is 7cm.
#
# The first thing we need to define is a way to decode male/female
# into this base height. This can be done by defining a recursive
# function `switch` and then lifting it into a combinator.
#

switch(x) = error();
switch(x, p, qs...) = x == p.first ? p.second : switch(x, qs...)
Switch(X, QS...) = Lift(switch, (X, QS...))
BaseHeight(X) = Switch(X, male => 177, female => 163)
run(BaseHeight(female))

# Then, we need to define this height based upon the patient's given
# `sex` and not a hard-coded value. This is done in two parts. The
# `Given` combinator assigns a parameter, and the `It` primitive can be
# used to obtain that parameter's value.

RandHeight =
  :height => Trunc(BaseHeight(It.sex)
                   .+ Rand(TruncatedNormal(0,7,-40,40)))
run(Given(:sex => female, RandHeight))

# This pattern is common enough that we can define Patient using
# the Given and then select it.

GivenPatient(X) =
  :patient => Given(RandMRN, RandSex, RandAge, RandHeight, X)

RandPatient =
   GivenPatient(Record(It.mrn, It.sex, It.age, It.height))
run(OneTo(Rand(2:5)) >> RandPatient)

#
# Nested Values
#

