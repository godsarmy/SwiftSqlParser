---
type: Implementation Reference
title: Grammar Strategy Metadata
description: GrammarStrategy records ANTLR4-oriented backend and delivery-phase metadata alongside a small grammar artifact.
tags: [internals, grammar, antlr]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: architecture
    resource: ../ARCHITECTURE.md
    title: Architecture guide
  - id: strategy
    resource: ../../Sources/SwiftSqlParser/Parser/GrammarStrategy.swift
    title: Grammar strategy model
  - id: grammar
    resource: ../../Grammar/JSqlParserSubset.g4
    title: JSqlParser subset grammar
---

# Grammar Strategy Metadata

`GrammarStrategy` defaults to the `antlr4` backend and records ordered phases: select core, CTEs and subqueries, DML, DDL, and dialect extensions. It is accepted by top-level parsing APIs and stored by `SqlParser`.

`Grammar/JSqlParserSubset.g4` is the active grammar source artifact and currently defines a minimal `SELECT ... FROM` subset. Parser-family implementations provide the broader behavior documented elsewhere; the strategy is metadata rather than a runtime parser switch.
