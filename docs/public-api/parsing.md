---
type: API Reference
title: Parsing APIs
description: SwiftSqlParser exposes throwing statement and batch parsing plus result-shaped and script-oriented APIs.
tags: [api, parsing, scripts]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: usage
    resource: ../USAGE.md
    title: Usage guide
  - id: parser-api
    resource: ../../Sources/SwiftSqlParser/Parser/SqlParserAPI.swift
    title: Top-level parser API
---

# Parsing APIs

Use `parseStatement` for one throwing parse and `parseStatements` for a delimiter-split batch. `SqlParser` also provides `parseStatementResult` and `parseStatementsResult` for result containers, while `parseScript` returns slot-preserving script results without throwing.

Top-level convenience functions accept `sql`, `ParserOptions`, and an optional `GrammarStrategy`; instance methods keep the strategy on `SqlParser`. Query, DML, DDL, and utility prefixes route to their matching parser; otherwise a nonempty input may be represented as `RawStatement`.

For recovery semantics and positions, see [Diagnostics](diagnostics.md) and [Options and Dialects](options-and-dialects.md).
