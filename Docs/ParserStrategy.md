# Parser Technology and Grammar Strategy

## Backend

- Primary parser backend: ANTLR4 with Swift runtime.
- Grammar source of truth starts in `Grammar/JSqlParserSubset.g4`.

## Phased Grammar Delivery

1. `select-core`: projection, `FROM`, `WHERE`, simple joins.
2. `with-and-subqueries`: CTEs, nested queries, set operations.
3. `dml`: `INSERT`, `UPDATE`, `DELETE`.
4. `ddl`: `CREATE`, `ALTER`, `DROP`, `TRUNCATE` basics.
5. `dialect-extensions`: optional syntax by dialect feature flags.

## Feature Toggle Policy

- Parser behavior must be controlled by explicit options.
- Initial options include:
  - bracket/identifier quoting behavior
  - escape behavior
  - script separator behavior
  - dialect feature flags

This policy keeps parser behavior deterministic and compatible with future
JSqlParser parity goals.
