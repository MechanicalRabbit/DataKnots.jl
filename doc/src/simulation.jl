# # Example: Simulated Data
#
# DataKnots can be used to create simulated data sets, using
# simple range iteration and random number generation.
#

using DataKnots

# Let us plot something; we'll change this soon.

using Plots
x = range(0, stop=6pi, length=1000)
plot(x, [sin.(x), cos.(x)])
