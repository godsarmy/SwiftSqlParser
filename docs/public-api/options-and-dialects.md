---
type: Configuration Reference
title: Options and Dialects
description: ParserOptions keeps lexical, script recovery, dialect, and experimental parsing choices explicit per parse.
tags: [configuration, dialects, recovery]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:02:37Z }
sources:
  - id: usage
    resource: ../USAGE.md
    title: Usage guide
  - id: options
    resource: ../../Sources/SwiftSqlParser/Parser/ParserOptions.swift
    title: Parser options definitions
  - id: parser-api
    resource: ../../Sources/SwiftSqlParser/Parser/SqlParserAPI.swift
    title: Parser feature gates
---

# Options and Dialects

`ParserOptions` is the behavior-control surface: identifier quoting, string escaping, script separators, parse-error recovery, unsupported-statement recovery, dialect features, and experimental features are all explicit values.

Defaults split scripts on `;`, standalone `GO`, standalone `/`, and triple newlines. Splitting ignores separators inside quoted strings and nested parentheses. `recoverParseErrors` continues script slots after failures; `recoverUnsupportedStatements` returns `UnsupportedStatement` for supported precheck failures.

Dialect flags include PostgreSQL, MySQL/MariaDB, SQL Server/Sybase, Oracle, BigQuery, Snowflake, DuckDB, Redshift, DB2, H2, HSQLDB, Derby, SQLite, and Salesforce SOQL. Experimental features include dialect-sensitive syntax such as `ILIKE`, `DISTINCT ON`, `TOP`, alternative Oracle quotes, `MERGE`, `REPLACE`, `PIVOT`, and piped SQL. Some syntax requires both its dialect and experimental flag.
