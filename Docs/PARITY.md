# JSqlParser Parity Matrix

This document tracks high-level feature parity against the JSqlParser capability claims.

Status legend:

- `implemented` - parser + deparser path exists and is covered by tests
- `partial` - some syntax or dialect coverage exists, but not full family coverage
- `missing` - not implemented yet

## Dialect Families

| Family | Status | Notes |
|---|---|---|
| BigQuery | partial | Includes BigQuery-specific `AS STRUCT`/`AS VALUE`, `SELECT * EXCEPT/REPLACE`, cast `FORMAT`, and `FOR SYSTEM_TIME AS OF`; broader dialect surface remains. |
| Snowflake | partial | Includes Snowflake table time-travel clause parsing (`AT`/`BEFORE`/`CHANGES`) but broader Snowflake syntax is not fully covered. |
| DuckDB | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| Redshift | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| Oracle | partial | Core DML/DDL supported; Oracle alt quoting and selected dialect-gated syntax supported. |
| SQL Server | partial | Core DML/DDL supported; `TOP`, `PIVOT`/`UNPIVOT`, and bracket quoting supported via feature flags. |
| Sybase | partial | Alias coverage for SQL Server-gated `TOP`, `MERGE`, `PIVOT`/`UNPIVOT`, and bracket quoting is supported. |
| Postgres | partial | Core DML/DDL supported; `ILIKE`, `DISTINCT ON`, RLS (`CREATE POLICY`, `ALTER TABLE ... ROW LEVEL SECURITY`) supported. |
| MySQL | partial | Core DML/DDL supported; backtick quoting and `REPLACE` (feature-gated) supported. |
| MariaDB | partial | Alias coverage for MySQL backticks and `REPLACE` supported. |
| DB2 | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| H2 | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| HSQLDB | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| Derby | partial | Dialect flag exists; dedicated syntax coverage is limited. |
| SQLite | partial | Dialect flag exists; includes SQLite in backtick quoting and UPSERT gating; broader syntax coverage is limited. |
| Salesforce SOQL | partial | `INCLUDES`/`EXCLUDES` expressions supported; broader SOQL grammar is not implemented. |

## Statement Families

| Statement Family | Status | Notes |
|---|---|---|
| SELECT | implemented | Includes `WITH`, `VALUES`, joins, set ops, windows, ordering, limit/offset, and multiple expression forms. |
| INSERT | implemented | Includes values/select/default values plus conflict/duplicate/returning variants already supported in project. |
| UPDATE | implemented | Includes `FROM` and `RETURNING` support currently present in parser. |
| UPSERT | implemented | `UPSERT INTO ...` supported with dialect gate (`postgres` or `sqlite`). |
| MERGE | implemented | Feature-gated; supported for SQL Server/Sybase/Oracle dialect paths. |
| DELETE | implemented | Includes `USING` and `RETURNING` support currently present in parser. |
| TRUNCATE TABLE | implemented | `TRUNCATE TABLE` supported. |
| CREATE / ALTER / DROP | partial | Core table/index/view and selected alter operations supported; full vendor DDL breadth is larger than current implementation. |

## Feature Areas

| Feature | Status | Notes |
|---|---|---|
| PostgreSQL Row Level Security | implemented | `CREATE POLICY` and `ALTER TABLE ... ENABLE/DISABLE/FORCE/NO FORCE ROW LEVEL SECURITY` supported. |
| SOQL `INCLUDES` / `EXCLUDES` | implemented | Dialect-gated under `.salesforceSoql`. |
| Piped SQL (FROM SQL) | partial | Experimental `.pipedSql`; supports `FROM ... |> WHERE/SELECT/DISTINCT/EXTEND/RENAME/DROP/HAVING/QUALIFY/ORDER BY/LIMIT/OFFSET/AS/JOIN/AGGREGATE/PIVOT/UNPIVOT/UNION/INTERSECT/EXCEPT`. Additional operators remain. |

## Next Recommended Work

1. Expand remaining Piped SQL operators for closer upstream parity.
2. Add dialect-focused conformance tests for `duckDB`, `redshift`, `db2`, `h2`, `hsqldb`, `derby`, and deeper `sqlite` behavior.
3. Add more vendor-specific DDL variants under explicit flags where needed.
