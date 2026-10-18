---
type: Testing Reference
title: Testing and Corpora
description: SwiftSqlParser tests parser families, dialect gates, visitors, deparsing, diagnostics, upstream-aligned cases, and SQL corpus resources.
tags: [support, testing, corpora]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: architecture
    resource: ../ARCHITECTURE.md
    title: Architecture guide
  - id: corpus-tests
    resource: ../../Tests/SwiftSqlParserTests/CorpusHarnessTests.swift
    title: Corpus harness tests
  - id: tests
    resource: ../../Tests/SwiftSqlParserTests
    title: SwiftSqlParser test suite
  - id: package
    resource: ../../Package.swift
    title: Swift package manifest
---

# Testing and Corpora

The `SwiftSqlParserTests` target uses Swift Testing and includes parser-family, AST, diagnostics, dialect extension, visitor/deparser, and upstream-aligned test files. Processed resources provide success, unsupported, DDL, utility, and script SQL corpora.

The corpus harness asserts expected parsed types, tracked unsupported gaps, raw round trips, DDL and utility deparsing, and multi-statement script behavior. Run the repository check with `swift test`.

New syntax should include parse and deparse assertions plus regression or corpus coverage as appropriate; see [Syntax Extension Workflow](../internals/extension-workflow.md).
