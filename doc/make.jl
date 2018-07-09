#!/usr/bin/env julia

try
    using Documenter
catch
    using Pkg
    Pkg.add("Documenter")
end

using Documenter
using DataKnots

# Highlight indented code blocks as Julia code.
using Markdown
Markdown.Code(code) = Markdown.Code("julia", code)

makedocs(
    format = :html,
    sitename = "DataKnots.jl",
    pages = [
        "Home" => "index.md",
        "install.md",
        "usage.md",
        hide("implementation.md",
             ["layouts.md", "vectors.md", "shapes.md", "queries.md", "combinators.md", "lifting.md"]),
    ],
    modules = [DataKnots])

deploydocs(
    repo = "github.com/rbt-lang/DataKnots.jl.git",
    julia = "nightly",
    osname = "linux",
    target = "build",
    deps = nothing,
    make = nothing)
