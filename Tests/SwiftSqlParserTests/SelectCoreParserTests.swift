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
  let sql =
    "SELECT DISTINCT department_id, count(id) OVER (PARTITION BY department_id ORDER BY created_at DESC) FROM users WHERE active = 1 GROUP BY department_id HAVING count(id) = 2 QUALIFY count(id) OVER (PARTITION BY department_id) > 1 ORDER BY department_id DESC, count(id) ASC LIMIT 10 OFFSET 20"
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

  let applyParsed = try parseStatement(
    "SELECT u.id FROM users u CROSS APPLY LATERAL (SELECT id FROM roles) r")
  guard let apply = applyParsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }
  #expect(apply.joins.first?.type == .crossApply)
}

@Test
func pivotAndUnpivotParseWhenEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.sqlServer], experimentalFeatures: [.pivotSyntax])

  let pivotParsed = try parseStatement(
    "SELECT sales.id FROM sales PIVOT (SUM(amount) FOR region IN ('EAST' east, 'WEST' west)) p",
    options: options
  )
  guard let pivotSelect = pivotParsed as? PlainSelect,
    let pivot = pivotSelect.from as? PivotFromItem
  else {
    Issue.record("Expected PivotFromItem")
    return
  }
  #expect(pivot.values.count == 2)

  let unpivotParsed = try parseStatement(
    "SELECT sales.id FROM sales UNPIVOT (amount FOR region IN (east, west)) u",
    options: options
  )
  guard let unpivotSelect = unpivotParsed as? PlainSelect,
    let unpivot = unpivotSelect.from as? UnpivotFromItem
  else {
    Issue.record("Expected UnpivotFromItem")
    return
  }
  #expect(unpivot.columns == ["east", "west"])
}

@Test
func selectParserBuildsAdvancedExpressionNodes() throws {
  let sql =
    "SELECT CASE WHEN age >= 18 THEN 'adult' ELSE 'minor' END AS bucket, CAST(score AS INTEGER) AS cast_score, name::TEXT AS text_name FROM users WHERE deleted_at IS NULL AND id IN (1, 2, 3) AND score BETWEEN 10 AND 20 AND email LIKE ? AND EXISTS (SELECT id FROM roles WHERE roles.user_id = users.id)"
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

@Test
func pipedFromSqlParsesWhenFeatureEnabled() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> WHERE active = 1 |> SELECT id, name |> HAVING COUNT(id) > 0 |> QUALIFY id > 10 |> ORDER BY id DESC |> LIMIT 5 OFFSET 2",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 2)
  #expect(select.whereExpression != nil)
  #expect(select.havingExpression != nil)
  #expect(select.qualifyExpression != nil)
  #expect(select.orderBy.count == 1)
  #expect(select.orderBy.first?.direction == .descending)
  #expect(select.limit == 5)
  #expect(select.offset == 2)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT id, name FROM users WHERE active = 1 HAVING COUNT(id) > 0 QUALIFY id > 10 ORDER BY id DESC LIMIT 5 OFFSET 2"
  )
}

@Test
func pipedFromSqlRequiresFeatureFlag() {
  #expect(throws: SqlParseError.self) {
    _ = try parseStatement("FROM users |> WHERE active = 1 |> SELECT id")
  }
}

@Test
func pipedFromSqlSupportsJoinAndAggregateOperators() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users u |> JOIN roles r ON u.role_id = r.id |> AGGREGATE r.name, COUNT(*) AS total GROUP BY r.name |> ORDER BY total DESC",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.joins.count == 1)
  #expect(select.groupByExpressions.count == 1)
  #expect(select.selectItems.count == 2)
  #expect(select.orderBy.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT r.name, COUNT(*) AS total FROM users u INNER JOIN roles r ON u.role_id = r.id GROUP BY r.name ORDER BY total DESC"
  )
}

