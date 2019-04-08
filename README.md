# DataKnots.jl

*DataKnots is a Julia library for querying data with
an extensible, practical and coherent algebra of query
combinators.*

**Documentation** | **Build Status** | **Process**
:---: | :---: | :---:
[![Stable Documentation][doc-rel-img]][doc-rel-url] [![Development Documentation][doc-dev-img]][doc-dev-url] | [![Linux/OSX Build Status][travis-img]][travis-url] [![Windows Build Status][appveyor-img]][appveyor-url] [![Code Coverage Status][codecov-img]][codecov-url] | [![Chat on Gitter][gitter-img]][gitter-url] [![Open Issues][issues-img]][issues-url] [![MIT License][license-img]][license-url]

DataKnots is designed to let data analysts and other
accidental programmers query and analyze complex
structured data.

DataKnots implements an algebraic query interface of
[Query Combinators]. This algebra’s elements, or queries,
represent relationships among class entities and data
types. This algebra’s operations, or combinators, are
applied to construct query expressions.

We seek to prove that this query algebra has
significant advantages over the state of the art:

* DataKnots is a practical alternative to SQL with
  a declarative syntax; this makes it suitable for
  use by domain experts.

* DataKnots' data model handles nested and recursive
  structures (unlike DataFrames or SQL); this makes
  it suitable for working with CSV, JSON, XML, and
  SQL databases.

* DataKnots has a formal semantic model based upon
  monadic composition; this makes it easy to reason
  about the structure and interpretation of queries.

* DataKnots is a combinator algebra (like XPath but
  unlike LINQ or SQL); this makes it easier to assemble
  queries dynamically.

* DataKnots is fully extensible with Julia; this makes
  it possible to specialize it into various domain
  specific query languages.

## Installation

To install `DataKnots`, run in the package shell
(enter with `]` from the Julia shell):

```juliarepl
pkg> add DataKnots
```

DataKnots.jl requires Julia 1.0 or higher.

If you want to modify the source code of DataKnots.jl,
you need to install it in development mode with:

```juliarepl
pkg> dev https://github.com/rbt-lang/DataKnots.jl
```

## Showcase

Let's take some Chicago public data and convert it into a *knot*.

    using DataKnots, CSV

    chicago_data = """
        name,department,position,salary,rate
        "JEFFERY A", "POLICE", "SERGEANT", 101442,
        "NANCY A", "POLICE", "POLICE OFFICER", 80016,
        "JAMES A", "FIRE", "FIRE ENGINEER-EMT", 103350,
        "DANIEL A", "FIRE", "FIRE FIGHTER-EMT", 95484,
        "BRENDA B", "OEMC", "TRAFFIC CONTROL AIDE", 64392,
        "LAKENYA A", "OEMC", "CROSSING GUARD", , 17.68
        "DORIS A", "OEMC", "CROSSING GUARD", , 19.38
        """
    file = CSV.File(IOBuffer(chicago_data), allowmissing=:auto)
    knot = DataKnot(:employee => file)

We could then query this data to return employees with salaries
greater than their department's average.

    using Statistics: mean

    knot[It.employee >>
         Group(It.department) >>
         Keep(:avg_salary => mean.(It.employee.salary)) >>
         It.employee >>
         Filter(It.salary .> It.avg_salary)]
     #=>
       │ employee                                               │
       │ name       department  position           salary  rate │
     ──┼────────────────────────────────────────────────────────┼
     1 │ JAMES A    FIRE        FIRE ENGINEER-EMT  103350       │
     2 │ JEFFERY A  POLICE      SERGEANT           101442       │
     =#

Note: this showcase only works in development branch; use
`Tables.jl` interface will be in v0.3.

## Support

At this time, while we welcome feedback and contributions,
DataKnots is not yet usable for general audiences.

Our development chat is currently hosted on Gitter:
https://gitter.im/rbt-lang/rbt-proto

Current documentation could be found at:
https://rbt-lang.github.io/DataKnots.jl/stable/

[travis-img]: https://travis-ci.org/rbt-lang/DataKnots.jl.svg?branch=master
[travis-url]: https://travis-ci.org/rbt-lang/DataKnots.jl
[appveyor-img]: https://ci.appveyor.com/api/projects/status/github/rbt-lang/DataKnots.jl?branch=master&svg=true
[appveyor-url]: https://ci.appveyor.com/project/rbt-lang/dataknots-jl/branch/master
[codecov-img]: https://codecov.io/gh/rbt-lang/DataKnots.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/rbt-lang/DataKnots.jl
[issues-img]: https://img.shields.io/github/issues/rbt-lang/DataKnots.jl.svg
[issues-url]: https://github.com/rbt-lang/DataKnots.jl/issues
[doc-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[doc-rel-img]: https://img.shields.io/badge/docs-stable-green.svg
[doc-dev-url]: https://rbt-lang.github.io/DataKnots.jl/dev/
[doc-rel-url]: https://rbt-lang.github.io/DataKnots.jl/stable/
[license-img]: https://img.shields.io/badge/license-MIT-brightgreen.svg
[license-url]: https://raw.githubusercontent.com/rbt-lang/DataKnots.jl/master/LICENSE.md
[gitter-img]: https://img.shields.io/gitter/room/rbt-lang/rbt-proto.svg?color=%23753a88
[gitter-url]: https://gitter.im/rbt-lang/rbt-proto/
[Query Combinators]: https://arxiv.org/abs/1702.08409
