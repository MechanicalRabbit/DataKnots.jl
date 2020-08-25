# # Patient Data Simulation
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
unitknot[OneTo(3)]

# Known data is boring in a simulation. Instead we need pseudorandom
# data. To make that data repeatable, let's fix the `seed`. We can
# then lift the `rand` function to a DataKnot combinator and use it to
# pick a random number from 3 to 5.

using Random: seed!, rand
seed!(1)
Rand(r::AbstractVector) = Lift(rand, (r,))
unitknot[Rand(3:5)]

# Combining `OneTo` and `Rand` we could make an easy way to build
# several rows of a given value.

Several = OneTo(Rand(2:5))
unitknot[Several >> "Hello World"]

# Julia's `Distributions` has `Categorical` and `TruncatedNormal`
# to make sure they work with DataKnots, we need another lift.

using Distributions
Rand(d::Distribution) = Lift(rand, (d,))
unitknot[Rand(Categorical([.492, .508]))]

# Sometimes it's helpful to truncate a floating point value, as chosen
# from an age distribution, to an integer value.  Here we lift `Trunc`.

Trunc(X) = Int.(floor.(X))
unitknot[Trunc(Rand(TruncatedNormal(60,20,18,104)))]

# Translating a value, such as an index to a reference height, is also
# common. Here we define a `switch` function and then lift it.

switch(x) = error();
switch(x, p, qs...) = x == p.first ? p.second : switch(x, qs...)
Switch(X, QS...) = Lift(switch, (X, QS...))
unitknot[Switch(1, 1=>177, 2=>163)]

# ## Building a Patient Record
#
# Let's incrementally construct a set of patient records. Let's start
# with assigning a random 5-digit Medical Record Number ("MRN").

RandPatient = Record(:mrn => Rand(10000:99999))
unitknot[:patient => Several >> RandPatient]

# To assign an age to patients, we use Julia's truncated normal
# distribution. Since we wish whole-numbered ages, we truncate to the
# nearest integer value.

RandPatient >>= Record(It.mrn,
  :age => Trunc(Rand(TruncatedNormal(60,20,18,104))))
unitknot[:patient => Several >> RandPatient]

# Let's assign each patient a random Sex. Here we use a categorical
# distribution plus enumerated values for male/female.

@enum Sex male=1 female=2
RandPatient >>= Record(It.mrn, It.age,
  :sex => Lift(Sex, (Rand(Categorical([.492, .508])),)))
unitknot[:patient => Several >> RandPatient]

# Next, let's define the patient's height based upon the U.S. average
# of 177cm for males and 163cm for females with distribution of 7cm.

RandPatient >>= Record(It.mrn, It.age, It.sex,
  :height => Trunc(Switch(It.sex, male => 177, female => 163)
                   .+ Rand(TruncatedNormal(0,7,-40,40))))
unitknot[:patient => Several >> RandPatient]

# ## Implemention Comparison
#
# How could this patient sample be implemented directly in Julia?

@enum Sex male=1 female=2
function rand_patient()
   sex = Sex(rand(Categorical([.492,.508])))
   return (
      mrn = rand(10000:99999), sex = sex, 
      age = trunc(Int, rand(TruncatedNormal(60,20,18,104))),
      height = trunc(Int, (sex == male ? 177 : 163)
                          + rand(TruncatedNormal(0,7,-40,40))))
end
[rand_patient() for i in 1:rand(2:5)]

# Omitting the boilerplate *lifting* of `Rand`, `Trunc`, and `Switch`,
# the combinator variant can also be constructed succinctly.

@enum Sex male=1 female=2
RandPatient = Given(
  :sex => Lift(Sex, (Rand(Categorical([.492, .508])),)),
  Record(
    :mrn => Rand(10000:99999), It.sex,
    :age => Trunc(Rand(TruncatedNormal(60,20,18,104))),
    :height => Trunc(Switch(It.sex, male => 177, female => 163)
                     .+ Rand(TruncatedNormal(0,7,-40,40)))))
unitknot[:patient => OneTo(Rand(2:5)) >> RandPatient]

# That said, as complexity builds, the more incremental approach as 
# shown in the previous section may prove to be more desireable.

