# SwiftSqlParser Architecture

## Purpose

SwiftSqlParser reimplements JSqlParser concepts in Swift with a focus on deterministic behavior, additive AST evolution, and option-driven dialect handling.

Core outcomes:

- stable parser entry points for single statements, batches, and scripts
- extensible AST plus visitors and deparsers
- deterministic diagnostics for parity tracking and tests
- recoverable script parsing with slot-preserving results

## Repository Layout

- `Sources/SwiftSqlParser/AST/` - AST protocols and node models (`Statement`, `Expression`, concrete SQL nodes)
- `Sources/SwiftSqlParser/Parser/` - parser entry APIs and statement-family parsers
  - `SqlParserAPI.swift` - top-level dispatch, script splitting, recovery shaping
  - `SelectCoreParser.swift` - query parsing (`SELECT`, `WITH`, `VALUES`, set ops, joins, windows)
  - `DmlParser.swift` - `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `REPLACE`
  - `DdlParser.swift` - table/view/index DDL and table alterations
  - `ParserOptions.swift` - option model and dialect/experimental feature gates
  - `GrammarStrategy.swift` - grammar backend/phase strategy metadata
- `Sources/SwiftSqlParser/Diagnostics/` - source locations, diagnostics, parse-result containers
- `Sources/SwiftSqlParser/Visitors/` - visitor protocols and `TableNameFinder`
- `Sources/SwiftSqlParser/Deparser/` - AST-to-SQL serialization
- `Sources/SwiftSqlParserBenchmark/` - local parser benchmark executable
- `Tests/SwiftSqlParserTests/` - unit, corpus, round-trip, and dialect tests

## Parsing Pipeline

1. Entry API trims/validates input and applies unsupported-syntax prechecks.
2. Statement-family routing uses SQL prefixes (`SELECT`, `INSERT`, `CREATE`, etc.) to pick parser paths.
3. Statement-family parsers build typed AST nodes.
4. Errors are converted to deterministic `SqlDiagnostic` values (`code`, `normalizedMessage`, `location`, optional `token`).
5. Result APIs shape output as throwing values, non-throwing results, or script slots.

Top-level APIs:

- throwing: `parseStatement`, `parseStatements`
- non-throwing/result-shaped: `parseStatementResult`, `parseStatementsResult`
- script-oriented: `parseScript`

## Option Model and Feature Gates

`ParserOptions` is the only behavior-control surface. No global parser state is required.

`ParserOptions` fields:

- lexical behavior: `identifierQuoting`, `escapeBehavior`
- script behavior: `scriptSeparators`, `recoverParseErrors`, `recoverUnsupportedStatements`
- dialect behavior: `dialectFeatures`
- experimental behavior: `experimentalFeatures`

Dialect flags (`DialectFeature`):

- `.postgres`, `.mysql`, `.sqlServer`, `.oracle`, `.bigQuery`, `.snowflake`

Experimental flags (`ExperimentalFeature`):

- `.postgresIlike`
- `.quotedIdentifiers`
- `.postgresDistinctOn`
- `.sqlServerTop`
- `.oracleAlternativeQuoting`
- `.mergeStatements`
- `.replaceStatements`
- `.pivotSyntax`

Some syntax requires both a matching dialect flag and a matching experimental flag.

## Diagnostics and Stability Contracts

Diagnostics are first-class parse outputs through `SqlDiagnostic` and include deterministic `normalizedMessage` values to support corpus parity and regression testing.

Diagnostic code families:

- `empty_input`
- `empty_statement`
- `unsupported_syntax`

Stability expectations:

- parser entry points are stable across minor releases
- AST evolution is additive-first
- normalized diagnostic messages are test-stable contracts

## Script Parsing and Recovery

Script parsing splits input into chunks with separator awareness while avoiding splits inside quoted strings and nested parentheses.

Default separators:

- `;`
- `GO` (line delimiter)
- `/` (line delimiter)
- triple newline (`\n\n\n`)

Recovery behavior:

- `recoverParseErrors: true` continues slot parsing after parse failures
- `recoverUnsupportedStatements: true` returns `UnsupportedStatement` for unsupported syntax

All script/batch result forms preserve slot locations to keep diagnostics and statement positions aligned.

## Grammar Strategy Metadata

`GrammarStrategy` models backend and phased delivery metadata:

- backend: `GrammarBackend.antlr4`
- phases: `select-core`, `with-and-subqueries`, `dml`, `ddl`, `dialect-extensions`

The active grammar source file is `Grammar/JSqlParserSubset.g4`.

## Performance and Robustness

Benchmark command:

```bash
swift run SwiftSqlParserBenchmark
```

Current benchmark scenarios:

- single-statement parse throughput (`parseStatement` loops)
- batch parse throughput (`parseStatements`)
- script parse throughput and diagnostics shaping (`parseScript`)

Robustness goals:

- deterministic diagnostics
- explicit unsupported syntax mapping for parity tracking
- behavior driven by options instead of hidden state

## Extension Workflow

For new syntax support:

1. Add/extend AST nodes.
2. Parse in the matching parser module.
3. Add deparser coverage.
4. Add visitor hooks when needed.
5. Update `TableNameFinder` if table references are introduced.
6. Add parse + deparse + regression tests.

For script/recovery behavior changes:

1. Update `SqlParserAPI.swift`.
2. Keep parse-error and unsupported-statement recovery distinct.
3. Add tests for delimiter and slot-level diagnostics.
