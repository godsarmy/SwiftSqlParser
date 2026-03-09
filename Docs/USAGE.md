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

let statements = try parseStatements(
    "SELECT * FROM users; DELETE FROM users WHERE id = 1"
)

let script = parseScript(
    "SELECT 'a;b' FROM users; MATCH_RECOGNIZE (foo); SHOW TABLES",
    options: ParserOptions(
        recoverParseErrors: true,
        recoverUnsupportedStatements: true
    )
)
```

## Parse a Statement

Parse SQL into typed Swift AST nodes and cast to the concrete statement you expect:

```swift
import SwiftSqlParser

let statement = try parseStatement("SELECT 1 FROM users WHERE a = b")
guard let select = statement as? PlainSelect else {
    fatalError("Expected PlainSelect")
}

let firstItem = select.selectItems[0] as? ExpressionSelectItem
let fromTable = select.from as? TableFromItem
let predicate = select.whereExpression as? BinaryExpression

print(firstItem?.alias as Any)
print(fromTable?.name as Any)
print(predicate?.operator as Any)
```

To inspect the parsed tree, cast to the concrete Swift AST types defined in `Sources/SwiftSqlParser/AST/` and walk them directly.

## Parse APIs

Top-level convenience functions:

- `parseStatement(_:, options:, strategy:) throws -> any Statement`
- `parseStatements(_:, options:, strategy:) throws -> [any Statement]`
- `parseScript(_:, options:, strategy:) -> ScriptParseResult`

`SqlParser` instance APIs expose the same behavior plus non-throwing result forms:

- `parseStatement(_:, options:) throws`
- `parseStatementResult(_:, options:) -> StatementParseResult`
- `parseStatements(_:, options:) throws`
- `parseStatementsResult(_:, options:) throws -> StatementsParseResult`
- `parseScript(_:, options:) -> ScriptParseResult`

Choose the API by failure mode:

- `parseStatement` for one statement and throwing behavior
- `parseStatementResult` for one statement plus diagnostic output instead of thrown errors
- `parseStatements` for delimited batches where the first diagnostic fails the call
- `parseStatementsResult` for slot-preserving batch results with both statements and diagnostics
- `parseScript` for script workloads with recovery and per-slot source locations

## Error Handling and Recovery

SwiftSqlParser supports the two recovery ideas highlighted in JSqlParser usage docs, but exposes them through `ParserOptions`.

Parse-error recovery:

```swift
let result = parseScript(
    "SELECT * FROM users; SELECT FROM; SELECT * FROM roles",
    options: ParserOptions(recoverParseErrors: true)
)

print(result.slots.count)
print(result.diagnostics.map(\.normalizedMessage))
```

Unsupported-statement recovery:

```swift
let result = parseScript(
    "SELECT * FROM users; MATCH_RECOGNIZE (foo); SHOW TABLES",
    options: ParserOptions(recoverUnsupportedStatements: true)
)

if let unsupported = result.slots[1].statement as? UnsupportedStatement {
    print(unsupported.sql)
    print(unsupported.diagnostic.normalizedMessage)
}
```

Behavior notes:

- `recoverParseErrors: true` keeps parsing later script slots after failures
- `recoverUnsupportedStatements: true` returns `UnsupportedStatement` instead of failing unsupported syntax
- `parseStatementsResult` and `parseScript` preserve slot order so diagnostics line up with input positions

## Parser Options and Dialects

`ParserOptions` is the central configuration surface:

- lexical behavior: `identifierQuoting`, `escapeBehavior`
- script behavior: `scriptSeparators`, `recoverParseErrors`, `recoverUnsupportedStatements`
- dialect behavior: `dialectFeatures`
- experimental behavior: `experimentalFeatures`

### Quoting and Escaping

Identifier quoting:

- `.ansiDoubleQuotes` for ANSI-style quoted identifiers
- `.squareBrackets` when working with T-SQL style bracketed identifiers

Escape behavior:

- `.backslash` when backslash escaping should be accepted
- `.standardConformingStrings` for stricter single-quote escaping behavior

Example:

```swift
let options = ParserOptions(
    identifierQuoting: .squareBrackets,
    escapeBehavior: .backslash,
    dialectFeatures: [.sqlServer],
    experimentalFeatures: [.quotedIdentifiers]
)

