# Performance and Robustness

## Benchmarks

Run local parser benchmarks:

```bash
swift run SwiftSqlParserBenchmark
```

The benchmark executable measures:

- parse throughput for per-statement parsing (`parseStatement` loop)
- batch script parsing via `parseStatements`
- script parsing with diagnostics via `parseScript`

Benchmark source: `Sources/SwiftSqlParserBenchmark/main.swift`.

## Hotspots Profiled

Observed hotspot classes during parser work:

- tokenizer character scanning and token emission
- expression parsing recursion in `WHERE`/assignment clauses
- script splitting and chunk allocation for large SQL scripts

## Optimizations Applied

- replaced component-based script splitting with a linear range-scanning splitter in `SqlParser` to reduce intermediate allocations on large scripts
- kept parser option dispatch at top-level to avoid unnecessary parser construction for mismatched statement families
- retained stable AST contracts and public API behavior while changing internals

## Robustness Notes

- parser continues to emit deterministic normalized diagnostic messages
- script mode still collects statement-level diagnostics without aborting the whole script parse
- unsupported syntax remains mapped to explicit diagnostic categories for parity tracking
