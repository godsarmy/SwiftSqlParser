---
type: Implementation Reference
title: Parser Families
description: Top-level dispatch delegates recognized SQL prefixes to select-core, DML, DDL, or utility parsing paths.
tags: [internals, parser, sql]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: architecture
    resource: ../ARCHITECTURE.md
    title: Architecture guide
  - id: parser-api
    resource: ../../Sources/SwiftSqlParser/Parser/SqlParserAPI.swift
    title: Top-level parser API
  - id: select-parser
    resource: ../../Sources/SwiftSqlParser/Parser/SelectCoreParser.swift
    title: Select-core parser
  - id: dml-parser
    resource: ../../Sources/SwiftSqlParser/Parser/DmlParser.swift
    title: DML parser
  - id: ddl-parser
    resource: ../../Sources/SwiftSqlParser/Parser/DdlParser.swift
    title: DDL parser
---

# Parser Families

`SelectCoreParser` handles `SELECT`, `WITH`, `VALUES`, parenthesized query forms, set operations, and experimental `FROM`-led pipelines. `DmlParser` handles `INSERT`, `UPSERT`, `UPDATE`, `DELETE`, and gated `MERGE` and `REPLACE`. `DdlParser` handles `CREATE`, `ALTER`, `DROP`, and `TRUNCATE`, including table, index, view, and policy paths.

`SqlParser` handles `EXPLAIN`, `SHOW`, `SET`, `RESET`, and `USE` directly before family routing. A recognized family parse failure is normalized to a family-specific unsupported-syntax diagnostic; unknown prefixes become `RawStatement`.
