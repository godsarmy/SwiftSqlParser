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
func dmlStatementsNowParseIntoDedicatedAstNodes() throws {
    let parsed = try parseStatement("INSERT INTO users (id) VALUES (1)")
    #expect(parsed is InsertStatement)
}

@Test
func withClauseParsesIntoWithSelect() throws {
    let sql = "WITH active_users AS (SELECT id FROM users) SELECT id FROM active_users"
    let parsed = try parseStatement(sql)

    guard let withSelect = parsed as? WithSelect else {
        Issue.record("Expected WithSelect")
        return
    }

    #expect(withSelect.expressions.count == 1)
    #expect(withSelect.body is PlainSelect)
}

@Test
func unionAllParsesIntoSetOperationSelect() throws {
    let parsed = try parseStatement("SELECT id FROM users UNION ALL SELECT id FROM roles")

    guard let setOperation = parsed as? SetOperationSelect else {
        Issue.record("Expected SetOperationSelect")
        return
    }

    #expect(setOperation.operation == .union)
    #expect(setOperation.isAll)
}
