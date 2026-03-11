import Testing

@testable import SwiftSqlParser

@Test
func sqlServerSquareBracketIdentifiersParseWhenEnabled() throws {
  let options = ParserOptions(
    identifierQuoting: .squareBrackets,
    dialectFeatures: [.sqlServer],
    experimentalFeatures: [.quotedIdentifiers]
  )
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
  let options = ParserOptions(dialectFeatures: [.mysql], experimentalFeatures: [.quotedIdentifiers])
  let parsed = try parseStatement("SELECT `id` FROM `users`", options: options)

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.selectItems.count == 1)
  #expect(StatementDeparser().deparse(select) == "SELECT id FROM users")
}

@Test
func mariaDbBacktickIdentifiersParseWhenEnabled() throws {
  let options = ParserOptions(
    dialectFeatures: [.mariaDB], experimentalFeatures: [.quotedIdentifiers])
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
  let options = ParserOptions(dialectFeatures: [.postgres], experimentalFeatures: [.postgresIlike])
  let parsed = try parseStatement("SELECT id FROM users WHERE name ILIKE 'a%'", options: options)

  guard let select = parsed as? PlainSelect,
    let whereExpression = select.whereExpression as? BinaryExpression
  else {
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

@Test
func postgresDistinctOnParsesWhenEnabled() throws {
  let options = ParserOptions(
    dialectFeatures: [.postgres], experimentalFeatures: [.postgresDistinctOn])
  let parsed = try parseStatement(
    "SELECT DISTINCT ON (department_id) department_id, id FROM users", options: options)

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.distinctOnExpressions.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT DISTINCT ON (department_id) department_id, id FROM users")
}

@Test
func postgresDistinctOnWithoutFeatureReturnsUnsupported() {
  let options = ParserOptions(dialectFeatures: [.postgres])
  #expect(throws: SqlParseError.self) {
    _ = try parseStatement(
      "SELECT DISTINCT ON (department_id) department_id, id FROM users", options: options)
  }
}

@Test
func sqlServerTopParsesWhenEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.sqlServer], experimentalFeatures: [.sqlServerTop])
  let parsed = try parseStatement("SELECT TOP 5 id FROM users", options: options)

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.top == 5)
  #expect(StatementDeparser().deparse(select) == "SELECT TOP 5 id FROM users")
}

@Test
func sybaseTopParsesWhenEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.sybase], experimentalFeatures: [.sqlServerTop])
  let parsed = try parseStatement("SELECT TOP 5 id FROM users", options: options)

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(select.top == 5)
  #expect(StatementDeparser().deparse(select) == "SELECT TOP 5 id FROM users")
}

@Test
func sqlServerTopWithoutFeatureReturnsUnsupported() {
  let options = ParserOptions(dialectFeatures: [.sqlServer])
  #expect(throws: SqlParseError.self) {
    _ = try parseStatement("SELECT TOP 5 id FROM users", options: options)
  }
}

@Test
func oracleAlternativeQuotingParsesWhenEnabled() throws {
  let options = ParserOptions(
    dialectFeatures: [.oracle], experimentalFeatures: [.oracleAlternativeQuoting])
  let parsed = try parseStatement("SELECT q'[hello]' FROM dual", options: options)

  guard let select = parsed as? PlainSelect else {
    Issue.record("Expected PlainSelect")
    return
  }

  #expect(StatementDeparser().deparse(select) == "SELECT 'hello' FROM dual")
}

@Test
func replaceAndMergeRequireFeatures() {
  #expect(throws: SqlParseError.self) {
    _ = try parseStatement(
      "REPLACE INTO users (id) VALUES (1)", options: ParserOptions(dialectFeatures: [.mysql]))
  }

  #expect(throws: SqlParseError.self) {
    _ = try parseStatement(
      "MERGE INTO users target USING SELECT id FROM staging_users source ON target.id = source.id WHEN MATCHED THEN UPDATE SET name = source.name",
      options: ParserOptions(dialectFeatures: [.sqlServer])
    )
  }
}

