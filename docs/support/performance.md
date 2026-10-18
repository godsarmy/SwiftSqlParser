---
type: Performance Reference
title: Parser Benchmark
description: The local benchmark measures statement-loop, batch, and script parsing over a generated 12,000-statement corpus.
tags: [support, performance, benchmark]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: readme
    resource: ../../README.md
    title: Project README
  - id: architecture
    resource: ../ARCHITECTURE.md
    title: Architecture guide
  - id: benchmark
    resource: ../../Sources/SwiftSqlParserBenchmark/main.swift
    title: Benchmark executable
  - id: package
    resource: ../../Package.swift
    title: Swift package manifest
---

# Parser Benchmark

Run `swift run SwiftSqlParserBenchmark` to execute the local benchmark executable. It builds a 12,000-statement generated corpus using representative query, DML, DDL, and CTE templates with selected PostgreSQL, MySQL, and SQL Server options.

The executable reports elapsed milliseconds for a `parseStatement` loop, `parseStatements` over a semicolon-joined batch, and `parseScript` diagnostics shaping. It is a local regression signal, not a published performance baseline.
