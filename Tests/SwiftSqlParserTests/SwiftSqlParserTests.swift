import Testing
@testable import SwiftSqlParser

@Test
func moduleCompiles() {
    _ = SwiftSqlParserModule.self
}

@Test
func parseStatementBuildsSelectAstForSelectQuery() throws {
    let statement = try parseStatement("SELECT * FROM users")
    #expect(statement is PlainSelect)
}

@Test
func parseStatementsRespectsSeparators() throws {
    let options = ParserOptions(scriptSeparators: [";"])
    let statements = try parseStatements("SELECT * FROM users;SELECT * FROM roles", options: options)
    #expect(statements.count == 2)
    #expect(statements.allSatisfy { $0 is PlainSelect })
}

@Test
func parseStatementFailsOnEmptyInput() {
    #expect(throws: SqlParseError.self) {
        let _ = try parseStatement("   ")
    }
}
