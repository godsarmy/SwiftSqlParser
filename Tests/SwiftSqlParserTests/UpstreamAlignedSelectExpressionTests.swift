import Testing

@testable import SwiftSqlParser

@Test
func upstreamSelectAstStyleOrderByCaseParsesAndDeparses() throws {
  let sql = "SELECT a, b FROM mytable ORDER BY b, c"
  let parsed = try parseStatement(sql)

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 2)
  #expect(select.orderBy.count == 2)
  #expect(StatementDeparser().deparse(select) == sql)
}

@Test
func upstreamAllColumnsStyleSelectParsesAndDeparses() throws {
  let sql = "SELECT * FROM users ORDER BY id"
  let parsed = try parseStatement(sql)

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 1)
  #expect(select.selectItems[0] is AllColumnsSelectItem)
  #expect(StatementDeparser().deparse(select) == sql)
}

@Test
func upstreamWindowFunctionStyleQueryParsesAndDeparses() throws {
  let sql =
    "SELECT count(id) OVER (PARTITION BY department_id ORDER BY created_at DESC) FROM users"
  let parsed = try parseStatement(sql)

  guard let select = parsed as? PlainSelect,
    let item = select.selectItems.first as? ExpressionSelectItem,
    let function = item.expression as? FunctionExpression
  else {
    Issue.record("Expected window function select item")
    return
  }

  #expect(function.overClause != nil)
  #expect(StatementDeparser().deparse(select) == sql)
}

@Test
func upstreamCaseExpressionStyleNestedCaseParsesAndDeparses() throws {
  let sql =
    "SELECT CASE WHEN 1 = 1 THEN CASE WHEN 2 = 2 THEN '2a' ELSE '2b' END ELSE 'b' END FROM test_table"
  let parsed = try parseStatement(sql)

  guard let select = parsed as? PlainSelect,
    let item = select.selectItems.first as? ExpressionSelectItem
  else {
    Issue.record("Expected expression select item")
    return
  }

  #expect(item.expression is CaseExpression)
  #expect(StatementDeparser().deparse(select) == sql)
}

@Test
func upstreamCaseExpressionStyleBracketedCaseParsesAndDeparses() throws {
  let sql =
    "SELECT (CASE WHEN score >= 10 THEN 1 ELSE 0 END) + 1 FROM test"
  let normalized =
    "SELECT CASE WHEN score >= 10 THEN 1 ELSE 0 END + 1 FROM test"
  let parsed = try parseStatement(sql)

  guard let select = parsed as? PlainSelect,
    let item = select.selectItems.first as? ExpressionSelectItem
  else {
    Issue.record("Expected expression select item")
    return
  }

  #expect(item.expression is BinaryExpression)
  #expect(StatementDeparser().deparse(select) == normalized)
}

@Test
func upstreamFunctionStyleCountStarParsesAndDeparses() throws {
  let sql = "SELECT count(*) FROM zzz"
  let parsed = try parseStatement(sql)

  guard let select = parsed as? PlainSelect,
    let item = select.selectItems.first as? ExpressionSelectItem,
    let function = item.expression as? FunctionExpression
  else {
    Issue.record("Expected function select item")
    return
  }

  #expect(function.name == "count")
  #expect(function.arguments.count == 1)
  #expect(StatementDeparser().deparse(select) == sql)
}