@Test
func pipedFromSqlSupportsAsOperatorBeforeJoin() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> AGGREGATE role_id, COUNT(*) AS total GROUP BY role_id |> AS grouped |> JOIN roles r ON grouped.role_id = r.id |> SELECT r.id, grouped.total",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  let subquery = select.from as? SubqueryFromItem
  let grouped = subquery?.statement as? PlainSelect

  #expect(subquery?.alias == "grouped")
  #expect(grouped?.groupByExpressions.count == 1)
  #expect(grouped?.selectItems.count == 2)
  #expect(select.joins.count == 1)
  #expect(select.selectItems.count == 2)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT r.id, grouped.total FROM (SELECT role_id, COUNT(*) AS total FROM users GROUP BY role_id) grouped INNER JOIN roles r ON grouped.role_id = r.id"
  )
}

@Test
func pipedFromSqlSupportsStandaloneOffsetOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> SELECT id |> OFFSET 7",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 1)
  #expect(select.limit == nil)
  #expect(select.offset == 7)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT id FROM users OFFSET 7"
  )
}

@Test
func pipedFromSqlSupportsDistinctOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> SELECT department_id |> DISTINCT |> ORDER BY department_id",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.isDistinct)
  #expect(select.selectItems.count == 1)
  #expect(select.orderBy.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT DISTINCT department_id FROM users ORDER BY department_id"
  )
}

@Test
func pipedFromSqlSupportsSelAlias() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> SEL id, name",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 2)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT id, name FROM users"
  )
}

@Test
func pipedFromSqlSupportsWindowAlias() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> WINDOW ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY id) AS row_num",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY id) AS row_num FROM users"
  )
}

@Test
func pipedFromSqlSupportsSetOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> SET name = UPPER(name), active = 1",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let allColumns = select.selectItems.first as? AllColumnsSelectItem
  else {
    Issue.record("Expected PlainSelect with all-columns replacement")
    return
  }

  #expect(allColumns.replacements.count == 2)
  #expect(select.selectItems.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT * REPLACE (UPPER(name) AS name, 1 AS active) FROM users"
  )
}

@Test
func pipedFromSqlSupportsCallOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> CALL normalize_users() cleaned",
    options: options
  )

  guard let call = parsed as? PipeCallStatement,
    let source = call.source as? PlainSelect
  else {
    Issue.record("Expected PipeCallStatement")
    return
  }

  #expect(call.alias == "cleaned")
  #expect(call.function.name == "normalize_users")
  #expect(source.selectItems.count == 1)
  #expect(
    StatementDeparser().deparse(call)
      == "SELECT * FROM users |> CALL normalize_users() cleaned"
  )
}

@Test
func pipedFromSqlSupportsUnionAllOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> SELECT id |> UNION ALL SELECT id FROM archived_users",
    options: options
  )

  guard let setOperation = parsed as? SetOperationSelect,
    let left = setOperation.left as? PlainSelect,
    let right = setOperation.right as? PlainSelect
  else {
    Issue.record("Expected SetOperationSelect")
    return
  }

  #expect(setOperation.operation == .union)
  #expect(setOperation.isAll)
  #expect(left.selectItems.count == 1)
  #expect(right.selectItems.count == 1)
  #expect(
    StatementDeparser().deparse(setOperation)
      == "SELECT id FROM users UNION ALL SELECT id FROM archived_users"
  )
}

@Test
func pipedFromSqlCanContinueAfterSetOperation() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> SELECT id |> UNION SELECT id FROM archived_users |> AS combined |> WHERE combined.id > 10",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let from = select.from as? SubqueryFromItem,
    let setOperation = from.statement as? SetOperationSelect
  else {
    Issue.record("Expected PlainSelect over subquery set operation")
    return
  }

  #expect(from.alias == "combined")
  #expect(setOperation.operation == .union)
  #expect(select.whereExpression != nil)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT * FROM (SELECT id FROM users UNION SELECT id FROM archived_users) combined WHERE combined.id > 10"
  )
}

