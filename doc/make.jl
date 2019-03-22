#!/usr/bin/env julia

using Pkg
haskey(Pkg.installed(), "Documenter") || Pkg.add("Documenter")

using Documenter
using DataKnots

# Highlight indented code blocks as Julia code.
using Markdown
Markdown.Code(code) = Markdown.Code("julia", code)

makedocs(
    sitename = "DataKnots.jl",
    pages = [
        "Home" => "index.md",
        "tutorial.md",
        "reference.md",
        "primer.md",
        "vectors.md",
        "pipelines.md",
        "shapes.md",
        "knots.md",
        "queries.md",
    ],
    modules = [DataKnots])

deploydocs(
    repo = "github.com/rbt-lang/DataKnots.jl.git",
)
