#!/usr/bin/env julia

using Pkg
haskey(Pkg.installed(), "NarrativeTest") || Pkg.clone("https://github.com/rbt-lang/NarrativeTest.jl")

using DataKnots
using NarrativeTest

# Make `print(Int)` produce identical output on 32-bit and 64-bit platforms.
Base.show_datatype(io::IO, ::Type{Int}) = print(io, "Int")
Base.show_datatype(io::IO, ::Type{UInt}) = print(io, "UInt")

# Normalize printing of `Vector{Bool}`.
Base.show(io::IO, b::Bool) = print(io, get(io, :typeinfo, Any) === Bool ? (b ? "1" : "0") : (b ? "true" : "false"))

# Normalize `LoadError` output and `[0 => 0]` under 1.2.
if VERSION >= v"1.2.0-DEV"
    function Base.showerror(io::IO, ex::LoadError, bt; backtrace=true)
        print(io, "LoadError: ")
        showerror(io, ex.error, bt, backtrace=backtrace)
        print(io, "\nin expression starting at $(ex.file):$(ex.line)")
    end
    function Base.show(io::IO, p::Pair)
        iocompact = IOContext(io, :compact => get(io, :compact, true))
        Base.isdelimited(io, p) && return Base.show_default(iocompact, p)
        typeinfos = Base.gettypeinfos(io, p)
        for i = (1, 2)
            io_i = IOContext(iocompact, :typeinfo => typeinfos[i])
            Base.isdelimited(io_i, p[i]) || print(io, "(")
            show(io_i, p[i])
            Base.isdelimited(io_i, p[i]) || print(io, ")")
            i == 1 && print(io, get(io, :compact, true) ? "=>" : " => ")
        end
    end
end

# Normalize printing of Enum values.
if VERSION < v"1.2.0-DEV"
    Base.show(io::IO, c::DataKnots.Cardinality) =
        print(io, Symbol(c))
end

args = !isempty(ARGS) ? ARGS : [relpath(joinpath(dirname(abspath(PROGRAM_FILE)), "../doc/src"))]
exit(!runtests(args))
