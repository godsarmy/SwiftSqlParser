import Testing

@testable import SwiftSqlParser

@Test
func emptyInputErrorContainsLocationAndNormalizedMessage() {
  do {
    _ = try parseStatement("\n  ")
    Issue.record("Expected parseStatement to throw")
  } catch let error as SqlParseError {
    #expect(error.diagnostic.code == .emptyInput)
    #expect(error.diagnostic.location.line == 1)
    #expect(error.normalizedMessage == "empty_input:input sql is empty")
  } catch {
    Issue.record("Unexpected error type")
  }
}

@Test
func parseScriptCollectsStatementLevelFailures() {
  let result = parseScript("SELECT * FROM a;;SELECT * FROM b")

  #expect(result.statements.count == 1)
  #expect(result.diagnostics.count == 1)
  #expect(result.diagnostics.allSatisfy { $0.code == .emptyStatement })
  #expect(
    result.diagnostics.allSatisfy {
      $0.normalizedMessage == "empty_statement:script statement is empty"
    })
}

@Test
func parseScriptContinuesAfterErrorsWhenRecoveryEnabled() {
  let result = parseScript(
    "SELECT * FROM a;;SELECT * FROM b",
    options: ParserOptions(recoverParseErrors: true)
  )

  #expect(result.statements.count == 2)
  #expect(result.diagnostics.count == 1)
}

@Test
func parseScriptIgnoresSeparatorsInsideQuotedStrings() {
  let result = parseScript("SELECT 'a;GO;/' FROM a;SELECT * FROM b")
  #expect(result.statements.count == 2)
  #expect(result.diagnostics.isEmpty)
}

@Test
func parseScriptTreatsGoAndSlashAsDelimiterLinesOnly() {
  let result = parseScript("SELECT 'GO' FROM a\nGO\nSELECT '/' FROM b\n/\nSELECT * FROM c")
  #expect(result.statements.count == 3)
  #expect(result.diagnostics.isEmpty)
}

@Test
func parseScriptRecoversUnsupportedStatementsWhenEnabled() {
  let options = ParserOptions(recoverUnsupportedStatements: true)
  let result = parseScript("SELECT * FROM a;MATCH_RECOGNIZE (foo);SHOW TABLES", options: options)

  #expect(result.statements.count == 3)
  #expect(result.statements[1] is UnsupportedStatement)
  #expect(result.diagnostics.isEmpty)
}

@Test
func parseStatementsResultRecoversUnsupportedStatementsWithoutDiagnostics() throws {
  let result = try SqlParser().parseStatementsResult(
    "SELECT * FROM a;MATCH_RECOGNIZE (foo);SHOW TABLES",
    options: ParserOptions(recoverParseErrors: true, recoverUnsupportedStatements: true)
  )

  #expect(result.slots.count == 3)
  #expect(result.slots[1].statement is UnsupportedStatement)
  #expect(result.slots[1].diagnostic == nil)
  #expect(result.diagnostics.isEmpty)
}
