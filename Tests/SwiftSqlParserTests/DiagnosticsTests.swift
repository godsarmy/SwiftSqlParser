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
    let result = parseScript("SELECT 1;;SELECT 2;")

    #expect(result.statements.count == 2)
    #expect(result.diagnostics.count == 2)
    #expect(result.diagnostics.allSatisfy { $0.code == .emptyStatement })
    #expect(result.diagnostics.allSatisfy { $0.normalizedMessage == "empty_statement:script statement is empty" })
}
