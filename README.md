# SwiftSqlParser

SwiftSqlParser parses SQL into a Swift AST with configurable dialect behavior.
The project is inspired by [JSqlParser](https://github.com/JSQLParser/JSqlParser).

## Install

Add the package in Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/godsarmy/SwiftSqlParser.git", from: "1.0.5")
]
```

Then add the product to your target dependencies:

```swift
.product(name: "SwiftSqlParser", package: "SwiftSqlParser")
```

## Quick Start

```swift
import SwiftSqlParser

let sqlStr = "select 1 from dual where a=b"
let statement = try parseStatement(sqlStr)

guard let select = statement as? PlainSelect else {
  fatalError("Expected PlainSelect")
}

guard let selectItem = select.selectItems.first as? ExpressionSelectItem,
      let one = selectItem.expression as? NumberLiteralExpression else {
  fatalError("Expected numeric select item")
}
assert(one.value == 1)

guard let table = select.from as? TableFromItem else {
  fatalError("Expected table from item")
}
assert(table.name == "dual")

guard let equals = select.whereExpression as? BinaryExpression,
      let a = equals.left as? IdentifierExpression,
      let b = equals.right as? IdentifierExpression else {
  fatalError("Expected binary WHERE expression")
}
assert(equals.operator == .equals)
assert(a.name == "a")
assert(b.name == "b")
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

- [`Docs/USAGE.md`](Docs/USAGE.md) - parser APIs, options, diagnostics, and examples
- [`Docs/ARCHITECTURE.md`](Docs/ARCHITECTURE.md) - system design, parser pipeline, and extension workflow
- [`Docs/PARITY.md`](Docs/PARITY.md) - current feature and dialect parity snapshot
- [`AGENTS.md`](AGENTS.md) - repository guidance for coding agents
