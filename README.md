# SwiftSqlParser

SwiftSqlParser parses SQL into a Swift AST with configurable dialect behavior.

## Install

Add the package in Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/godsarmy/SwiftSqlParser.git", from: "1.0.4")
]
```

Then add the product to your target dependencies:

```swift
.product(name: "SwiftSqlParser", package: "SwiftSqlParser")
```

## Features

- Query parsing
  - `SELECT`, `WITH` / CTE, `VALUES`, set operations, joins, `GROUP BY`, `HAVING`, `QUALIFY`, window functions, `ORDER BY`, `LIMIT`, `OFFSET`
- Write statements
  - `INSERT`, `UPDATE`, `DELETE`, dialect-gated `MERGE`, MySQL `REPLACE`, `RETURNING`, `ON CONFLICT`, `ON DUPLICATE KEY UPDATE`
- Schema statements
  - `CREATE TABLE`, `CREATE INDEX`, `CREATE VIEW`, `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`
- Utility statements
  - `EXPLAIN`, `SHOW`, `SET`, `RESET`, `USE`
- Dialect-aware options
  - Postgres `ILIKE` and `DISTINCT ON`
  - SQL Server `TOP`
  - Oracle alternative quoting
  - Quoted identifiers
  - Dialect-gated `PIVOT` / `UNPIVOT`
- Script and recovery support
  - delimiter-aware script splitting with parse-error and unsupported-statement recovery
  - default separators include `;`, `GO`, `/`, and double-blank-line boundaries; `GO` and `/` act as delimiter lines
- Parsing APIs
  - throwing entry points plus non-throwing results through `parseStatementResult(...)` and `parseStatementsResult(...)`
- Utilities and tooling
  - visitors, deparsers, and `TableNameFinder` for statements and expressions
  - upstream-aligned JSqlParser-derived tests plus curated SQL corpora for syntax and recovery coverage

## Quick Start

- Configure dialect and experimental behavior through `ParserOptions`
- Use the throwing parse APIs for typed ASTs and the result APIs when you want diagnostics without throwing
- Reach for `TableNameFinder` when you need quick table discovery from statements or expressions

```swift
import SwiftSqlParser

let options = ParserOptions(
    dialectFeatures: [.postgres],
    experimentalFeatures: [.postgresIlike, .postgresDistinctOn]
)

let statement = try parseStatement("SELECT id FROM users WHERE name ILIKE 'a%'", options: options)
let statements = try parseStatements("SELECT * FROM users;DELETE FROM users WHERE id = 1")
let script = parseScript(
    "SELECT 'a;b' FROM users;MATCH_RECOGNIZE (foo);SHOW TABLES",
    options: ParserOptions(recoverParseErrors: true, recoverUnsupportedStatements: true)
)

let statementResult = SqlParser().parseStatementResult("MATCH_RECOGNIZE (foo)")
let statementsResult = try SqlParser().parseStatementsResult("SELECT * FROM users;;SELECT * FROM roles")

let utility = try parseStatement("EXPLAIN SELECT * FROM users")
let tables = TableNameFinder().find(in: statement)
let expressionTables = TableNameFinder().find(in: BinaryExpression(
    left: IdentifierExpression(name: "users.id"),
    operator: .equals,
    right: IdentifierExpression(name: "roles.user_id")
))
```

- `statement` parses a single SQL statement with Postgres-specific options enabled
- `statements` parses a delimiter-separated batch
- `script` keeps going with recovery enabled and collects diagnostics for unsupported or invalid chunks
- `statementResult` and `statementsResult` expose non-throwing parse flows
- `utility`, `tables`, and `expressionTables` show the AST and utility layer around the core parser

## Development

- Run tests: `swift test`
- Run benchmark: `swift run SwiftSqlParserBenchmark`

## CLI

The repository also ships a simple CLI for local inspection:

- Parse a single statement from stdin by default
- Add `--json` for machine-readable output
- Add repeatable `--dialect <name>` flags for dialect-specific parsing
- Use `--script` for multi-statement input split by script separators

```bash
echo "SELECT * FROM users" | swift run SwiftSqlParserCLI
echo "SELECT * FROM users" | swift run SwiftSqlParserCLI --json
echo "SELECT id FROM users t AT ('2024-01-01')" | swift run SwiftSqlParserCLI --dialect snowflake
printf "SELECT * FROM users\nGO\nSELECT * FROM roles\n" | swift run SwiftSqlParserCLI --script
```

- Reads SQL from stdin and prints a human-readable tree by default
- Prints parse diagnostics to stderr and exits non-zero on failure
- Exposes dialect flags only; syntax that also needs experimental flags still uses the library API

## Documentation

- `Docs/USAGE.md` - parser APIs, options, diagnostics, and examples
- `Docs/ARCHITECTURE.md` - system design, parser pipeline, and extension workflow
- `AGENTS.md` - repository guidance for coding agents
