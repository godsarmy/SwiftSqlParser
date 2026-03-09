import Testing

@testable import SwiftSqlParser

@Test
func upstreamInsertRegularValuesCaseParsesAndDeparses() throws {
  let sql = "INSERT INTO mytable (col1, col2, col3) VALUES (?, 'sadfsd', 234)"
  let parsed = try parseStatement(sql)

  guard let insert = parsed as? InsertStatement else {
    Issue.record("Expected InsertStatement")
    return
  }

  #expect(insert.table == "mytable")
  #expect(insert.columns == ["col1", "col2", "col3"])
  guard case .values(let rows) = insert.source else {
    Issue.record("Expected values source")
    return
  }
  #expect(rows.count == 1)
  #expect(StatementDeparser().deparse(insert) == sql)
}

@Test
func upstreamInsertSelectAndReturningCasesParseAndDeparse() throws {
  let sql = "INSERT INTO mytable (mycolumn) SELECT mycolumn FROM mytable RETURNING id"
  let parsed = try parseStatement(sql)

  guard let insert = parsed as? InsertStatement else {
    Issue.record("Expected InsertStatement")
    return
  }

  guard case .select = insert.source else {
    Issue.record("Expected select source")
    return
  }
  #expect(insert.returningClause != nil)
  #expect(StatementDeparser().deparse(insert) == sql)
}

@Test
func upstreamInsertConflictAndDuplicateCasesParseAndDeparse() throws {
  let conflictSql =
    "INSERT INTO distributors (did, dname) VALUES (5, 'Gizmo') ON CONFLICT (did) DO UPDATE SET dname = 'Gizmo' RETURNING did"
  let conflictParsed = try parseStatement(conflictSql)
  guard let conflict = conflictParsed as? InsertStatement else {
    Issue.record("Expected InsertStatement")
    return
  }
  #expect(conflict.onConflict != nil)
  #expect(conflict.returningClause != nil)
  #expect(StatementDeparser().deparse(conflict) == conflictSql)

  let duplicateSql =
    "INSERT INTO TEST (ID, COUNTER) VALUES (123, 0) ON DUPLICATE KEY UPDATE COUNTER = COUNTER + 1"
  let duplicateParsed = try parseStatement(duplicateSql)
  guard let duplicate = duplicateParsed as? InsertStatement else {
    Issue.record("Expected InsertStatement")
    return
  }
  #expect(duplicate.onDuplicateKeyAssignments.count == 1)
  #expect(StatementDeparser().deparse(duplicate) == duplicateSql)
}

@Test
func upstreamUpdateWithFromAndReturningParsesAndDeparses() throws {
  let sql =
    "UPDATE table1 SET columna = 5 FROM table1 LEFT JOIN table2 ON col1 = col2 WHERE columna >= 3 RETURNING columna"
  let parsed = try parseStatement(sql)

  guard let update = parsed as? UpdateStatement else {
    Issue.record("Expected UpdateStatement")
    return
  }

  #expect(update.from != nil)
  #expect(update.fromJoins.count == 1)
  #expect(update.returningClause != nil)
  #expect(StatementDeparser().deparse(update) == sql)
}

@Test
func upstreamDeleteUsingAndReturningParsesAndDeparses() throws {
  let sql =
    "DELETE FROM products USING archive WHERE products.id = archive.id RETURNING products.id"
  let parsed = try parseStatement(sql)

  guard let delete = parsed as? DeleteStatement else {
    Issue.record("Expected DeleteStatement")
    return
  }

  #expect(delete.usingItems.count == 1)
  #expect(delete.returningClause != nil)
  #expect(StatementDeparser().deparse(delete) == sql)
}

@Test
func upstreamMergeAndReplaceCasesParseAndDeparse() throws {
  let mergeOptions = ParserOptions(
    dialectFeatures: [.sqlServer], experimentalFeatures: [.mergeStatements])
  let mergeSql =
    "MERGE INTO bonuses B USING SELECT employee_id, salary FROM employee ON B.employee_id = employee_id WHEN MATCHED THEN UPDATE SET bonus = salary WHEN NOT MATCHED THEN INSERT (employee_id, bonus) VALUES (employee_id, salary)"
  let mergeParsed = try parseStatement(mergeSql, options: mergeOptions)

  guard let merge = mergeParsed as? MergeStatement else {
    Issue.record("Expected MergeStatement")
    return
  }

  #expect(merge.clauses.count == 2)
  #expect(StatementDeparser().deparse(merge) == mergeSql)

  let replaceOptions = ParserOptions(
    dialectFeatures: [.mysql], experimentalFeatures: [.replaceStatements])
  let replaceSql = "REPLACE INTO mytable (col1, col2, col3) VALUES (1, 'aaa', 2)"
  let replaceParsed = try parseStatement(replaceSql, options: replaceOptions)
  guard let replace = replaceParsed as? ReplaceStatement else {
    Issue.record("Expected ReplaceStatement")
    return
  }
  #expect(replace.columns == ["col1", "col2", "col3"])
  #expect(StatementDeparser().deparse(replace) == replaceSql)
}
