---
type: Compatibility Reference
title: JSqlParser Parity Matrix
description: High-level SwiftSqlParser feature and dialect parity tracking against JSqlParser capability claims.
tags: [parity, compatibility, dialects]
status: stable
generated: { by: openai/gpt-5.6-terra, at: 2026-10-18T18:07:26Z }
sources:
  - id: readme
    resource: ../README.md
    title: Project README
  - id: options
    resource: ../Sources/SwiftSqlParser/Parser/ParserOptions.swift
    title: Parser dialect and experimental options
---

# JSqlParser Parity Matrix

This document tracks high-level feature parity against the JSqlParser capability claims.

Status legend:

- `implemented` - a typed parser + deparser path exists and is covered by tests; this does not imply complete vendor grammar coverage
- `partial` - some syntax or dialect coverage exists, but not full family coverage
- `missing` - not implemented yet

## Upstream Baseline

Reviewed on 2026-10-18 against:

- Release target: [JSqlParser 5.4](https://github.com/JSQLParser/JSqlParser/releases/tag/jsqlparser-5.4), released 2026-09-13.
- Development snapshot: [`f6ac2571e6e9777d6a5ee942a4ea53cd91153e4d`](https://github.com/JSQLParser/JSqlParser/tree/f6ac2571e6e9777d6a5ee942a4ea53cd91153e4d), committed 2026-10-18.

The review sampled the latest 100 commits and the 5.4 release notes; it is not an exhaustive differential conformance run. Future reviews should record the new snapshot and compare it with this baseline.

Raw passthrough (`RawStatement`) preserves SQL text but does not count as typed syntax support, AST traversal, or table-discovery parity. For example, `CHECK TABLE t` currently passes through as raw SQL. Unsupported syntax within recognized parser families produces normalized diagnostics instead.

## Tracked Upstream Regressions

Local coverage is in `Tests/SwiftSqlParserTests/UpstreamRegressionTests.swift`.

| Upstream reference | Local coverage | Status |
|---|---|---|
| [#2751: trailing LIMIT/OFFSET on set operations](https://github.com/JSQLParser/JSqlParser/pull/2751) | Combined-query ORDER BY/LIMIT/OFFSET, operand-local clauses, nested grouping, WITH/VALUES operands, and piped set operations | implemented |
| [#2749: query and DML table-finder children](https://github.com/JSQLParser/JSqlParser/pull/2749) and [#2826: skipped expression children](https://github.com/JSQLParser/JSqlParser/pull/2826) | VALUES, DISTINCT ON, star replacements, conflict and duplicate-key updates, and expression-based pagination; broader upstream node types remain outside our AST | partial |
| [#2831: power/XOR precedence](https://github.com/JSQLParser/JSqlParser/pull/2831) and [#2833: bitwise precedence](https://github.com/JSQLParser/JSqlParser/pull/2833) | Operators are not yet represented in the Swift binary-expression AST | missing |

## Dialect Families

| Family | Status | Notes |
|---|---|---|
| BigQuery | partial | Includes BigQuery-specific `AS STRUCT`/`AS VALUE`, `SELECT * EXCEPT/REPLACE`, cast `FORMAT`, and `FOR SYSTEM_TIME AS OF`; broader dialect surface remains. |
| Snowflake | partial | Includes Snowflake table time-travel clause parsing (`AT`/`BEFORE`/`CHANGES`) but broader Snowflake syntax is not fully covered. |
| DuckDB | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| Redshift | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| Oracle | partial | Core DML/DDL supported; Oracle alt quoting and selected dialect-gated syntax supported. |
| SQL Server | partial | Core DML/DDL supported; `TOP`, `PIVOT`/`UNPIVOT`, and bracket quoting supported via feature flags. |
| Sybase | partial | Alias coverage for SQL Server-gated `TOP`, `MERGE`, `PIVOT`/`UNPIVOT`, and bracket quoting is supported. |
| Postgres | partial | Core DML/DDL supported; `ILIKE`, `DISTINCT ON`, RLS (`CREATE POLICY`, `ALTER TABLE ... ROW LEVEL SECURITY`) supported. |
| MySQL | partial | Core DML/DDL supported; backtick quoting and `REPLACE` (feature-gated) supported. |
| MariaDB | partial | Alias coverage for MySQL backticks and `REPLACE` supported. |
| DB2 | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| H2 | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| HSQLDB | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| Derby | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| SQLite | partial | Dialect flag exists; includes SQLite in backtick quoting and UPSERT gating; broader syntax coverage is limited. |
| Salesforce SOQL | partial | `INCLUDES`/`EXCLUDES` expressions supported; broader SOQL grammar is not implemented. |

## Statement Families

| Statement Family | Status | Notes |
|---|---|---|
| SELECT | implemented | Includes `WITH`, `VALUES`, joins, set ops, windows, ordering, limit/offset, and multiple expression forms. |
| INSERT | implemented | Includes values/select/default values plus conflict/duplicate/returning variants already supported in project. |
| UPDATE | implemented | Includes `FROM` and `RETURNING` support currently present in parser. |
| UPSERT | implemented | `UPSERT INTO ...` supported with dialect gate (`postgres` or `sqlite`). |
| MERGE | implemented | Feature-gated; supported for SQL Server/Sybase/Oracle dialect paths. |
| DELETE | implemented | Includes `USING` and `RETURNING` support currently present in parser. |
| TRUNCATE TABLE | implemented | `TRUNCATE TABLE` supported. |
| CREATE / ALTER / DROP | partial | Core table/index/view and selected alter operations supported; full vendor DDL breadth is larger than current implementation. |

## Feature Areas

| Feature | Status | Notes |
|---|---|---|
| `WITH` / CTE syntax | implemented | `WITH ... AS (...) SELECT ...` parsing is supported (including multiple CTE entries) via `WithSelect` and `CommonTableExpression`, with parser/deparser coverage and tests. |
| PostgreSQL Row Level Security | implemented | `CREATE POLICY` and `ALTER TABLE ... ENABLE/DISABLE/FORCE/NO FORCE ROW LEVEL SECURITY` supported. |
| SOQL `INCLUDES` / `EXCLUDES` | implemented | Dialect-gated under `.salesforceSoql`. |
| Piped SQL (FROM SQL) | implemented | Experimental `.pipedSql`; supports `FROM ... |> WHERE/SELECT/SEL/WINDOW/DISTINCT/EXTEND/RENAME/SET/DROP/HAVING/QUALIFY/ORDER BY/LIMIT/OFFSET/AS/JOIN/AGGREGATE/CALL/PIVOT/UNPIVOT/TABLESAMPLE/UNION/INTERSECT/EXCEPT`, including richer set-op modifiers and expression-based piped pagination. |

## Next Recommended Work

1. Add missing bitwise, shift, power, modulo, and concatenation operators with explicit precedence tests in both query and DML parsing.
2. Expand DuckDB coverage: star RENAME, comprehensions, slices, lambdas, numeric separators, percentage limits, methodless sampling, FROM-first/TABLE operands, and named-window inheritance.
3. Extend typed PostgreSQL/MySQL DDL, including ON COMMIT, access methods, DROP behavior, column positions, and attributes; retain additive AST APIs.
4. Add typed MySQL maintenance statements and track PostgreSQL ownership, Informix constraints, ClickHouse transformers, and ksqlDB clauses as separate gaps.
5. Add dialect-focused conformance tests for redshift, db2, h2, hsqldb, derby, and deeper sqlite behavior.
6. Verify whether upstream TABLE SAMPLE spelling should also be accepted alongside the current TABLESAMPLE tokenization path.
