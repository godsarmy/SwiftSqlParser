import Testing

@testable import SwiftSqlParser

private struct UtilityStatementVisitor: StatementVisitor {
  var explainCount = 0
  var showCount = 0
  var setCount = 0
  var resetCount = 0
  var useCount = 0

  mutating func visit(explainStatement: ExplainStatement) {
    explainCount += 1
  }

  mutating func visit(showStatement: ShowStatement) {
    showCount += 1
  }

  mutating func visit(setStatement: SetStatement) {
    setCount += 1
  }

  mutating func visit(resetStatement: ResetStatement) {
    resetCount += 1
  }

  mutating func visit(useStatement: UseStatement) {
    useCount += 1
  }
}

@Test
func upstreamUtilityStatementCasesParseAndDeparse() throws {
  let utilitySql = [
    "SHOW FULL TABLES",
    "SET work_mem = 64",
    "RESET search_path",
    "USE analytics",
    "EXPLAIN SELECT id FROM users",
  ]

  for sql in utilitySql {
    let parsed = try parseStatement(sql)
    #expect(StatementDeparser().deparse(parsed) == sql)
  }
}

@Test
func upstreamTableNameFinderViewCaseCollectsViewAndBaseTables() throws {
  let sql =
    "CREATE VIEW active_role_users AS SELECT u.id, r.name FROM users u INNER JOIN roles r ON u.role_id = r.id WHERE u.active = 1"
  let statement = try parseStatement(sql)

  let names = TableNameFinder().find(in: statement)
  #expect(names == ["active_role_users", "roles", "users"])
}

@Test
func upstreamUtilityVisitorDispatchesAcrossMixedBatch() throws {
  let statements = try parseStatements(
    "SHOW TABLES;SET search_path = public;RESET work_mem;USE analytics;EXPLAIN SELECT * FROM users"
  )

  var visitor = UtilityStatementVisitor()
  for statement in statements {
    AstVisit.statement(statement, visitor: &visitor)
  }

  #expect(visitor.showCount == 1)
  #expect(visitor.setCount == 1)
  #expect(visitor.resetCount == 1)
  #expect(visitor.useCount == 1)
  #expect(visitor.explainCount == 1)
}
