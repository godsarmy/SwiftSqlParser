# SwiftSqlParser Usage

## Install

Use Swift Package Manager and import:

```swift
import SwiftSqlParser
```

## Quick Start

```swift
import SwiftSqlParser

let options = ParserOptions(
    dialectFeatures: [.postgres],
    experimentalFeatures: [.postgresIlike, .postgresDistinctOn]
)

let statement = try parseStatement(
    "SELECT id FROM users WHERE name ILIKE 'a%'",
    options: options
)

let many = try parseStatements("SELECT * FROM users; DELETE FROM users WHERE id = 1")

let script = parseScript(
    "SELECT 'a;b' FROM users; MATCH_RECOGNIZE (foo); SHOW TABLES",
    options: ParserOptions(recoverParseErrors: true, recoverUnsupportedStatements: true)
)
```

## Entry APIs

Top-level convenience functions:

- `parseStatement(_:, options:, strategy:) throws -> any Statement`
- `parseStatements(_:, options:, strategy:) throws -> [any Statement]`
- `parseScript(_:, options:, strategy:) -> ScriptParseResult`

`SqlParser` instance APIs (same behavior, plus non-throwing result forms):

- `parseStatement(_:, options:) throws`
- `parseStatementResult(_:, options:) -> StatementParseResult`
- `parseStatements(_:, options:) throws`
- `parseStatementsResult(_:, options:) throws -> StatementsParseResult`
- `parseScript(_:, options:) -> ScriptParseResult`

## Choosing a Parse API

- Use `parseStatement` for one statement and throwing failure behavior.
- Use `parseStatementResult` when you want diagnostic output instead of thrown errors.
- Use `parseStatements` for delimited statement lists when first diagnostic should fail the call.
- Use `parseStatementsResult` when you need slot-preserving statements + diagnostics.
- Use `parseScript` for script workloads with explicit per-slot locations and recovery behavior.

## Parser Options

`ParserOptions` controls parser behavior:

- lexical behavior:
  - `identifierQuoting`: `.ansiDoubleQuotes` or `.squareBrackets`
  - `escapeBehavior`: `.backslash` or `.standardConformingStrings`
- script behavior:
  - `scriptSeparators` (default: `;`, `GO`, `/`, `\n\n\n`)
  - `recoverParseErrors`
  - `recoverUnsupportedStatements`
- dialect behavior: `dialectFeatures`
- experimental behavior: `experimentalFeatures`

### Dialect Flags

- `.postgres`
- `.mysql`
- `.sqlServer`
- `.oracle`
- `.bigQuery`
- `.snowflake`

### Experimental Flags

- `.postgresIlike`
- `.quotedIdentifiers`
- `.postgresDistinctOn`
- `.sqlServerTop`
- `.oracleAlternativeQuoting`
- `.mergeStatements`
- `.replaceStatements`
- `.pivotSyntax`

Some syntax paths require both a dialect flag and an experimental flag.

## Script Separators and Recovery

Default separator behavior:

- `;` splits statements inline.
- `GO` and `/` split only when they appear as standalone delimiter lines.
- triple-newline separators (`\n\n\n`) are supported.

Recovery controls:

- `recoverParseErrors: true` keeps parsing script slots after a parse failure.
- `recoverUnsupportedStatements: true` emits `UnsupportedStatement` slots instead of failing unsupported syntax.

## Result Types and Diagnostics

Main diagnostic/result models:

- `SqlDiagnostic` (`code`, `message`, `normalizedMessage`, `location`, optional `token`)
- `StatementParseResult` (single statement + diagnostic)
- `StatementsParseResult` (slot-preserving batch parse)
- `ScriptParseResult` (slot-preserving script parse)
- `StatementParseSlot` (statement/diagnostic/location per slot)

Diagnostic codes:

- `empty_input`
- `empty_statement`
- `unsupported_syntax`

Use `normalizedMessage` for stable assertions in tests and corpus parity tracking.

## Supported SQL Surface

Current implemented families include:

- query: `SELECT`, `WITH`, `VALUES`, set operations, joins, windows, ordering/pagination
- DML: `INSERT`, `UPDATE`, `DELETE`, dialect-gated `MERGE`, dialect-gated `REPLACE`
- DDL: `CREATE TABLE`, `CREATE INDEX`, `CREATE VIEW`, `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`
- utility: `EXPLAIN`, `SHOW`, `SET`, `RESET`, `USE`

Known explicit gap:

- `MATCH_RECOGNIZE` is intentionally reported as unsupported via deterministic diagnostics.

## Visitors and Deparsing

- Use visitor protocols in `Sources/SwiftSqlParser/Visitors/` for AST traversal.
- Use `TableNameFinder` to extract referenced table names from statements and expressions.
- Use deparsers in `Sources/SwiftSqlParser/Deparser/` to serialize AST back to SQL.

Example:

```swift
let statement = try parseStatement("SELECT u.id FROM users u")
let tables = TableNameFinder().find(in: statement)
```

## Development Checks

- Run tests: `swift test`
- Run benchmark when parser hot paths change: `swift run SwiftSqlParserBenchmark`
