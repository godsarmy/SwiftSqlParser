# Release Plan

## v0.1 (Completed)

- SwiftPM package and targets in place
- public parser API available (`parseStatement`, `parseStatements`, `parseScript`)
- minimal `SELECT` support implemented

## v0.2 (Completed)

- visitor protocols and adapters implemented
- deparsers for expressions/statements implemented
- round-trip tests and corpus harness established

## v0.3 (Completed)

- DML support implemented (`INSERT`, `UPDATE`, `DELETE`)
- diagnostics include normalized message contracts and script-level reporting
- corpus-based regression and unsupported-syntax parity tests scaled

## v1.0 (In Progress)

Remaining work before v1.0 stabilization:

- finalize documented support matrix and parity deltas vs JSqlParser
- freeze AST/API stability guarantees for first stable release
- complete release notes and migration guidance for experimental flags
