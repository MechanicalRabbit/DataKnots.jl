#!/usr/bin/env julia

using Pkg
haskey(Pkg.installed(), "NarrativeTest") || Pkg.clone("https://github.com/rbt-lang/NarrativeTest.jl")

# Make `print(Int)` produce identical output on 32-bit and 64-bit platforms.
Base.show_datatype(io::IO, ::Type{Int}) = print(io, "Int")
Base.show_datatype(io::IO, ::Type{UInt}) = print(io, "UInt")

using DataKnots
using NarrativeTest

args = !isempty(ARGS) ? ARGS : [relpath(joinpath(dirname(abspath(PROGRAM_FILE)), "../doc/src"))]
exit(!runtests(args))
