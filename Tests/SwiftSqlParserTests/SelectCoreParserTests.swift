import Testing
@testable import SwiftSqlParser

@Test
func selectParserBuildsWhereExpression() throws {
    let parsed = try parseStatement("SELECT id, name FROM users WHERE active = 1")
    guard let select = parsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }

    #expect(select.selectItems.count == 2)
    #expect(select.whereExpression != nil)
}

@Test
func selectParserBuildsJoinNodes() throws {
    let sql = "SELECT u.id FROM users u INNER JOIN roles r ON u.id = r.user_id"
    let parsed = try parseStatement(sql)
    guard let select = parsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }

    #expect(select.joins.count == 1)
    #expect(select.joins.first?.type == .inner)
}

@Test
func nonSelectStatementsRemainRawUntilDmlDdlSlices() throws {
    let parsed = try parseStatement("INSERT INTO users (id) VALUES (1)")
    #expect(parsed is RawStatement)
}
