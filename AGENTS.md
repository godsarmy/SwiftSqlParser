# AGENTS Guide

This file gives coding agents a fast, reliable map for working in this repository.

## Project Goal

Reimplement JSqlParser concepts in Swift with:

- parser entry APIs (`parseStatement`, `parseStatementResult`, `parseStatements`, `parseStatementsResult`, `parseScript`)
- extensible AST model
- visitor/deparser support
- deterministic diagnostics for parity tracking and tests
- recoverable batch/script parsing with slot-preserving results

## Code Map

- `Sources/SwiftSqlParser/AST/` - AST protocols and node models
- `Sources/SwiftSqlParser/Parser/` - parser entry API and statement-family parsers
  - `SelectCoreParser.swift` - query parsing (`SELECT`, `WITH`, `VALUES`, set ops, joins, window syntax)
  - `DmlParser.swift` - `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `REPLACE`
  - `DdlParser.swift` - table/view/index DDL
  - `SqlParserAPI.swift` - top-level dispatch, utility statements, script splitting, recovery behavior, and parse-result shaping
- `Sources/SwiftSqlParser/Visitors/` - visitor protocols, dispatch helpers, and `TableNameFinder` for statements and expressions
- `Sources/SwiftSqlParser/Deparser/` - SQL serialization from AST
- `Sources/SwiftSqlParserBenchmark/` - local benchmark executable
- `Tests/SwiftSqlParserTests/` - unit/corpus/round-trip/dialect tests

## Working Rules

1. Keep parser behavior option-driven, not global-state driven.
2. Preserve stable normalized diagnostics (`unsupported_syntax:*`, etc.).
3. AST changes should be additive-first; avoid breaking existing node names/fields.
4. For new syntax support, ship parser + deparser + tests together.
5. Keep unsupported syntax mapped to explicit diagnostics for parity tracking.
6. If script parsing or recovery behavior changes, update both `parseStatements` and `parseScript` coverage.

## Dialect and Experimental Flags

- Dialects live in `ParserOptions.dialectFeatures`.
- Experimental behavior is gated by `ParserOptions.experimentalFeatures`.
- Do not silently enable experimental behavior; require explicit flags.

## Required Checks Before Finishing

- `swift test`
- If parser hot paths were touched: `swift run SwiftSqlParserBenchmark`

## Change Patterns

### Adding new SQL syntax

1. Add/extend AST node types in `AST/`.
2. Parse it in the correct parser file under `Parser/`.
3. Add deparse path in `Deparser/`.
4. Add visitor hooks in `Visitors/` if it is a statement/expression node.
5. Update `TableNameFinder` when the new syntax introduces table references.
6. Add tests in `Tests/SwiftSqlParserTests/`:
   - parse assertions
   - deparse assertion
   - regression/corpus coverage where relevant

### Adding utility or script behavior

1. Update `SqlParserAPI.swift` for top-level dispatch and script handling.
2. Keep parse-error recovery and unsupported-statement recovery distinct and option-driven via `ParserOptions`.
3. Add script-level diagnostics tests when delimiter handling or recovery changes.
4. Update `Docs/USAGE.md` when behavior becomes user-visible.

### Adding dialect-specific behavior

1. Add/confirm dialect enum in `DialectFeature`.
2. Add/confirm explicit experimental gate in `ExperimentalFeature` if needed.
3. Gate parsing logic by both dialect and experimental flag when appropriate.
4. Add positive and negative tests (enabled vs disabled).

## Reference Docs

- `Docs/USAGE.md`
- `Docs/ARCHITECTURE.md`
