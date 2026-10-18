---
type: Engineering Guide
title: Syntax Extension Workflow
description: New SQL syntax should evolve the AST, parser, deparser, traversal support, and tests together under explicit feature gates.
tags: [internals, extensions, testing]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: architecture
    resource: ../ARCHITECTURE.md
    title: Architecture guide
  - id: agent-guide
    resource: ../../AGENTS.md
    title: Repository agent guide
---

# Syntax Extension Workflow

For new syntax, add or extend AST nodes, parse in the appropriate family, add deparser support, add visitor hooks when the node participates in traversal, update `TableNameFinder` for new table references, and add parse, deparse, and regression coverage.

Keep behavior option-driven. Dialect-specific behavior belongs in `DialectFeature`, and experimental behavior requires an explicit `ExperimentalFeature`; do not silently enable it. Preserve normalized diagnostics for unsupported syntax.

For delimiter or recovery changes, update `SqlParserAPI.swift` and cover both `parseStatements` and `parseScript` behavior. See [Testing and Corpora](../support/testing-and-corpora.md).
