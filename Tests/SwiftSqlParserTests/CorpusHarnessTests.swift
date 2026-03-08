import Foundation
import Testing

@testable import SwiftSqlParser

private enum CorpusHarness {
  static func statements(from resourceName: String) throws -> [String] {
    guard let url = Bundle.module.url(forResource: resourceName, withExtension: "sql") else {
      throw NSError(domain: "CorpusHarness", code: 1)
    }

    let content = try String(contentsOf: url, encoding: .utf8)
    return
      content
      .split(separator: "\n")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
      .map { $0.hasSuffix(";") ? String($0.dropLast()) : $0 }
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
    let parsed = try parseStatement(statement)

    let upper = statement.uppercased()
    if upper.hasPrefix("SELECT ") {
      #expect(parsed is PlainSelect)
    } else if upper.hasPrefix("WITH ") {
      #expect(parsed is WithSelect)
    } else if upper.hasPrefix("INSERT ") {
      #expect(parsed is InsertStatement)
    } else if upper.hasPrefix("UPDATE ") {
      #expect(parsed is UpdateStatement)
    } else if upper.hasPrefix("DELETE ") {
      #expect(parsed is DeleteStatement)
    } else if upper.hasPrefix("CREATE ") {
      #expect(parsed is CreateTableStatement)
    } else {
      #expect(parsed is RawStatement)
    }
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
