# # Tutorial: Simulated Data
#
# In this tutorial we simulate a random patient population from a
# health clinic dealing with hypertension and type 2 diabetes. We
# assume the reader has read "Thinking in Combinators" and wishes to
# use `DataKnots` for this simulation.

using DataKnots

# ## Lifted Functions
#
# Before we start generating data, there are a few combinators that are
# specific to this application area we should define first. Let's start
# with `OneTo` that wraps Julia's `UnitRange`.

OneTo(N) = Lift(UnitRange, (1, N))
make(X) = run(OneTo(Rand(2:5)) >> X)
make(It)

# Known data is boring in a simulation. Instead we need pseudorandom
# data. To make that data repeatable, let's fix the `seed`. We can then
# lift the `rand` function to a DataKnot combinator and use it to pick
# a random number from 3 to 5.

using Random: seed!, rand
seed!(1)
Rand(r::AbstractVector) = Lift(rand, (r,))
run(Rand(3:5))

# Julia's `Distributions` has `Categorical` and `TruncatedNormal`
# to make sure they work with DataKnots, we need another lift.

using Distributions
Rand(d::Distribution) = Lift(rand, (d,))
run(Rand(Categorical([.492, .508])))

# Sometimes it's helpful to truncate a floating point value, as chosen
# from an age distribution, to an integer value.  Here we lift `Trunc`.

Trunc(X) = Int.(floor.(X))
run(Trunc(Rand(TruncatedNormal(60,20,18,104))))

# Translating a value, such as a sex code to an average height, is also
# important to this domain. Here we define a `switch` function and then
# lift it to a combinator.

switch(x) = error();
switch(x, p, qs...) = x == p.first ? p.second : switch(x, qs...)
Switch(X, QS...) = Lift(switch, (X, QS...))
run(Switch(1, 1=>177, 2=>163))

# ## Building a Patient Record
#
# Let's incrementally construct a set of patient records. Let's start
# with assigning a random 5-digit Medical Record Number ("MRN").

RandPatient =
   :patient => Record(:mrn => Rand(10000:99999))
make(RandPatient)

# To assign an age to patients, we use Julia's truncated normal
# distribution. Since we wish whole-numbered ages, we truncate to
# the nearest integer value.

RandPatient >>= Record(
  :age => Trunc(Rand(TruncatedNormal(60,20,18,104))))
make(RandPatient)

# Let's assign each patient a random Sex. Here we use a categorical
# distribution plus enumerated values for male/female.

@enum Sex male=1 female=2
RandPatient >>= Record(
  :sex => Lift(Sex, (Rand(Categorical([.492, .508])),)))
make(RandPatient)

# Next, let's define the patient's height based upon the U.S. average
# of 177cm for males and 163cm for females with distribution of 7cm.

RandPatient >>= Record(
  :height => Trunc(Switch(It.sex, male => 177, female => 163)
                   .+ Rand(TruncatedNormal(0,7,-40,40))))
make(RandPatient)

