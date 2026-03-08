# SwiftSqlParser

SwiftSqlParser parses SQL into a Swift AST with configurable dialect behavior.

## Current Status

- Core query support: `SELECT`, `WITH`/CTE, set operations (`UNION`, `INTERSECT`, `EXCEPT`)
- DML support: `INSERT`, `UPDATE`, `DELETE`
- DDL support: `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`
- Option-driven dialect extensions (for example Postgres `ILIKE`, quoted identifiers)

## Quick Start

```swift
import SwiftSqlParser

let options = ParserOptions(
    dialectFeatures: [.postgres],
    experimentalFeatures: [.postgresIlike]
)

let statement = try parseStatement("SELECT id FROM users WHERE name ILIKE 'a%'", options: options)
let statements = try parseStatements("SELECT * FROM users;DELETE FROM users WHERE id = 1")
let script = parseScript("SELECT * FROM users;;SELECT * FROM roles")
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
