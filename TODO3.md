# JSqlParser Usage Alignment Plan

This file tracks the remaining gaps identified from the JSqlParser usage docs, especially around statement-list parsing, recovery behavior, and parser utility APIs.

## Goal

Align `SwiftSqlParser` more closely with the behaviors described in:

- `https://jsqlparser.github.io/JSqlParser/usage.html#parse-a-sql-statements`

## Remaining Gaps

### 1. Recoverable batch parsing API

- `parseStatements(...)` still throws on parse failures or empty chunks
- JSqlParser supports continuing across statement lists while preserving statement slots
- `parseScript(...)` is closer, but it is not the same API shape as recoverable batch parsing

### 2. Separate recovery modes

- JSqlParser distinguishes:
  - parse error recovery
  - unsupported-statement recovery
- `SwiftSqlParser` currently only exposes `recoverUnsupportedStatements`
- current behavior mixes recovery and diagnostics in a way that does not fully match JSqlParser

### 3. Unsupported-statement semantics

- JSqlParser returns `UnsupportedStatement` without recording parse errors in unsupported mode
- `SwiftSqlParser` currently still preserves diagnostics for recovered unsupported statements in script mode
- this is a behavior mismatch

### 4. Default script separators

- JSqlParser usage docs call out:
  - `;`
  - `GO`
  - `/`
  - two empty lines
- `SwiftSqlParser` currently defaults to `;`
- separators are configurable, but default parity is missing

### 5. Separator semantics for script mode

- `GO` and `/` should behave like statement separators in script context
- they should be treated structurally, typically as delimiter lines, not arbitrary substrings
- blank-line separators should also be handled structurally

### 6. Parse error collection API

- JSqlParser exposes parse errors separately
- `SwiftSqlParser` only exposes diagnostics through `parseScript(...)`
- `parseStatement(...)` and `parseStatements(...)` do not have a non-throwing parse-result API

### 7. Expression-level table-name finder

- JSqlParser usage docs show table-name finding from both statements and expressions
- `SwiftSqlParser` now has statement-level `TableNameFinder`
- expression-level entry points are still missing

## Implementation Plan

### Milestone A: Recoverable statements result API

- [x] Add a recoverable batch API such as `parseStatementsResult(...)`
- [x] Return both statements and diagnostics in a structured result
- [x] Preserve statement positions so failed statements do not collapse indexing
- [x] Reuse this shared engine from both `parseStatements(...)` and `parseScript(...)`

### Milestone B: Distinguish recovery behaviors

- [x] Add a parser option for parse-error recovery separate from unsupported-statement recovery
- [x] Keep `recoverUnsupportedStatements` for unsupported syntax mapping
- [x] Add a second option for JSqlParser-style error recovery across batches/scripts
- [x] Document the behavior difference clearly

### Milestone C: Align unsupported-statement semantics

- [x] When unsupported recovery is enabled, return `UnsupportedStatement` without emitting a parse error diagnostic for that statement
- [x] Keep diagnostics for true parse failures when parse-error recovery is enabled
- [x] Add tests proving the difference between the two recovery modes

### Milestone D: Expand separator parity

- [x] Extend default script separators to include `;`, `GO`, `/`, and blank-line delimiters
- [x] Keep the behavior configurable through `ParserOptions`
- [x] Document how separator matching works

### Milestone E: Make script splitting line-aware

- [x] Update `splitScriptChunks` to treat `GO` as a standalone delimiter line
- [x] Update `splitScriptChunks` to treat `/` as a standalone delimiter line where appropriate
- [x] Support blank-line delimiters structurally rather than as naive substring matches
- [x] Preserve quote-awareness and parenthesis-awareness
- [x] Preserve accurate source locations for diagnostics

### Milestone F: Add parse-result diagnostics API

- [ ] Expose a reusable parse-result type for statements lists
- [ ] Ensure callers can inspect diagnostics without relying on exceptions
- [ ] Keep `parseStatement(...)` throwing for convenience, but add a non-throwing alternative if useful

### Milestone G: Add expression-level table-name finding

- [ ] Add `TableNameFinder.find(in expression: any Expression) -> [String]`
- [ ] Reuse the existing expression traversal logic
- [ ] Add tests for joins/subqueries inside expressions such as `EXISTS (...)`

## Suggested Order

1. Recoverable statements result API
2. Separate parse-error recovery from unsupported-statement recovery
3. Align unsupported-statement semantics
4. Expand default separators and make splitting line-aware
5. Add diagnostics/result APIs
6. Add expression-level table-name finder

## Files Likely To Change

- `Sources/SwiftSqlParser/Parser/ParserOptions.swift`
- `Sources/SwiftSqlParser/Parser/SqlParserAPI.swift`
- `Sources/SwiftSqlParser/Visitors/TableNameFinder.swift`
- `Sources/SwiftSqlParser/Diagnostics/SqlDiagnostics.swift`
- `Tests/SwiftSqlParserTests/DiagnosticsTests.swift`
- `Tests/SwiftSqlParserTests/SwiftSqlParserTests.swift`
- `Tests/SwiftSqlParserTests/VisitorAndDeparserTests.swift`
- `Docs/SupportMatrix.md`
- `README.md`

## Acceptance Checklist

- [ ] Recoverable statement-list parsing exists and is tested
- [ ] Unsupported recovery and parse-error recovery are distinct and documented
- [ ] Default separator behavior is closer to JSqlParser usage docs
- [ ] `GO`, `/`, and blank-line handling are verified with tests
- [ ] Table-name finding works for both statements and expressions
- [ ] Public docs reflect the final behavior accurately
