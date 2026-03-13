# Piped SQL Parity Plan

Goal: close the remaining Piped SQL (FROM SQL) gaps against upstream JSqlParser.

## Upstream Baseline

Reference: `JSQLParser/JSqlParser` grammar (`JSqlParserCC.jjt`, pipe operator productions around lines 4025-4400 in current upstream).

Canonical upstream pipe operator families:

- `SELECT` (also `SEL`, plus `EXTEND`, `WINDOW`, `RENAME` synonyms)
- `SET`
- `DROP`
- `AS`
- `WHERE`
- `LIMIT` (with optional `OFFSET`)
- `AGGREGATE`
- `ORDER BY`
- `UNION` / `INTERSECT` / `EXCEPT`
- `JOIN`
- `CALL`
- `TABLE SAMPLE`
- `PIVOT`
- `UNPIVOT`

## Current SwiftSqlParser Coverage Snapshot

Implemented in `SelectCoreParser.parsePipedFromStatement(...)`:

- `WHERE`, `SELECT`, `DISTINCT`, `EXTEND`, `RENAME`, `DROP`, `HAVING`, `QUALIFY`, `ORDER BY`, `LIMIT`, `OFFSET`, `AS`, `JOIN`, `AGGREGATE`, `PIVOT`, `UNPIVOT`, `TABLESAMPLE`, `UNION`, `INTERSECT`, `EXCEPT`

## Confirmed Missing Features (7)

1. `SET` pipe operator is not implemented.
2. `CALL` pipe operator is not implemented.
3. `SEL` alias for piped `SELECT` is not implemented.
4. `WINDOW` alias for piped `SELECT` is not implemented.
5. Set-op modifiers beyond `ALL` are not implemented for piped `UNION`/`INTERSECT`/`EXCEPT` (e.g. `BY NAME`, `MATCHING`, `STRICT CORRESPONDING`).
6. Piped `AGGREGATE` does not support upstream inline `ORDER BY` forms (`... GROUP BY ... AND ORDER BY ...` / inline aggregate-order syntax).
7. Piped `LIMIT`/`OFFSET` currently requires integer literals; upstream accepts expression forms.

Note: upstream documents `TABLE SAMPLE` naming while SwiftSqlParser currently accepts `TABLESAMPLE`. This should be verified for exact token-compatibility behavior.

## Implementation Plan

1. Extend pipe operator dispatch in `Sources/SwiftSqlParser/Parser/SelectCoreParser.swift`:
   - Add `SET` branch and AST plumbing.
   - Add `CALL` branch and AST plumbing.
   - Accept `SEL` and `WINDOW` as aliases of `SELECT` behavior.
2. Expand set-op parsing in piped context:
   - Parse and represent upstream modifier families (`ALL`/`DISTINCT`, `BY NAME`, `MATCHING`, `STRICT CORRESPONDING ...`).
   - Keep parsing gated under existing experimental piped SQL flag.
3. Expand `AGGREGATE` pipe syntax support:
   - Add upstream-compatible inline ordering variations.
   - Preserve current deparse stability for existing forms.
4. Relax `LIMIT`/`OFFSET` in piped mode to expression-based forms where safe.
5. Add/extend AST + deparser support for any new operator payloads introduced by steps 1-4.
6. Add tests in `Tests/SwiftSqlParserTests/SelectCoreParserTests.swift`:
   - Positive and negative coverage for each missing feature.
   - Round-trip deparse checks for newly supported forms.
7. Update `Docs/PARITY.md` after implementation lands.

## Validation

- `swift test`
- `swift run SwiftSqlParserBenchmark` (if parser hot path changes are substantial)
