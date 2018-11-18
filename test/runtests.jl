#!/usr/bin/env julia

using Pkg
haskey(Pkg.installed(), "NarrativeTest") || Pkg.add("NarrativeTest")

# Make `print(Int)` produce identical output on 32-bit and 64-bit platforms.
Base.show_datatype(io::IO, ::Type{Int}) = print(io, "Int")

using DataKnots
using NarrativeTest
runtests()
