import Foundation
import Testing

@testable import SwiftSqlParser

private enum CorpusHarness {
  static func content(from resourceName: String) throws -> String {
    guard let url = Bundle.module.url(forResource: resourceName, withExtension: "sql") else {
      throw NSError(domain: "CorpusHarness", code: 1)
    }

    return try String(contentsOf: url, encoding: .utf8)
  }

  static func statements(from resourceName: String) throws -> [String] {
    let content = try content(from: resourceName)
    return
      content
      .split(separator: "\n")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
      .map { $0.hasSuffix(";") ? String($0.dropLast()) : $0 }
  }
}

private func expectParsedType(for statement: String) throws {
  let parsed = try parseStatement(statement)
  let upper = statement.uppercased()

  if upper.hasPrefix("SELECT ") {
    #expect(parsed is PlainSelect)
  } else if upper.hasPrefix("WITH ") {
    #expect(parsed is WithSelect)
  } else if upper.hasPrefix("VALUES ") {
    #expect(parsed is ValuesSelect)
  } else if upper.hasPrefix("INSERT ") {
    #expect(parsed is InsertStatement)
  } else if upper.hasPrefix("UPDATE ") {
    #expect(parsed is UpdateStatement)
  } else if upper.hasPrefix("DELETE ") {
    #expect(parsed is DeleteStatement)
  } else if upper.hasPrefix("CREATE TABLE ") {
    #expect(parsed is CreateTableStatement)
  } else if upper.hasPrefix("CREATE UNIQUE INDEX ") || upper.hasPrefix("CREATE INDEX ") {
    #expect(parsed is CreateIndexStatement)
  } else if upper.hasPrefix("CREATE VIEW ") {
    #expect(parsed is CreateViewStatement)
  } else if upper.hasPrefix("ALTER TABLE ") {
    #expect(parsed is AlterTableStatement)
  } else if upper.hasPrefix("DROP TABLE ") {
    #expect(parsed is DropTableStatement)
  } else if upper.hasPrefix("TRUNCATE ") {
    #expect(parsed is TruncateTableStatement)
  } else if upper.hasPrefix("SHOW ") {
    #expect(parsed is ShowStatement)
  } else if upper.hasPrefix("SET ") {
    #expect(parsed is SetStatement)
  } else if upper.hasPrefix("RESET ") {
    #expect(parsed is ResetStatement)
  } else if upper.hasPrefix("USE ") {
    #expect(parsed is UseStatement)
  } else if upper.hasPrefix("EXPLAIN ") {
    #expect(parsed is ExplainStatement)
  } else {
    #expect(parsed is RawStatement)
  }
}

private struct TrackedParityGap: Sendable, Hashable {
  let id: String
  let token: String
}

@Test
func corpusSuccessStatementsParse() throws {
  let statements = try CorpusHarness.statements(from: "success")
  #expect(statements.isEmpty == false)

  for statement in statements {
    try expectParsedType(for: statement)
  }
}

@Test
func corpusUnsupportedStatementsMapToTrackedGaps() throws {
  let statements = try CorpusHarness.statements(from: "unsupported")
  #expect(statements.count == 5)

  let trackedGaps: Set<TrackedParityGap> = [
    .init(id: "merge_statement", token: "MERGE"),
    .init(id: "pivot_clause", token: "PIVOT"),
    .init(id: "unpivot_clause", token: "UNPIVOT"),
    .init(id: "match_recognize", token: "MATCH_RECOGNIZE"),
  ]

  for statement in statements {
    do {
      let parsed = try parseStatement(statement)
      if statement.uppercased().contains("QUALIFY") {
        #expect(parsed is PlainSelect)
      } else {
        Issue.record("Expected unsupported syntax: \(statement)")
      }
    } catch let error as SqlParseError {
      #expect(error.diagnostic.code == .unsupportedSyntax)
      let normalized = error.normalizedMessage.replacingOccurrences(
        of: "unsupported_syntax:", with: "")
      let token = error.diagnostic.token ?? ""
      #expect(trackedGaps.contains(.init(id: normalized, token: token)))
    }
  }
}

@Test
func corpusRoundTripMaintainsTextForRawStatements() throws {
  let statements = try CorpusHarness.statements(from: "success")
  let deparser = StatementDeparser()

  for statement in statements {
    let parsed = try parseStatement(statement)
    let deparsed = deparser.deparse(parsed)
    #expect(deparsed == statement)
  }
}

@Test
func corpusDdlStatementsParseAndRoundTrip() throws {
  let statements = try CorpusHarness.statements(from: "ddl")
  #expect(statements.count == 6)

  let deparser = StatementDeparser()
  for statement in statements {
    try expectParsedType(for: statement)
    let parsed = try parseStatement(statement)
    #expect(deparser.deparse(parsed) == statement)
  }
}

@Test
func corpusUtilityStatementsParseAndRoundTrip() throws {
  let statements = try CorpusHarness.statements(from: "utility")
  #expect(statements.count == 5)

  let deparser = StatementDeparser()
  for statement in statements {
    try expectParsedType(for: statement)
    let parsed = try parseStatement(statement)
    #expect(deparser.deparse(parsed) == statement)
  }
}

@Test
func corpusScriptExercisesBatchParsingAndRecovery() throws {
  let script = try CorpusHarness.content(from: "script")
  let statements = try parseStatements(script)
  #expect(statements.count == 4)
  #expect(statements[0] is CreateTableStatement)
  #expect(statements[1] is InsertStatement)
  #expect(statements[2] is ExplainStatement)
  #expect(statements[3] is AlterTableStatement)

  let result = parseScript(script)
  #expect(result.slots.count == 4)
  #expect(result.slots.allSatisfy { $0.statement != nil })
  #expect(result.diagnostics.isEmpty)
}