@Test
func pivotSyntaxRequiresFeature() {
  let options = ParserOptions(dialectFeatures: [.sqlServer])
  #expect(throws: SqlParseError.self) {
    _ = try parseStatement(
      "SELECT sales.id FROM sales PIVOT (SUM(amount) FOR region IN ('EAST' east)) p",
      options: options)
  }
}

@Test
func bigQuerySelectQualifierAndStarTransformersParse() throws {
  let options = ParserOptions(
    dialectFeatures: [.bigQuery],
    experimentalFeatures: [.quotedIdentifiers]
  )
  let parsed = try parseStatement(
    "SELECT AS STRUCT * EXCEPT (internal_id) REPLACE (name AS name) FROM `project.dataset.users`",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let allColumns = select.selectItems.first as? AllColumnsSelectItem
  else {
    Issue.record("Expected PlainSelect with AllColumnsSelectItem")
    return
  }

  #expect(select.selectQualifier == .asStruct)
  #expect(allColumns.exceptColumns == ["internal_id"])
  #expect(allColumns.replacements.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT AS STRUCT * EXCEPT (internal_id) REPLACE (name AS name) FROM project.dataset.users"
  )
}

@Test
func bigQueryCastFormatParsesWhenEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.bigQuery])
  let parsed = try parseStatement(
    "SELECT CAST(created_at AS STRING FORMAT 'YYYY-MM-DD') FROM users",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let cast = (select.selectItems.first as? ExpressionSelectItem)?.expression as? CastExpression
  else {
    Issue.record("Expected CAST expression")
    return
  }

  #expect(cast.typeName == "STRING")
  #expect(cast.format == "YYYY-MM-DD")
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT CAST(created_at AS STRING FORMAT 'YYYY-MM-DD') FROM users")
}

@Test
func snowflakeTimeTravelClauseParsesWhenEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.snowflake])
  let parsed = try parseStatement("SELECT id FROM users t AT ('2024-01-01')", options: options)

  guard let select = parsed as? PlainSelect,
    let table = select.from as? TableFromItem
  else {
    Issue.record("Expected table from item")
    return
  }

  #expect(table.alias == "t")
  #expect(table.timeTravelClauseAfterAlias == "AT ('2024-01-01')")
  #expect(StatementDeparser().deparse(select) == "SELECT id FROM users t AT ('2024-01-01')")
}

@Test
func soqlIncludesExcludesParsesWhenDialectEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.salesforceSoql])
  let parsed = try parseStatement(
    "SELECT id FROM accounts WHERE industries INCLUDES ('Banking', 'Finance') AND industries EXCLUDES ('Gaming')",
    options: options
  )

  guard let select = parsed as? PlainSelect,
    let andExpression = select.whereExpression as? BinaryExpression,
    let left = andExpression.left as? SoqlIncludesExcludesExpression,
    let right = andExpression.right as? SoqlIncludesExcludesExpression
  else {
    Issue.record("Expected SOQL INCLUDES/EXCLUDES expression tree")
    return
  }

  #expect(andExpression.operator == .and)
  #expect(left.operator == .includes)
  #expect(left.values.count == 2)
  #expect(right.operator == .excludes)
  #expect(right.values.count == 1)
  #expect(
    StatementDeparser().deparse(select)
      == "SELECT id FROM accounts WHERE industries INCLUDES ('Banking', 'Finance') AND industries EXCLUDES ('Gaming')"
  )
}

@Test
func soqlIncludesExcludesRequireDialectFlag() {
  #expect(throws: SqlParseError.self) {
    _ = try parseStatement("SELECT id FROM accounts WHERE industries INCLUDES ('Banking')")
  }

  #expect(throws: SqlParseError.self) {
    _ = try parseStatement("SELECT id FROM accounts WHERE industries EXCLUDES ('Gaming')")
  }
}
