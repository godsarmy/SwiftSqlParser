# SwiftSqlParser

SwiftSqlParser parses SQL into a Swift AST with configurable dialect behavior.

## Install

Add the package in Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/godsarmy/SwiftSqlParser.git", from: "1.0.0")
]
```

Then add the product to your target dependencies:

```swift
.product(name: "SwiftSqlParser", package: "SwiftSqlParser")
```

## Current Status

- Core query support: `SELECT`, `WITH`/CTE, `VALUES`, set operations, joins, `GROUP BY`, `HAVING`, `QUALIFY`, window functions, `ORDER BY`, `LIMIT`, `OFFSET`
- DML support: `INSERT`, `UPDATE`, `DELETE`, dialect-gated `MERGE`, MySQL `REPLACE`, `RETURNING`, `ON CONFLICT`, `ON DUPLICATE KEY UPDATE`
- DDL support: `CREATE TABLE`, `CREATE INDEX`, `CREATE VIEW`, `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`
- Utility statements: `EXPLAIN`, `SHOW`, `SET`, `RESET`, `USE`
- Option-driven dialect extensions including Postgres `ILIKE` / `DISTINCT ON`, SQL Server `TOP`, Oracle alternative quoting, quoted identifiers, and dialect-gated `PIVOT` / `UNPIVOT`
- Script parsing supports delimiter-aware splitting, parse-error recovery, and unsupported-statement recovery
- Default script separators include `;`, `GO`, `/`, and double-blank-line boundaries; `GO` and `/` are treated as delimiter lines
- Non-throwing result APIs are available through `parseStatementResult(...)` and `parseStatementsResult(...)`
- Ecosystem utilities include visitors/deparsers plus `TableNameFinder` for statements and expressions
- The test suite includes upstream-aligned JSqlParser-derived coverage plus curated SQL corpora for supported syntax and recovery stress tests

## Quick Start

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

## Development

- Run tests: `swift test`
- Run benchmark: `swift run SwiftSqlParserBenchmark`

## Documentation

- `Docs/USAGE.md` - parser APIs, options, diagnostics, and examples
- `Docs/ARCHITECTURE.md` - system design, parser pipeline, and extension workflow
- `AGENTS.md` - repository guidance for coding agents