let statement = try parseStatement(
    "SELECT [name] FROM [users] WHERE [nickname] LIKE '\\_a%'",
    options: options
)
```

### Script Separators

Default separators match the JSqlParser usage guide:

- `;`
- `GO`
- `/`
- triple newline (`\n\n\n`)

Separator behavior:

- `;` splits statements inline
- `GO` and `/` split only when they appear on standalone delimiter lines
- separators are ignored inside quoted strings and nested parentheses

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

Example:

```swift
let options = ParserOptions(
    dialectFeatures: [.oracle],
    experimentalFeatures: [.oracleAlternativeQuoting, .mergeStatements, .pivotSyntax]
)
```

## Diagnostics and Result Types

Main result models:

- `SqlDiagnostic` - parse issue with `code`, `message`, `normalizedMessage`, `location`, and optional `token`
- `StatementParseResult` - one statement plus optional diagnostic
- `StatementsParseResult` - batch parse with `slots`, `statements`, and `diagnostics`
- `ScriptParseResult` - script parse with `slots`, `statements`, and `diagnostics`
- `StatementParseSlot` - one slot containing `statement`, `diagnostic`, and `location`

Diagnostic codes:

- `empty_input`
- `empty_statement`
- `unsupported_syntax`

Use `normalizedMessage` for stable tests and parity tracking.

## Visitor Patterns

SwiftSqlParser exposes visitor protocols plus `AstVisit` dispatch helpers.

Example statement visitor:

```swift
import SwiftSqlParser

struct ColumnCollector: StatementVisitor, ExpressionVisitor {
    var names: [String] = []

    mutating func visit(plainSelect: PlainSelect) {
        if let predicate = plainSelect.whereExpression {
            AstVisit.expression(predicate, visitor: &self)
        }
    }

    mutating func visit(binaryExpression: BinaryExpression) {
        AstVisit.expression(binaryExpression.left, visitor: &self)
        AstVisit.expression(binaryExpression.right, visitor: &self)
    }

    mutating func visit(identifierExpression: IdentifierExpression) {
        names.append(identifierExpression.name)
    }
}

let statement = try parseStatement("SELECT * FROM users WHERE a = b")
var collector = ColumnCollector()
AstVisit.statement(statement, visitor: &collector)
print(collector.names)
```

For table discovery, `TableNameFinder` is the simpler built-in utility.

## Find Table Names

Use `TableNameFinder` for statements or standalone expressions:

```swift
let statement = try parseStatement(
    "SELECT * FROM A LEFT JOIN B ON A.id = B.id AND A.age = (SELECT age FROM C)"
)
let statementTables = TableNameFinder().find(in: statement)

let expression = BinaryExpression(
    left: IdentifierExpression(name: "A.id"),
    operator: .equals,
    right: SubqueryExpression(
        statement: PlainSelect(
            selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "age"))],
            from: TableFromItem(name: "C")
        )
    )
)
let expressionTables = TableNameFinder().find(in: expression)
```

## Build and Deparse SQL

You can build AST nodes directly, then serialize them back to SQL with `StatementDeparser`.

```swift
import SwiftSqlParser

let select = PlainSelect(
    selectItems: [
        ExpressionSelectItem(expression: NumberLiteralExpression(value: 1))
    ],
    from: TableFromItem(name: "dual", alias: "t"),
    whereExpression: BinaryExpression(
        left: IdentifierExpression(name: "a"),
        operator: .equals,
        right: IdentifierExpression(name: "b")
    )
)

let sql = StatementDeparser().deparse(select)
print(sql)
```

This is the Swift equivalent of JSqlParser's build-and-deparse workflow.

## Supported SQL Surface

Current implemented families include:

- query: `SELECT`, `WITH`, `VALUES`, set operations, joins, windows, ordering, `LIMIT`, `OFFSET`
- DML: `INSERT`, `UPDATE`, `DELETE`, dialect-gated `MERGE`, dialect-gated `REPLACE`
- DDL: `CREATE TABLE`, `CREATE INDEX`, `CREATE VIEW`, `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`
- utility: `EXPLAIN`, `SHOW`, `SET`, `RESET`, `USE`

Selected supported dialect-sensitive features include:

- quoted identifiers
- Postgres `ILIKE` and `DISTINCT ON`
- SQL Server `TOP`
- Oracle alternative quoting
- `PIVOT` and `UNPIVOT`

Known explicit gap:

- `MATCH_RECOGNIZE` is intentionally reported as unsupported via deterministic diagnostics

## Development Checks

- Run tests: `swift test`
- Run benchmark when parser hot paths change: `swift run SwiftSqlParserBenchmark`
