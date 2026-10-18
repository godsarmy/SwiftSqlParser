---
type: API Reference
title: Diagnostics and Parse Results
description: Deterministic diagnostics and slot-preserving result types expose parsing failures without losing input position.
tags: [api, diagnostics, recovery]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: usage
    resource: ../USAGE.md
    title: Usage guide
  - id: diagnostics
    resource: ../../Sources/SwiftSqlParser/Diagnostics/SqlDiagnostics.swift
    title: Diagnostic and result models
  - id: parser-api
    resource: ../../Sources/SwiftSqlParser/Parser/SqlParserAPI.swift
    title: Error and recovery behavior
---

# Diagnostics and Parse Results

`SqlDiagnostic` carries a code, human message, stable `normalizedMessage`, `SqlSourceLocation`, and optional token. The code set is `empty_input`, `empty_statement`, and `unsupported_syntax`; use normalized messages for stable parity and regression assertions.

`StatementParseResult` represents one optional statement and diagnostic. `StatementsParseResult` and `ScriptParseResult` expose `slots`, successful `statements`, and `diagnostics`; each `StatementParseSlot` retains its source location. [Parsing APIs](parsing.md) selects the appropriate failure mode.
