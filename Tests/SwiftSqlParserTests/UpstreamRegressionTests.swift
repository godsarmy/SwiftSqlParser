import Testing

@testable import SwiftSqlParser

// JSqlParser #2751: trailing pagination belongs to the combined query.
@Test(arguments: ["UNION", "UNION ALL", "INTERSECT", "EXCEPT"])
func setOperationOwnsTrailingClauses(operation: String) throws {
  let sql =
    "SELECT id FROM users \(operation) SELECT id FROM archived ORDER BY id DESC LIMIT 5 OFFSET 2"
  let parsed = try #require(parseStatement(sql) as? SetOperationSelect)
  let left = try #require(parsed.left as? PlainSelect)
  let right = try #require(parsed.right as? PlainSelect)
  #expect(parsed.orderBy.count == 1)
  #expect(parsed.orderBy.first?.direction == .descending)
  #expect(parsed.limit == 5)
  #expect(parsed.offset == 2)
  #expect(left.orderBy.isEmpty && right.orderBy.isEmpty)
  #expect(left.limit == nil && right.limit == nil)
  #expect(left.offset == nil && right.offset == nil)
  let deparsed = StatementDeparser().deparse(parsed)
  #expect(deparsed == sql)
  let reparsed = try #require(parseStatement(deparsed) as? SetOperationSelect)
  #expect(reparsed.limit == 5 && reparsed.offset == 2)
  #expect((reparsed.right as? PlainSelect)?.limit == nil)
}

@Test
func setOperationPreservesOperandLocalClauses() throws {
  let sql =
    "(SELECT id FROM users ORDER BY id LIMIT 3) UNION (SELECT id FROM archived LIMIT 2) ORDER BY id LIMIT 5 OFFSET 1"
  let parsed = try #require(parseStatement(sql) as? SetOperationSelect)
  #expect((parsed.left as? PlainSelect)?.limit == 3)
  #expect((parsed.right as? PlainSelect)?.limit == 2)
  #expect(parsed.limit == 5 && parsed.offset == 1)
  #expect(StatementDeparser().deparse(parsed) == sql)
  let reparsed = try #require(
    parseStatement(StatementDeparser().deparse(parsed)) as? SetOperationSelect)
  #expect((reparsed.left as? PlainSelect)?.limit == 3)
  #expect((reparsed.right as? PlainSelect)?.limit == 2)
}

@Test
func nestedSetOperationsPreserveGroupingAndPagination() throws {
  let sql =
    "(SELECT id FROM users UNION SELECT id FROM archived LIMIT 3) EXCEPT (SELECT id FROM blocked EXCEPT SELECT id FROM allowed) LIMIT 8"
  let parsed = try #require(parseStatement(sql) as? SetOperationSelect)
  #expect((parsed.left as? SetOperationSelect)?.limit == 3)
  #expect(parsed.right is SetOperationSelect)
  #expect(parsed.limit == 8)
  #expect(StatementDeparser().deparse(parsed) == sql)
  let reparsed = try #require(
    parseStatement(StatementDeparser().deparse(parsed)) as? SetOperationSelect)
  #expect((reparsed.left as? SetOperationSelect)?.limit == 3)
  #expect(reparsed.right is SetOperationSelect)
}

@Test
func withAndValuesSetOperationOwnsTrailingClauses() throws {
  let sql =
    "WITH ids AS (SELECT id FROM users) SELECT id FROM ids UNION VALUES (1) LIMIT 4 OFFSET 2"
  let parsed = try #require(parseStatement(sql) as? WithSelect)
  let body = try #require(parsed.body as? SetOperationSelect)
  #expect(body.right is ValuesSelect)
  #expect(body.limit == 4 && body.offset == 2)
  #expect(StatementDeparser().deparse(parsed) == sql)
}

@Test
func pipedSetOperationOwnsUnpipedTrailingClauses() throws {
  let parsed = try #require(
    parseStatement(
      "FROM users |> SELECT id |> UNION SELECT id FROM archived LIMIT 4",
      options: .init(experimentalFeatures: [.pipedSql])) as? SetOperationSelect)
  #expect(parsed.limit == 4)
  #expect((parsed.right as? PlainSelect)?.limit == nil)
  #expect(
    StatementDeparser().deparse(parsed)
      == "SELECT id FROM users UNION SELECT id FROM archived LIMIT 4")
}

@Test(arguments: [
  "SELECT id FROM users LIMIT 1 UNION SELECT id FROM archived",
  "SELECT id FROM users UNION SELECT id FROM archived LIMIT 1 LIMIT 2",
])
func setOperationRejectsMisplacedOrDuplicateClauses(sql: String) {
  #expect(SqlParser().parseStatementResult(sql).diagnostic?.code == .unsupportedSyntax)
}

