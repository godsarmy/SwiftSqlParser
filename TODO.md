# SwiftSqlParser Reimplementation Plan (JSqlParser in Swift)

## 0) Scope and Success Criteria

- [ ] Define v1 scope and lock a parity matrix against JSqlParser.
  - [ ] Include in v1: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `WITH`, basic DDL.
  - [ ] Defer advanced dialect-specific syntax to later milestones.
- [ ] Define success criteria:
  - [ ] Parse coverage target for selected corpus.
  - [ ] Round-trip quality target (`parse -> deparse -> parse`).
  - [ ] Error diagnostics quality target (line/column/token context).

## 1) Project Foundation (SwiftPM)

- [ ] Create `Package.swift` with targets:
  - [ ] `SwiftSqlParser` (library)
  - [ ] `SwiftSqlParserTests` (test target)
- [ ] Create source layout:
  - [ ] `Sources/SwiftSqlParser/Lexer/`
  - [ ] `Sources/SwiftSqlParser/Parser/`
  - [ ] `Sources/SwiftSqlParser/AST/`
  - [ ] `Sources/SwiftSqlParser/Visitors/`
  - [ ] `Sources/SwiftSqlParser/Deparser/`
  - [ ] `Sources/SwiftSqlParser/Diagnostics/`

## 2) Parser Technology and Grammar Strategy

- [ ] Use a grammar-driven parser approach (recommended: ANTLR4 Swift target).
- [ ] Build/port grammar in phases, staying close to JSqlParser concepts.
- [ ] Define parser configuration options for feature toggles:
  - [ ] quoting/bracket behavior
  - [ ] escaping behavior
  - [ ] statement separator/script mode behavior
  - [ ] dialect feature flags (future-safe)

## 3) Core Public API

- [ ] Implement parser entry points:
  - [ ] `parseStatement(_ sql: String, options: ParserOptions) throws -> Statement`
  - [ ] `parseStatements(_ sql: String, options: ParserOptions) throws -> [Statement]`
- [ ] Design `ParserOptions` to support future compatibility flags.
- [ ] Define stable error contract (`SqlParseError`).

## 4) AST Architecture (Mirror JSqlParser Concepts)

- [ ] Create base protocols/types:
  - [ ] `Statement`
  - [ ] `Expression`
  - [ ] `SelectItem`
  - [ ] `FromItem`
- [ ] Implement initial concrete nodes:
  - [ ] `PlainSelect`
  - [ ] literals and identifiers
  - [ ] binary/unary expressions
  - [ ] functions
  - [ ] joins
  - [ ] subqueries
- [ ] Keep AST extensible for dialect-specific nodes.

## 5) Visitors and Deparsers

- [ ] Implement visitor protocols with default implementations:
  - [ ] `StatementVisitor`
  - [ ] `ExpressionVisitor`
  - [ ] `FromItemVisitor`
  - [ ] `SelectItemVisitor`
- [ ] Implement SQL serializers:
  - [ ] `ExpressionDeparser`
  - [ ] `SelectDeparser`
  - [ ] `StatementDeparser`

## 6) Error Handling and Diagnostics

- [ ] Add detailed parse errors with line/column/token context.
- [ ] Add script parsing mode behavior (collect statement-level failures where possible).
- [ ] Normalize error messages for deterministic tests.

## 7) Test Strategy and Corpus

- [x] Create test categories:
  - [x] parser success/failure tests
  - [x] AST shape assertions for key grammar constructs
  - [x] round-trip parse/deparse tests
- [x] Add large real-world SQL corpus files for regression testing.
- [x] Build a parity test harness that maps unsupported syntax to tracked gaps.

## 8) Incremental Feature Delivery (Vertical Slices)

- [x] Milestone A: `SELECT` core (projection, `FROM`, `WHERE`, joins).
- [x] Milestone B: `WITH`/CTE + subqueries + set ops.
- [x] Milestone C: DML (`INSERT`, `UPDATE`, `DELETE`).
- [x] Milestone D: basic DDL (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`).
- [x] Milestone E: dialect extensions (`Postgres`, `MySQL`, `SQL Server`, `BigQuery`, etc.).

## 9) Performance and Robustness

- [x] Add parser benchmarks on large scripts/corpus.
- [x] Profile tokenization and AST allocation hotspots.
- [x] Optimize hot paths without breaking AST/API contracts.

## 10) Versioning and Compatibility

- [x] Define versioning policy for AST/API evolution.
- [x] Mark experimental features clearly behind flags.
- [x] Maintain compatibility notes with JSqlParser behavior differences.

## 11) Suggested Release Milestones

- [ ] `v0.1`: SwiftPM skeleton + parser API + minimal `SELECT` support.
- [ ] `v0.2`: visitor/deparser + round-trip tests + expanded `SELECT` grammar.
- [ ] `v0.3`: full DML + diagnostics polish + corpus scaling.
- [ ] `v1.0`: stable API + basic DDL + documented dialect support matrix.
