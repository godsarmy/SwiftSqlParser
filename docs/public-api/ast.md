---
type: API Reference
title: SQL AST
description: The public AST is a protocol-based, additive model for SQL statements, expressions, select items, and from items.
tags: [api, ast, sql]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: architecture
    resource: ../ARCHITECTURE.md
    title: Architecture guide
  - id: ast
    resource: ../../Sources/SwiftSqlParser/AST/SqlAst.swift
    title: SQL AST model
---

# SQL AST

The core public protocols are `Statement`, `Expression`, `SelectItem`, and `FromItem`. Concrete values are `Sendable`; many also provide intentionally scoped `Equatable` behavior.

Statement coverage includes plain, values, CTE, and set-operation queries; DML; table/index/view/policy DDL and alterations; utility statements; raw input; and `UnsupportedStatement`. Expression, join, select-item, and from-item models carry the structured parts consumed by visitors and deparsers.

AST evolution is additive-first. Build nodes directly when needed, then serialize them through [Deparsing](deparsing.md), or traverse them with [Visitors and Tools](visitors-and-tools.md).

`SetOperationSelect` carries combined-query `orderBy`, `limit`, and `offset`
fields, plus `limitExpression` and `offsetExpression` for constructed ASTs.
Existing initializers remain usable because the added parameters have defaults.
The parser assigns unparenthesized trailing clauses to this node; clauses inside
parenthesized operands stay on those operands. Nested set operands are rendered
with parentheses to preserve AST grouping.
