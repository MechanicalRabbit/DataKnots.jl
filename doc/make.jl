#!/usr/bin/env julia

if Pkg.installed("Documenter") == nothing
    Pkg.add("Documenter")
end

using Documenter
using QueryCombinators

# Highlight indented code blocks as Julia code.
Base.Markdown.Code(code) = Base.Markdown.Code("julia", code)

makedocs(
    format = :html,
    sitename = "QueryCombinators.jl",
    pages = [
        "index.md",
        "reference.md",
        "test/index.md",
    ],
    modules = [QueryCombinators])

deploydocs(
    repo = "github.com/rbt-lang/QueryCombinators.jl.git",
    julia = "0.6",
    osname = "linux",
    target = "build",
    deps = nothing,
    make = nothing)
