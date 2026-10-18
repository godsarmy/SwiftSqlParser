---
type: API Reference
title: Visitors and Table Discovery
description: Visitor protocols and AstVisit dispatch support typed traversal, while TableNameFinder collects referenced table names.
tags: [api, visitors, analysis]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: usage
    resource: ../USAGE.md
    title: Usage guide
  - id: visitors
    resource: ../../Sources/SwiftSqlParser/Visitors/SqlVisitors.swift
    title: Visitor protocols and dispatch
  - id: finder
    resource: ../../Sources/SwiftSqlParser/Visitors/TableNameFinder.swift
    title: Table name finder
---

# Visitors and Table Discovery

Implement `StatementVisitor`, `ExpressionVisitor`, `FromItemVisitor`, or `SelectItemVisitor`; default no-op methods allow implementing only relevant cases. `AstVisit` dispatches a protocol-typed node to its matching concrete visitor method.

`TableNameFinder().find(in:)` accepts either a statement or expression and returns sorted unique table names. It follows nested queries, joins, DML, relevant DDL constraints, and expressions while suppressing CTE names and aliases where tracked.
