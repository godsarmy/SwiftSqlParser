# SQL Support Matrix

This matrix tracks currently implemented parser support in SwiftSqlParser.

## Core Statement Families

| Area | Status | Notes |
|---|---|---|
| `SELECT` core | Supported | projection, `DISTINCT`, `FROM`, `WHERE`, joins, `GROUP BY`, `HAVING`, `QUALIFY`, `ORDER BY`, `LIMIT`, `OFFSET` |
| `WITH` / CTE | Supported | `WITH ... AS (...)` with query body |
| `VALUES` query | Supported | top-level `VALUES (...)` and nested values subqueries |
| Set operations | Supported | `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT` |
| `INSERT` | Supported | `VALUES`, `DEFAULT VALUES`, `INSERT ... SELECT`, `RETURNING`, `ON CONFLICT`, `ON DUPLICATE KEY UPDATE` |
| `MERGE` | Supported | dialect-gated SQL Server / Oracle style `MERGE INTO ... USING ...` |
| `REPLACE` | Supported | dialect-gated MySQL `REPLACE INTO ...` |
| `UPDATE` | Supported | `UPDATE ... SET ... [FROM ...] [WHERE ...] [RETURNING ...]` |
| `DELETE` | Supported | `DELETE FROM ... [USING ...] [WHERE ...] [RETURNING ...]` |
| `CREATE TABLE` | Supported | columns with defaults/constraints plus table `PRIMARY KEY` / `FOREIGN KEY` / `CHECK` constraints |
| `CREATE INDEX` | Supported | `CREATE [UNIQUE] INDEX ... ON ... (...)` |
| `CREATE VIEW` | Supported | `CREATE VIEW ... AS <select>` |
| `ALTER TABLE` | Supported | `ADD/DROP [COLUMN]`, `RENAME [COLUMN]`, `RENAME TO`, `ADD/DROP CONSTRAINT` |
| `DROP TABLE` | Supported | single table |
| `TRUNCATE [TABLE]` | Supported | single table |
| Utility statements | Supported | `EXPLAIN`, `SHOW`, `SET`, `RESET`, `USE` |

## Dialect Features

Dialect behavior is option-driven and may require both a dialect flag and an experimental feature flag.

| Feature | Dialect Flag | Experimental Flag | Status |
|---|---|---|---|
| SQL Server bracket identifiers (`[name]`) | `.sqlServer` | `.quotedIdentifiers` | Supported |
| MySQL/BigQuery/Snowflake backtick identifiers (`` `name` ``) | `.mysql`/`.bigQuery`/`.snowflake` | `.quotedIdentifiers` | Supported |
| ANSI quoted identifiers (`"name"`) | any | `.quotedIdentifiers` | Supported |
| Postgres `ILIKE` | `.postgres` | `.postgresIlike` | Supported |
| Postgres `DISTINCT ON` | `.postgres` | `.postgresDistinctOn` | Supported |
| SQL Server `TOP` | `.sqlServer` | `.sqlServerTop` | Supported |
| Oracle alternative quoting (`q'[...]'`) | `.oracle` | `.oracleAlternativeQuoting` | Supported |
| SQL Server/Oracle `MERGE` | `.sqlServer`/`.oracle` | `.mergeStatements` | Supported |
| MySQL `REPLACE` | `.mysql` | `.replaceStatements` | Supported |
| SQL Server/Oracle `PIVOT` / `UNPIVOT` | `.sqlServer`/`.oracle` | `.pivotSyntax` | Supported |

## Expression Features

| Feature | Status | Notes |
|---|---|---|
| Comparison operators | Supported | `=`, `!=`, `<>`, `<`, `<=`, `>`, `>=` |
| Null predicates | Supported | `IS NULL`, `IS NOT NULL` |
| Membership/range predicates | Supported | `IN`, `NOT IN`, `BETWEEN`, `NOT BETWEEN` |
| Pattern predicates | Supported | `LIKE`, Postgres `ILIKE` |
| Conditional expressions | Supported | searched/simple `CASE` |
| Casts | Supported | `CAST(... AS type)`, Postgres `::` |
| Placeholders | Supported | `?`, `$1`-style positional placeholders |
| Existence predicates | Supported | `EXISTS (subquery)` |
| Window functions | Supported | `... OVER (PARTITION BY ... ORDER BY ...)` and named windows |

## Join / From Features

| Feature | Status | Notes |
|---|---|---|
| Lateral subqueries | Supported | `LATERAL (...) alias` |
| Natural joins | Supported | `NATURAL JOIN`, `NATURAL LEFT/RIGHT/FULL JOIN` |
| USING joins | Supported | `JOIN ... USING (...)` |
| APPLY joins | Supported | `CROSS APPLY`, `OUTER APPLY` |
| Pivoted sources | Supported | `FROM ... PIVOT (...) alias` |
| Unpivoted sources | Supported | `FROM ... UNPIVOT (...) alias` |

## Known Non-Goals / Current Gaps

The following syntax remains intentionally unsupported and reported via normalized diagnostics for parity tracking:

- `MATCH_RECOGNIZE`

## Script Parsing

| Feature | Status | Notes |
|---|---|---|
| Delimiter-aware splitting | Supported | ignores separators inside quoted strings and nested parentheses |
| Unsupported recovery | Supported | `ParserOptions(recoverUnsupportedStatements: true)` returns `UnsupportedStatement` while preserving diagnostics |
| Default separators | Supported | defaults include `;`, `GO`, `/`, and blank-line delimiters |
| Line-aware delimiters | Supported | `GO` and `/` split only when they appear on standalone delimiter lines |

## Utilities

| Feature | Status | Notes |
|---|---|---|
| Table name finder | Supported | `TableNameFinder` walks statements and returns referenced tables, excluding CTE aliases |

## Stability Notes

- Public entry points (`parseStatement`, `parseStatements`, `parseScript`) are treated as stable.
- AST evolution is additive-first; breaking changes are reserved for major releases.
- Diagnostic `normalizedMessage` values are intended to remain deterministic for test automation.
