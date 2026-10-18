---
type: Architecture Reference
title: Parser Architecture
description: SwiftSqlParser routes SQL through option-aware parser families into typed ASTs, diagnostics, visitors, and deparsers.
tags: [internals, architecture, parser]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: architecture
    resource: ../ARCHITECTURE.md
    title: Architecture guide
  - id: parser-api
    resource: ../../Sources/SwiftSqlParser/Parser/SqlParserAPI.swift
    title: Top-level parser API
  - id: package
    resource: ../../Package.swift
    title: Swift package manifest
---

# Parser Architecture

The Swift package exposes a library plus CLI and benchmark executables. The library separates AST, parser, diagnostics, visitors, deparser, lexer, and namespace sources.

The top-level parser trims and validates input, performs explicit unsupported-syntax checks, routes recognized prefixes to statement-family parsers, and shapes failures as deterministic diagnostics. Result APIs then present throwing, nonthrowing, batch, or script forms. Script splitting maintains locations and avoids delimiters inside quotes and parentheses.

Configuration is per-call through `ParserOptions`, not global state. See [Parser Families](parser-families.md) and [Diagnostics](../public-api/diagnostics.md).