// JSqlParser #2749 and #2826: visit every structured query/DML child.
@Test
func tableFinderVisitsValuesDistinctAndStarReplacements() throws {
  let finder = TableNameFinder()
  let values = try parseStatement("VALUES ((SELECT id FROM value_source))")
  #expect(finder.find(in: values) == ["value_source"])
  let distinct = try parseStatement(
    "SELECT DISTINCT ON ((SELECT id FROM distinct_source)) id FROM users",
    options: .init(dialectFeatures: [.postgres], experimentalFeatures: [.postgresDistinctOn]))
  #expect(finder.find(in: distinct) == ["distinct_source", "users"])
  let replacement = try parseStatement(
    "SELECT * REPLACE ((SELECT id FROM replacement_source) AS id) FROM users",
    options: .init(dialectFeatures: [.bigQuery]))
  #expect(finder.find(in: replacement) == ["replacement_source", "users"])
}

@Test(arguments: ["INSERT", "UPSERT"])
func tableFinderVisitsConflictUpdates(verb: String) throws {
  let parsed = try parseStatement(
    "\(verb) INTO users (id) VALUES (1) ON CONFLICT (id) DO UPDATE SET id = (SELECT id FROM update_source) WHERE EXISTS (SELECT id FROM predicate_source)",
    options: .init(dialectFeatures: [.postgres]))
  #expect(TableNameFinder().find(in: parsed) == ["predicate_source", "update_source", "users"])
}

@Test
func tableFinderVisitsDuplicateKeyUpdates() throws {
  let parsed = try parseStatement(
    "INSERT INTO users (id) VALUES (1) ON DUPLICATE KEY UPDATE id = (SELECT id FROM duplicate_source)",
    options: .init(dialectFeatures: [.mysql]))
  #expect(TableNameFinder().find(in: parsed) == ["duplicate_source", "users"])
}

@Test
func tableFinderVisitsPlainAndSetPaginationExpressions() {
  func subquery(_ table: String) -> SubqueryExpression {
    SubqueryExpression(
      statement: PlainSelect(
        selectItems: [AllColumnsSelectItem()], from: TableFromItem(name: table)))
  }
  let plain = PlainSelect(
    selectItems: [AllColumnsSelectItem()], from: TableFromItem(name: "users"),
    limitExpression: subquery("plain_limit"), offsetExpression: subquery("plain_offset"))
  #expect(TableNameFinder().find(in: plain) == ["plain_limit", "plain_offset", "users"])
  let combined = SetOperationSelect(
    left: plain, operation: .union,
    right: ValuesSelect(rows: [[NumberLiteralExpression(value: 1)]]),
    orderBy: [OrderByElement(expression: subquery("set_order"))],
    limitExpression: subquery("set_limit"), offsetExpression: subquery("set_offset"))
  #expect(
    TableNameFinder().find(in: combined) == [
      "plain_limit", "plain_offset", "set_limit", "set_offset", "set_order", "users",
    ])
  let sql = StatementDeparser().deparse(combined)
  #expect(
    sql.contains(
      "ORDER BY (SELECT * FROM set_order) LIMIT (SELECT * FROM set_limit) OFFSET (SELECT * FROM set_offset)"
    ))
}

@Test
func setOperationDeparserPreservesMixedLeftGrouping() throws {
  let sql = "(SELECT id FROM users UNION SELECT id FROM archived) INTERSECT SELECT id FROM allowed"
  let parsed = try parseStatement(sql)
  #expect(StatementDeparser().deparse(parsed) == sql)
  let reparsed = try #require(
    parseStatement(StatementDeparser().deparse(parsed)) as? SetOperationSelect)
  #expect(reparsed.operation == .intersect)
  #expect((reparsed.left as? SetOperationSelect)?.operation == .union)
}

@Test(arguments: ["ORDER BY id", "LIMIT 0", "OFFSET 2"])
func setOperationSupportsIndividualTrailingClauses(tail: String) throws {
  let sql = "SELECT id FROM users UNION SELECT id FROM archived \(tail)"
  let parsed = try #require(parseStatement(sql) as? SetOperationSelect)
  #expect(StatementDeparser().deparse(parsed) == sql)
  if tail.hasPrefix("ORDER") { #expect(parsed.orderBy.count == 1) }
  if tail.hasPrefix("LIMIT") { #expect(parsed.limit == 0) }
  if tail.hasPrefix("OFFSET") { #expect(parsed.offset == 2) }
  let right = try #require(parsed.right as? PlainSelect)
  #expect(right.orderBy.isEmpty && right.limit == nil && right.offset == nil)
}
