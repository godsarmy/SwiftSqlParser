# JSqlParser Parity TODO

This file tracks major feature gaps between `SwiftSqlParser` and `JSqlParser` and suggests a practical implementation order.

## Status Legend

- `supported`: implemented in `SwiftSqlParser`
- `partial`: some support exists, but coverage is limited
- `missing`: not implemented

## Parity Checklist

### Statements / scripting

- `supported`: top-level dispatch for query, DML, DDL
- `supported`: `parseStatements` and `parseScript` with diagnostics
- `partial`: script parsing is separator-based only
- `missing`: `IF ... ELSE`
- `missing`: `BEGIN ... END` blocks
- `missing`: unsupported-statement recovery similar to JSqlParser
- `missing`: richer statement families such as transaction/session/utility statements

### SELECT / query clauses

- `supported`: `SELECT ... FROM ... WHERE`
- `supported`: `WITH` / CTE
- `supported`: subqueries
- `supported`: aliases
- `supported`: set operations `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT`
- `partial`: `PlainSelect` only models a narrow core query shape
- `missing`: `DISTINCT`
- `missing`: `GROUP BY`
- `missing`: `HAVING`
- `missing`: `ORDER BY`
- `missing`: `LIMIT`
- `missing`: `OFFSET`
- `missing`: `FETCH`
- `missing`: `TOP`
- `missing`: `QUALIFY`
- `missing`: `VALUES` queries
- `missing`: window clauses
- `missing`: `PIVOT`
- `missing`: `UNPIVOT`
- `missing`: `MATCH_RECOGNIZE`

### FROM / JOIN

- `supported`: table references
- `supported`: subquery `FROM` items
- `supported`: `INNER JOIN`
- `supported`: `LEFT JOIN`
- `supported`: `RIGHT JOIN`
- `supported`: `FULL JOIN`
- `supported`: `CROSS JOIN`
- `supported`: `ON` predicates
- `partial`: alias handling works for simple sources only
- `missing`: `USING`
- `missing`: `NATURAL JOIN`
- `missing`: `LATERAL`
- `missing`: `APPLY`
- `missing`: table-valued functions
- `missing`: `UNNEST`
- `missing`: Oracle outer join syntax
- `missing`: join hints

### Expressions

- `supported`: identifiers
- `supported`: string literals
- `supported`: numeric literals
- `supported`: unary `+`, `-`, `NOT`
- `supported`: binary `=`, `!=`, `<>`
- `supported`: boolean `AND`, `OR`
- `supported`: arithmetic `+`, `-`, `*`, `/`
- `supported`: function calls
- `supported`: parenthesized expressions
- `supported`: subquery expressions
- `partial`: Postgres `ILIKE` is feature-gated and narrow
- `missing`: `<`, `>`, `<=`, `>=`
- `missing`: `LIKE`
- `missing`: `IN`
- `missing`: `BETWEEN`
- `missing`: `IS NULL` / `IS NOT NULL`
- `missing`: `EXISTS`
- `missing`: `CASE`
- `missing`: `CAST`
- `missing`: Postgres `::`
- `missing`: `INTERVAL`
- `missing`: parameter markers / placeholders
- `missing`: arrays
- `missing`: JSON operators / expressions
- `missing`: XML expressions
- `missing`: regex operators
- `missing`: analytic / window expressions

### DML

- `supported`: `INSERT INTO ... VALUES (...)`
- `supported`: `UPDATE ... SET ... [WHERE ...]`
- `supported`: `DELETE FROM ... [WHERE ...]`
- `partial`: DML expressions are limited by the current expression grammar
- `missing`: `INSERT ... SELECT`
- `missing`: `DEFAULT VALUES`
- `missing`: `INSERT ... SET`
- `missing`: `RETURNING`
- `missing`: `ON CONFLICT`
- `missing`: `ON DUPLICATE KEY UPDATE`
- `missing`: `MERGE`
- `missing`: `UPSERT`
- `missing`: joined `UPDATE`
- `missing`: `UPDATE ... FROM`
- `missing`: joined `DELETE`
- `missing`: `DELETE ... USING`
- `missing`: output clauses
- `missing`: DML `ORDER BY` / `LIMIT`

### DDL / utility statements

- `supported`: `CREATE TABLE`
- `supported`: `ALTER TABLE ... ADD COLUMN`
- `supported`: `ALTER TABLE ... DROP COLUMN`
- `supported`: `DROP TABLE`
- `supported`: `TRUNCATE TABLE`
- `partial`: column definitions only support `name type`
- `missing`: column constraints
- `missing`: defaults
- `missing`: primary keys
- `missing`: foreign keys
- `missing`: checks
- `missing`: indexes
- `missing`: schemas
- `missing`: views
- `missing`: sequences
- `missing`: rename statements
- `missing`: comment statements
- `missing`: grant / revoke
- `missing`: explain / describe
- `missing`: show / set / reset / use
- `missing`: lock / analyze
- `missing`: import / export
- `missing`: procedures / functions
- `missing`: materialized views
- `missing`: policy / security statements

### Dialect / parser features

- `supported`: ANSI double-quoted identifiers behind feature flag
- `supported`: SQL Server bracket identifiers
- `supported`: MySQL / BigQuery / Snowflake backtick identifiers
- `supported`: Postgres `ILIKE` behind explicit flags
- `supported`: configurable script separators
- `partial`: only a small whitelist of dialect features exists
- `missing`: broad vendor syntax coverage comparable to JSqlParser
- `missing`: most Oracle-specific constructs
- `missing`: most SQL Server-specific constructs
- `missing`: most MySQL/MariaDB-specific constructs
- `missing`: most PostgreSQL-specific constructs beyond `ILIKE`
- `missing`: SQLite / DuckDB / Redshift / Databricks / Salesforce coverage

