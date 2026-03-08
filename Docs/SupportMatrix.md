# SQL Support Matrix

This matrix tracks currently implemented parser support in SwiftSqlParser.

## Core Statement Families

| Area | Status | Notes |
|---|---|---|
| `SELECT` core | Supported | projection, `FROM`, `WHERE`, joins |
| `WITH` / CTE | Supported | `WITH ... AS (...)` with query body |
| Set operations | Supported | `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT` |
| `INSERT` | Supported | `INSERT INTO ... [(...)] VALUES (...)` |
| `UPDATE` | Supported | `UPDATE ... SET ... [WHERE ...]` |
| `DELETE` | Supported | `DELETE FROM ... [WHERE ...]` |
| `CREATE TABLE` | Supported | simple column list (`name type`) |
| `ALTER TABLE` | Supported | `ADD [COLUMN]`, `DROP [COLUMN]` |
| `DROP TABLE` | Supported | single table |
| `TRUNCATE [TABLE]` | Supported | single table |

## Dialect Features

Dialect behavior is option-driven and may require both a dialect flag and an experimental feature flag.

| Feature | Dialect Flag | Experimental Flag | Status |
|---|---|---|---|
| SQL Server bracket identifiers (`[name]`) | `.sqlServer` | `.quotedIdentifiers` | Supported |
| MySQL/BigQuery/Snowflake backtick identifiers (`` `name` ``) | `.mysql`/`.bigQuery`/`.snowflake` | `.quotedIdentifiers` | Supported |
| ANSI quoted identifiers (`"name"`) | any | `.quotedIdentifiers` | Supported |
| Postgres `ILIKE` | `.postgres` | `.postgresIlike` | Supported |

## Known Non-Goals / Current Gaps

The following syntax remains intentionally unsupported and reported via normalized diagnostics for parity tracking:

- `MERGE`
- `QUALIFY`
- `PIVOT`
- `UNPIVOT`
- `MATCH_RECOGNIZE`

## Stability Notes

- Public entry points (`parseStatement`, `parseStatements`, `parseScript`) are treated as stable.
- AST evolution is additive-first; breaking changes are reserved for major releases.
- Diagnostic `normalizedMessage` values are intended to remain deterministic for test automation.
