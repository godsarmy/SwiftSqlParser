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
