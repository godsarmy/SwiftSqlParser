# SwiftSqlParser

SwiftSqlParser parses SQL into a Swift AST with configurable dialect behavior.

## Current Status

- Core query support: `SELECT`, `WITH`/CTE, `VALUES`, set operations, joins, `GROUP BY`, `HAVING`, `QUALIFY`, window functions, `ORDER BY`, `LIMIT`, `OFFSET`
- DML support: `INSERT`, `UPDATE`, `DELETE`, dialect-gated `MERGE`, MySQL `REPLACE`, `RETURNING`, `ON CONFLICT`, `ON DUPLICATE KEY UPDATE`
- DDL support: `CREATE TABLE`, `CREATE INDEX`, `CREATE VIEW`, `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`
- Utility statements: `EXPLAIN`, `SHOW`, `SET`, `RESET`, `USE`
- Option-driven dialect extensions including Postgres `ILIKE` / `DISTINCT ON`, SQL Server `TOP`, Oracle alternative quoting, quoted identifiers, and dialect-gated `PIVOT` / `UNPIVOT`
- Script parsing supports delimiter-aware splitting and optional unsupported-statement recovery
- Default script separators include `;`, `GO`, `/`, and double-blank-line boundaries; `GO` and `/` are treated as delimiter lines
- Ecosystem utilities include visitors/deparsers plus `TableNameFinder`

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
    options: ParserOptions(recoverUnsupportedStatements: true)
)

let utility = try parseStatement("EXPLAIN SELECT * FROM users")
let tables = TableNameFinder().find(in: statement)
```

## Development

- Run tests: `swift test`
- Run benchmark: `swift run SwiftSqlParserBenchmark`

## Documentation

- `Docs/SupportMatrix.md` - current SQL and dialect support
- `Docs/VersioningAndCompatibility.md` - semantic versioning and stability policy
- `Docs/PerformanceAndRobustness.md` - benchmark and optimization notes
- `Docs/ReleasePlan.md` - release milestone status
- `AGENTS.md` - repository guidance for coding agents
