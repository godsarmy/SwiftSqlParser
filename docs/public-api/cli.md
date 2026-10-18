---
type: CLI Reference
title: SwiftSqlParserCLI
description: The bundled CLI reads SQL from stdin and renders a parsed tree or JSON for local inspection.
tags: [cli, tooling, parsing]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: readme
    resource: ../../README.md
    title: Project README
  - id: usage
    resource: ../USAGE.md
    title: Usage guide
  - id: cli
    resource: ../../Sources/SwiftSqlParserCLI/main.swift
    title: CLI implementation
  - id: package
    resource: ../../Package.swift
    title: Swift package manifest
---

# SwiftSqlParserCLI

Run `swift run SwiftSqlParserCLI` and pipe SQL on standard input. Single-statement mode is the default; `--script` uses script parsing, `--json` emits pretty JSON, and repeatable `--dialect <name>` enables supported dialect flags.

The CLI prints a human-readable reflected tree by default. It sends diagnostics to standard error and exits nonzero on parse failure. It exposes dialect flags only, so experimental syntax must be enabled through the library API.
