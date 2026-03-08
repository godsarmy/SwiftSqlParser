# Versioning and Compatibility

## Versioning Policy

SwiftSqlParser follows semantic versioning:

- `MAJOR`: breaking API/AST/behavior changes
- `MINOR`: backward-compatible feature additions
- `PATCH`: bug fixes and non-breaking performance/internal updates

## API Stability Rules

- public parser entry points remain stable across minor releases:
  - `parseStatement`
  - `parseStatements`
  - `parseScript`
- existing AST node types are additive-first; removals/renames require major release
- diagnostic `normalizedMessage` values are treated as test-stable contracts

## Experimental Features

Experimental behavior must be explicitly enabled through `ParserOptions.experimentalFeatures`.

Current experimental flags:

- `.postgresIlike`
- `.quotedIdentifiers`

Dialects are still selected through `ParserOptions.dialectFeatures`, but experimental syntax is parsed only when both the dialect and corresponding experimental flag are enabled.

## Compatibility Notes vs JSqlParser

- current implementation is intentionally subset-oriented and prioritizes deterministic AST/deparse behavior
- unsupported syntax is surfaced through normalized diagnostics (`unsupported_syntax:*`) for parity tracking
- parser behavior is configuration-driven and may differ from JSqlParser defaults unless options are aligned

## Planned Compatibility Workflow

1. track syntax parity gaps via normalized diagnostics and corpus tests
2. implement support in additive slices (AST + parser + deparser + tests)
3. move syntax from experimental to stable only after corpus coverage and round-trip confidence targets are met
