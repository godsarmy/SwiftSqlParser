import Testing
@testable import SwiftSqlParser

private struct CountingStatementVisitor: StatementVisitor {
    var rawCount = 0
    var selectCount = 0

    mutating func visit(rawStatement: RawStatement) {
        rawCount += 1
    }

    mutating func visit(plainSelect: PlainSelect) {
        selectCount += 1
    }
}

@Test
func statementVisitorDispatchesExpectedType() {
    let statement = RawStatement(sql: "SELECT 1")
    var visitor = CountingStatementVisitor()

    AstVisit.statement(statement, visitor: &visitor)
    #expect(visitor.rawCount == 1)
    #expect(visitor.selectCount == 0)
}

@Test
func selectDeparserBuildsExpectedSql() {
    let select = PlainSelect(
        selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "id"))],
        from: TableFromItem(name: "users"),
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "active"),
            operator: .equals,
            right: NumberLiteralExpression(value: 1)
        )
    )

    let sql = StatementDeparser().deparse(select)
    #expect(sql == "SELECT id FROM users WHERE active = 1")
}
