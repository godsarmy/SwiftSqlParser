---
type: Compatibility Reference
title: SQL Surface and JSqlParser Parity
description: The parity matrix records implemented statement families, partial dialect coverage, and known unsupported syntax.
tags: [support, parity, dialects]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: parity
    resource: ../PARITY.md
    title: JSqlParser parity matrix
  - id: readme
    resource: ../../README.md
    title: Project README
  - id: parser-api
    resource: ../../Sources/SwiftSqlParser/Parser/SqlParserAPI.swift
    title: Unsupported syntax checks
---

# SQL Surface and JSqlParser Parity

The project tracks high-level parity with JSqlParser rather than claiming full dialect conformance. Query, core DML, utility statements, and selected table/index/view DDL are implemented; broader vendor DDL remains partial.

Dialect families are generally partial. The matrix identifies focused support such as BigQuery select features, Snowflake time travel, PostgreSQL row-level security and expressions, SQL Server/Sybase features, MySQL-family quoting and replace support, SQLite UPSERT gating, and Salesforce SOQL `INCLUDES`/`EXCLUDES`.

`MATCH_RECOGNIZE` is intentionally an explicit unsupported gap. `MERGE`, `PIVOT`, and `UNPIVOT` require their experimental and dialect gates; see [Options and Dialects](../public-api/options-and-dialects.md).
