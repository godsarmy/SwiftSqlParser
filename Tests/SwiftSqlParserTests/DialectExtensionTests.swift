import Testing
@testable import SwiftSqlParser

@Test
func sqlServerSquareBracketIdentifiersParseWhenEnabled() throws {
    let options = ParserOptions(identifierQuoting: .squareBrackets, dialectFeatures: [.sqlServer])
    let parsed = try parseStatement("SELECT [u].[id] FROM [dbo].[users] [u]", options: options)

    guard let select = parsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }

    #expect(select.selectItems.count == 1)
    #expect(StatementDeparser().deparse(select) == "SELECT u.id FROM dbo.users u")
}

@Test
func mysqlBacktickIdentifiersParseWhenEnabled() throws {
    let options = ParserOptions(dialectFeatures: [.mysql])
    let parsed = try parseStatement("SELECT `id` FROM `users`", options: options)

    guard let select = parsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }

    #expect(select.selectItems.count == 1)
    #expect(StatementDeparser().deparse(select) == "SELECT id FROM users")
}

@Test
func postgresIlikeParsesWhenFeatureEnabled() throws {
    let options = ParserOptions(dialectFeatures: [.postgres])
    let parsed = try parseStatement("SELECT id FROM users WHERE name ILIKE 'a%'", options: options)

    guard let select = parsed as? PlainSelect,
          let whereExpression = select.whereExpression as? BinaryExpression else {
        Issue.record("Expected where binary expression")
        return
    }

    #expect(whereExpression.operator == .ilike)
    #expect(StatementDeparser().deparse(select) == "SELECT id FROM users WHERE name ILIKE 'a%'")
}

@Test
func postgresIlikeWithoutFeatureReturnsUnsupported() {
    #expect(throws: SqlParseError.self) {
        _ = try parseStatement("SELECT id FROM users WHERE name ILIKE 'a%'")
    }
}