### AST / visitors / deparsers / utilities

- `supported`: AST for currently implemented core statements and expressions
- `supported`: visitor protocols for current nodes
- `supported`: deparsers for current nodes
- `partial`: visitor/deparser breadth only matches the small current AST
- `missing`: AST nodes for most advanced query / DML / DDL constructs
- `missing`: table-name finder utility comparable to JSqlParser
- `missing`: broader SQL builder / manipulation conveniences

## Recommended Implementation Order

1. Expand core query shape
   - Add `DISTINCT`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT`, `OFFSET`
2. Expand expression grammar
   - Add comparisons, `LIKE`, `IN`, `BETWEEN`, `IS NULL`, `CASE`, `CAST`
3. Expand DML
   - Add `INSERT ... SELECT`, `RETURNING`, `ON CONFLICT`, joined `UPDATE` / `DELETE`
4. Expand DDL
   - Add constraints, indexes, views, rename support
5. Add advanced dialect-heavy features
   - Add `MERGE`, `PIVOT`, `UNPIVOT`, window syntax, vendor-specific constructs
6. Add utilities and parity helpers
   - Add unsupported-statement recovery, richer diagnostics, table-name finder, broader visitor/deparser support

## Milestone Plan

### Milestone 1: Core query parity

- [ ] Extend AST for `DISTINCT`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT`, `OFFSET`
- [ ] Parse those clauses in `SelectCoreParser`
- [ ] Deparse the new query clauses
- [ ] Add visitor coverage for new query nodes
- [ ] Add parse + deparse + regression tests for each clause

### Milestone 2: Expression parity

- [ ] Add AST nodes/operators for comparison operators `<`, `>`, `<=`, `>=`
- [ ] Add support for `LIKE`, `IN`, `BETWEEN`, `IS NULL`, `EXISTS`
- [ ] Add `CASE` expressions
- [ ] Add `CAST` and Postgres `::`
- [ ] Add placeholders / parameter markers
- [ ] Add parse + deparse + regression tests for expression precedence and nesting

### Milestone 3: Practical DML parity

- [ ] Support `INSERT ... SELECT`
- [ ] Support `DEFAULT VALUES`
- [ ] Support `RETURNING`
- [ ] Support Postgres `ON CONFLICT`
- [ ] Support MySQL `ON DUPLICATE KEY UPDATE`
- [ ] Support `UPDATE ... FROM`
- [ ] Support `DELETE ... USING`
- [ ] Add parse + deparse + regression tests for each DML variant

### Milestone 4: Practical DDL parity

- [ ] Extend column definitions with defaults and constraints
- [ ] Add primary key / foreign key / check constraint modeling
- [ ] Support `CREATE INDEX`
- [ ] Support `ALTER TABLE` rename and constraint operations
- [ ] Support `CREATE VIEW`
- [ ] Add parse + deparse + regression tests for each DDL addition

### Milestone 5: Advanced query features

- [ ] Add window / analytic function support
- [ ] Add `VALUES` query support
- [ ] Add `LATERAL` / `APPLY`
- [ ] Add `USING` and `NATURAL JOIN`
- [ ] Add `QUALIFY`
- [ ] Add parse + deparse + regression tests for advanced query forms

### Milestone 6: Vendor-heavy features

- [ ] Add `MERGE`
- [ ] Add `UPSERT` / `REPLACE` where appropriate
- [ ] Add `PIVOT` / `UNPIVOT`
- [ ] Add more PostgreSQL-specific syntax beyond `ILIKE`
- [ ] Add more SQL Server / MySQL / Oracle-specific constructs behind parser options
- [ ] Add enabled-vs-disabled tests for dialect-gated syntax

### Milestone 7: Utility statements and scripting

- [ ] Improve `parseScript` to be delimiter-aware rather than pure substring splitting
- [ ] Add unsupported-statement recovery mode
- [ ] Add utility statements such as `EXPLAIN`, `SHOW`, `SET`, `RESET`, `USE`
- [ ] Evaluate support for procedural blocks (`IF`, `BEGIN ... END`) if parity requires them
- [ ] Add script-level diagnostics and recovery tests

### Milestone 8: Ecosystem parity

- [ ] Add a table-name finder utility
- [ ] Expand visitors for all new AST families
- [ ] Expand deparsers for all new AST families
- [ ] Update `Docs/SupportMatrix.md` as each feature lands
- [ ] Add corpus/parity fixtures derived from JSqlParser-supported SQL samples

## Suggested Work Breakdown

- [ ] Start with Milestone 1 and Milestone 2 before adding vendor-specific syntax
- [ ] Keep every feature additive-first in the AST
- [ ] Ship parser + AST + deparser + visitors + tests together for each syntax family
- [ ] Gate dialect-specific behavior with `ParserOptions`
- [ ] Keep normalized diagnostics stable for unsupported or partial syntax

## Key Evidence

- `Docs/SupportMatrix.md`
- `Sources/SwiftSqlParser/Parser/SqlParserAPI.swift`
- `Sources/SwiftSqlParser/Parser/SelectCoreParser.swift`
- `Sources/SwiftSqlParser/Parser/DmlParser.swift`
- `Sources/SwiftSqlParser/Parser/DdlParser.swift`
- `Sources/SwiftSqlParser/Parser/ParserOptions.swift`
- `Sources/SwiftSqlParser/AST/SqlAst.swift`
- `Sources/SwiftSqlParser/Visitors/SqlVisitors.swift`
- `Sources/SwiftSqlParser/Deparser/StatementDeparser.swift`
