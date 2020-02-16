#!/usr/bin/env julia

using Documenter
using DataKnots

# Setup for doctests embedded in docstrings.
DocMeta.setdocmeta!(DataKnots, :DocTestSetup, :(using DataKnots))

# Highlight indented code blocks as Julia code.
using Documenter.Expanders: ExpanderPipeline, Selectors, Markdown, iscode
abstract type DefaultLanguage <: ExpanderPipeline end
Selectors.order(::Type{DefaultLanguage}) = 99.0
Selectors.matcher(::Type{DefaultLanguage}, node, page, doc) =
    iscode(node, "")
Selectors.runner(::Type{DefaultLanguage}, node, page, doc) =
    page.mapping[node] = Markdown.Code("julia", node.code)

makedocs(
    sitename = "DataKnots.jl",
    format = Documenter.HTML(prettyurls=(get(ENV, "CI", nothing) == "true")),
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
