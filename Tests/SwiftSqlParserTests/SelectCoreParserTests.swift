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
    let sql = "SELECT u.id FROM users u NATURAL LEFT JOIN roles r USING (role_id)"
    let parsed = try parseStatement(sql)
    guard let select = parsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }

    #expect(select.joins.count == 1)
    #expect(select.joins.first?.type == .left)
    #expect(select.joins.first?.isNatural == true)
    #expect(select.joins.first?.usingColumns == ["role_id"])
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

@Test
func selectParserBuildsDistinctGroupingOrderingAndPagination() throws {
    let sql = "SELECT DISTINCT department_id, count(id) OVER (PARTITION BY department_id ORDER BY created_at DESC) FROM users WHERE active = 1 GROUP BY department_id HAVING count(id) = 2 QUALIFY count(id) OVER (PARTITION BY department_id) > 1 ORDER BY department_id DESC, count(id) ASC LIMIT 10 OFFSET 20"
    let parsed = try parseStatement(sql)

    guard let select = parsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }

    #expect(select.isDistinct)
    #expect(select.groupByExpressions.count == 1)
    #expect(select.havingExpression != nil)
    #expect(select.qualifyExpression != nil)
    #expect(select.orderBy.count == 2)
    #expect(select.orderBy.first?.direction == .descending)
    #expect(select.orderBy.last?.direction == .ascending)
    #expect(select.limit == 10)
    #expect(select.offset == 20)
}

@Test
func valuesAndApplyQueriesParse() throws {
    let valuesParsed = try parseStatement("VALUES (1, 'a'), (2, 'b')")
    guard let values = valuesParsed as? ValuesSelect else {
        Issue.record("Expected ValuesSelect")
        return
    }
    #expect(values.rows.count == 2)

    let applyParsed = try parseStatement("SELECT u.id FROM users u CROSS APPLY LATERAL (SELECT id FROM roles) r")
    guard let apply = applyParsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }
    #expect(apply.joins.first?.type == .crossApply)
}

@Test
func selectParserBuildsAdvancedExpressionNodes() throws {
    let sql = "SELECT CASE WHEN age >= 18 THEN 'adult' ELSE 'minor' END AS bucket, CAST(score AS INTEGER) AS cast_score, name::TEXT AS text_name FROM users WHERE deleted_at IS NULL AND id IN (1, 2, 3) AND score BETWEEN 10 AND 20 AND email LIKE ? AND EXISTS (SELECT id FROM roles WHERE roles.user_id = users.id)"
    let parsed = try parseStatement(sql)

    guard let select = parsed as? PlainSelect else {
        Issue.record("Expected PlainSelect")
        return
    }

    #expect(select.selectItems.count == 3)
    #expect(select.whereExpression != nil)

    let expressionItems = select.selectItems.compactMap { $0 as? ExpressionSelectItem }
    #expect(expressionItems.count == 3)
    #expect(expressionItems[0].expression is CaseExpression)
    #expect(expressionItems[1].expression is CastExpression)
    #expect(expressionItems[2].expression is CastExpression)
}
