#!/usr/bin/env julia

using Pkg
haskey(Pkg.installed(), "Documenter") || Pkg.add("Documenter")
haskey(Pkg.installed(), "CSV") || Pkg.add("CSV") # used in jldoctest

using Documenter
using DataKnots

# Setup for doctests embedded in docstrings.
DocMeta.setdocmeta!(DataKnots, :DocTestSetup, :(using DataKnots))

# Highlight indented code blocks as Julia code.
using Markdown
Markdown.Code(code) = Markdown.Code("julia", code)
Documenter.Utilities.Markdown2._convert_inline(s::Markdown.Code) =
    Documenter.Utilities.Markdown2.CodeSpan(s.code)

makedocs(
    sitename = "DataKnots.jl",
    format = Documenter.HTML(prettyurls=("CI" in keys(ENV))),
    pages = [
        "Home" => "index.md",
        "Queries for Data Analysts" => "overview.md",
        "Tutorials" => [
            "highlypaid.md"
        ],
        "Reference Manual" => [
            "primer.md",
            "tutorial.md",
            "reference.md",
        ],
        "Implementer's Guide" => [
            "vectors.md",
            "pipelines.md",
            "shapes.md",
            "knots.md",
            "queries.md",
        ],
    ],
    modules = [DataKnots])

deploydocs(
    repo = "github.com/rbt-lang/DataKnots.jl.git",
)
