---
type: API Reference
title: Deparsing
description: StatementDeparser serializes supported AST statements to SQL using expression and select deparsers.
tags: [api, deparser, sql]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: usage
    resource: ../USAGE.md
    title: Usage guide
  - id: statement-deparser
    resource: ../../Sources/SwiftSqlParser/Deparser/StatementDeparser.swift
    title: Statement deparser
---

# Deparsing

Construct `StatementDeparser()` and call `deparse(_:)` with any `Statement`. It delegates expressions and select structures to companion deparsers and handles query, DML, DDL, utility, raw, and unsupported statement forms.

Deparsing is the public build-and-serialize workflow for [SQL AST](ast.md). Unsupported statement values preserve their original SQL; an unrecognized statement type yields the literal fallback `<unsupported-statement>`.
