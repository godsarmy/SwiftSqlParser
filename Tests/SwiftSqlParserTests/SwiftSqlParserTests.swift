import Testing
@testable import SwiftSqlParser

@Test
func moduleCompiles() {
    _ = SwiftSqlParserModule.self
}

@Test
func parseStatementReturnsRawStatement() throws {
    let statement = try parseStatement("SELECT * FROM users")
    #expect(statement is RawStatement)
}

@Test
func parseStatementsRespectsSeparators() throws {
    let options = ParserOptions(scriptSeparators: [";"])
    let statements = try parseStatements("SELECT * FROM users;SELECT * FROM roles", options: options)
    #expect(statements.count == 2)
}

@Test
func parseStatementFailsOnEmptyInput() {
    #expect(throws: SqlParseError.self) {
        let _ = try parseStatement("   ")
    }
}
