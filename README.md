# DataKnots.jl

*DataKnots is a Julia library for querying data with
an extensible, practical and coherent algebra of query
combinators.*

At this time, while we welcome feedback and contributions,
DataKnots is not yet usable for general audiences.

[![Linux/OSX Build Status][travis-img]][travis-url]
[![Windows Build Status][appveyor-img]][appveyor-url]
[![Code Coverage Status][codecov-img]][codecov-url]
[![Open Issues][issues-img]][issues-url]
[![Documentation][doc-dev-img]][doc-dev-url]
[![MIT License][license-img]][license-url]

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

## Support

Our development chat is currently hosted on Gitter:
https://gitter.im/rbt-lang/rbt-proto

Current documentation could be found at:
https://rbt-lang.github.io/DataKnots.jl/dev/

[travis-img]: https://travis-ci.org/rbt-lang/DataKnots.jl.svg?branch=master
[travis-url]: https://travis-ci.org/rbt-lang/DataKnots.jl
[appveyor-img]: https://ci.appveyor.com/api/projects/status/github/rbt-lang/DataKnots.jl?branch=master&svg=true
[appveyor-url]: https://ci.appveyor.com/project/rbt-lang/dataknots-jl/branch/master
[codecov-img]: https://codecov.io/gh/rbt-lang/DataKnots.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/rbt-lang/DataKnots.jl
[issues-img]: https://img.shields.io/github/issues/rbt-lang/DataKnots.jl.svg
[issues-url]: https://github.com/rbt-lang/DataKnots.jl/issues
[doc-dev-img]: https://img.shields.io/badge/doc-dev-blue.svg
[doc-dev-url]: https://rbt-lang.github.io/DataKnots.jl/dev/
[license-img]: https://img.shields.io/badge/license-MIT%2FApache%202-blue.svg
[license-url]: https://raw.githubusercontent.com/rbt-lang/DataKnots.jl/master/LICENSE.md
[Query Combinators]: https://arxiv.org/abs/1702.08409
