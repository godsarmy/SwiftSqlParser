# JSqlParser Test Port Plan

This file tracks how to port the upstream JSqlParser test suite from `src/test` into `SwiftSqlParser` in a staged way.

Goal:

- reuse as much upstream SQL coverage as possible
- avoid blindly importing tests for unsupported features
- make parity progress measurable by upstream test family

## Status Legend

- `ported` - upstream family is represented here with meaningful adapted coverage
- `partial` - some comparable coverage exists, but upstream breadth is not matched
- `blocked` - upstream family depends on features not implemented locally yet
- `skip` - Java-specific or non-applicable to the Swift project architecture

## Upstream Family Matrix

### Parser / harness / feature toggles

| Upstream Area | Local Status | Notes |
|---|---|---|
| parser entry APIs | `ported` | `parseStatement`, `parseStatementResult`, `parseStatements`, `parseStatementsResult`, `parseScript` are covered locally |
| parser recovery / unsupported statements | `ported` | local tests now cover parse-error recovery and unsupported recovery semantics |
| parser feature toggles | `partial` | dialect/experimental gating exists, but upstream breadth is larger |
| parser listener/internal Java hooks | `skip` | Java-implementation-specific |

### Expressions

| Upstream Area | Local Status | Notes |
|---|---|---|
| core boolean/arithmetic/comparison expressions | `ported` | local expression coverage exists |
| `CASE`, `CAST`, `IN`, `BETWEEN`, `EXISTS`, null predicates | `ported` | locally covered |
| window/analytic expressions | `partial` | practical coverage exists, but upstream permutations are much broader |
| JSON / XML / vendor expression features | `blocked` | not broadly implemented |
| interval/date/time edge cases | `blocked` | upstream has much denser coverage |
| operator permutation matrix | `partial` | local precedence coverage exists, but not upstream-scale |

### Schema helpers

| Upstream Area | Local Status | Notes |
|---|---|---|
| table/column helper classes | `partial` | local AST tests exist, but not upstream helper breadth |
| database/server/schema metadata helpers | `blocked` | little or no local equivalent |

### SELECT / query statements

| Upstream Area | Local Status | Notes |
|---|---|---|
| plain `SELECT`, joins, CTEs, set ops | `ported` | covered locally |
| `VALUES`, `QUALIFY`, lateral/apply, pivot/unpivot | `ported` | locally implemented and tested |
| advanced select permutations and dialect variants | `partial` | many upstream cases remain unported |
| piped/select pipeline syntax | `blocked` | not implemented locally |

### DML statements

| Upstream Area | Local Status | Notes |
|---|---|---|
| `INSERT`, `UPDATE`, `DELETE` | `ported` | practical coverage exists |
| `MERGE`, `REPLACE`, upsert variants | `partial` | local support exists for some dialect-gated forms |
| advanced vendor DML matrices | `blocked` | upstream breadth still exceeds local implementation |

### DDL statements

| Upstream Area | Local Status | Notes |
|---|---|---|
| `CREATE TABLE`, `ALTER TABLE`, `DROP`, `TRUNCATE` | `ported` | locally covered |
| `CREATE INDEX`, `CREATE VIEW` | `ported` | locally covered |
| analyze/execute/grant/import/lock/show/describe/session control | `blocked` | mostly not implemented |
| sequences/materialized views/procedures/functions | `blocked` | not implemented |

### Utilities / visitors / deparsers

| Upstream Area | Local Status | Notes |
|---|---|---|
| statement/expression deparsing | `partial` | solid local coverage, but fewer constructs than upstream |
| table-name finding | `ported` | now supported for statements and expressions |
| validation / metadata / CNF helpers | `blocked` | no equivalent local subsystem yet |

### Resource corpora

| Upstream Area | Local Status | Notes |
|---|---|---|
| success corpus | `partial` | local corpus exists, but much smaller |
| unsupported corpus | `ported` | tracked with explicit diagnostics |
| large Oracle/vendor script resources | `blocked` | not yet imported or supported |

## Porting Rules

1. Do not mass-copy upstream tests blindly.
2. Port only families that are `ported` or near-`partial` first.
3. Preserve upstream SQL text where possible.
4. Adapt assertions to Swift AST/deparser shape rather than forcing Java object-model parity.
5. When an upstream case is unsupported, either:
   - add implementation first, or
   - classify it as blocked and keep it out of the active port set.
6. Keep imported tests grouped by upstream family in local test files or resource folders.

## Milestones

### Milestone 1: Inventory and mapping

- [x] Create an upstream-family parity matrix
- [x] Classify families as `ported`, `partial`, `blocked`, or `skip`
- [x] Define porting rules and order

### Milestone 2: Core query and expression ports

- [x] Port upstream-aligned tests for currently supported `SELECT` families
- [x] Port more expression/operator cases that map to local grammar
- [x] Fill any small missing parser/deparser gaps needed for those cases

### Milestone 3: DML port wave

- [x] Port upstream-aligned `INSERT` / `UPDATE` / `DELETE` / `MERGE` / `REPLACE` cases
- [x] Separate dialect-gated cases cleanly in local tests
- [x] Add regression fixtures for high-value DML variants

### Milestone 4: DDL port wave

- [x] Port upstream-aligned `CREATE` / `ALTER` / `DROP` / `TRUNCATE` cases
- [x] Expand local DDL assertions where upstream cases expose gaps

### Milestone 5: Utility / deparser / finder wave

- [x] Port utility statement cases that map to local behavior
- [x] Expand deparser round-trip coverage
- [x] Expand `TableNameFinder` coverage using upstream-style cases

### Milestone 6: Corpus expansion

- [x] Import curated upstream SQL resources for supported syntax only
- [x] Keep unsupported/dialect-specific cases separated and explicitly tracked
- [x] Use corpus files for recovery and batch parsing stress tests

## Recommended Order

1. Milestone 2
2. Milestone 3
3. Milestone 4
4. Milestone 5
5. Milestone 6

## Acceptance Criteria

- [x] Upstream test families are inventoried in-repo
- [x] Each family is classified by parity status
- [x] A first wave of upstream-aligned tests is ported and passing
- [x] Blocked upstream families are clearly separated from active port work
