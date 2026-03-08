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
func parseStatementsIgnoresSeparatorsInsideStrings() throws {
  let options = ParserOptions(scriptSeparators: [";"])
  let statements = try parseStatements(
    "SELECT 'a;b' FROM users;SELECT * FROM roles", options: options)
  #expect(statements.count == 2)
}

@Test
func utilityStatementsParseIntoDedicatedAstNodes() throws {
  #expect(try parseStatement("SHOW TABLES") is ShowStatement)
  #expect(try parseStatement("RESET work_mem") is ResetStatement)
  #expect(try parseStatement("USE analytics") is UseStatement)
  #expect(try parseStatement("EXPLAIN SELECT * FROM users") is ExplainStatement)

  let set = try parseStatement("SET search_path = public")
  #expect(set is SetStatement)
}

@Test
func parseStatementFailsOnEmptyInput() {
  #expect(throws: SqlParseError.self) {
    let _ = try parseStatement("   ")
  }
}