@Test
func pipedFromSqlSupportsPivotOperator() throws {
  let options = ParserOptions(
    dialectFeatures: [.sqlServer],
    experimentalFeatures: [.pipedSql, .pivotSyntax]
  )
  let parsed = try parseStatement(
    "FROM sales |> PIVOT (SUM(amount) FOR region IN ('EAST' east, 'WEST' west)) p |> SELECT p.id",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let pivot = select.from as? PivotFromItem
  else {
    Issue.record("Expected PlainSelect with PivotFromItem")
    return
  }

  #expect(pivot.alias == "p")
  #expect(pivot.values.count == 2)
  #expect(select.selectItems.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT p.id FROM sales PIVOT (SUM(amount) FOR region IN ('EAST' AS east, 'WEST' AS west)) p"
  )
}

@Test
func pipedFromSqlSupportsUnpivotOperator() throws {
  let options = ParserOptions(
    dialectFeatures: [.sqlServer],
    experimentalFeatures: [.pipedSql, .pivotSyntax]
  )
  let parsed = try parseStatement(
    "FROM sales |> UNPIVOT (amount FOR region IN (east, west)) u |> SELECT u.amount, u.region",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let unpivot = select.from as? UnpivotFromItem
  else {
    Issue.record("Expected PlainSelect with UnpivotFromItem")
    return
  }

  #expect(unpivot.alias == "u")
  #expect(unpivot.columns == ["east", "west"])
  #expect(select.selectItems.count == 2)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT u.amount, u.region FROM sales UNPIVOT (amount FOR region IN (east, west)) u"
  )
}

@Test
func pipedFromSqlSupportsExtendOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> EXTEND active = 1 AS is_active",
    options: options
  )

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 2)
  #expect(select.selectItems.first is AllColumnsSelectItem)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT *, active = 1 AS is_active FROM users"
  )
}

@Test
func pipedFromSqlSupportsRenameOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> RENAME name AS full_name",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let allColumns = select.selectItems.first as? AllColumnsSelectItem,
    let renamedItem = select.selectItems.dropFirst().first as? ExpressionSelectItem
  else {
    Issue.record("Expected PlainSelect with renamed projection")
    return
  }

  #expect(allColumns.exceptColumns == ["name"])
  #expect(renamedItem.alias == "full_name")
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT * EXCEPT (name), name AS full_name FROM users"
  )
}

@Test
func pipedFromSqlSupportsDropOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> DROP password, deleted_at",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let allColumns = select.selectItems.first as? AllColumnsSelectItem
  else {
    Issue.record("Expected PlainSelect with all-columns transformer")
    return
  }

  #expect(allColumns.exceptColumns == ["deleted_at", "password"])
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT * EXCEPT (deleted_at, password) FROM users"
  )
}

@Test
func standardFromTableSampleParses() throws {
  let parsed = try parseStatement("SELECT id FROM users TABLESAMPLE SYSTEM (1.0 PERCENT)")

  guard let select = parsed as? PlainSelect,
    let tableSample = select.from as? TableSampleFromItem
  else {
    Issue.record("Expected PlainSelect with TableSampleFromItem")
    return
  }

  #expect(tableSample.method == "SYSTEM")
  #expect(tableSample.size == "1.0")
  #expect(tableSample.unit == "PERCENT")
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT id FROM users TABLESAMPLE SYSTEM (1.0 PERCENT)"
  )
}

@Test
func pipedFromSqlSupportsTableSampleOperator() throws {
  let options = ParserOptions(experimentalFeatures: [.pipedSql])
  let parsed = try parseStatement(
    "FROM users |> TABLESAMPLE SYSTEM (1.0 PERCENT) |> SELECT id",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let tableSample = select.from as? TableSampleFromItem
  else {
    Issue.record("Expected PlainSelect with TableSampleFromItem")
    return
  }

  #expect(tableSample.method == "SYSTEM")
  #expect(tableSample.size == "1.0")
  #expect(tableSample.unit == "PERCENT")
  #expect(select.selectItems.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT id FROM users TABLESAMPLE SYSTEM (1.0 PERCENT)"
  )
}
