import Testing
@testable import SwiftSqlParser

private struct CountingStatementVisitor: StatementVisitor {
    var rawCount = 0
    var selectCount = 0
    var withCount = 0
    var setOperationCount = 0
    var insertCount = 0
    var updateCount = 0
    var deleteCount = 0

    mutating func visit(rawStatement: RawStatement) {
        rawCount += 1
    }

    mutating func visit(plainSelect: PlainSelect) {
        selectCount += 1
    }

    mutating func visit(withSelect: WithSelect) {
        withCount += 1
    }

    mutating func visit(setOperationSelect: SetOperationSelect) {
        setOperationCount += 1
    }

    mutating func visit(insertStatement: InsertStatement) {
        insertCount += 1
    }

    mutating func visit(updateStatement: UpdateStatement) {
        updateCount += 1
    }

    mutating func visit(deleteStatement: DeleteStatement) {
        deleteCount += 1
    }
}

@Test
func statementVisitorDispatchesExpectedType() {
    let statement = RawStatement(sql: "SELECT 1")
    var visitor = CountingStatementVisitor()

    AstVisit.statement(statement, visitor: &visitor)
    #expect(visitor.rawCount == 1)
    #expect(visitor.selectCount == 0)
    #expect(visitor.withCount == 0)
    #expect(visitor.setOperationCount == 0)
    #expect(visitor.insertCount == 0)
    #expect(visitor.updateCount == 0)
    #expect(visitor.deleteCount == 0)
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

@Test
func deparserHandlesWithAndSetOperations() {
    let withStatement = WithSelect(
        expressions: [
            CommonTableExpression(
                name: "active_users",
                statement: PlainSelect(
                    selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "id"))],
                    from: TableFromItem(name: "users")
                )
            )
        ],
        body: SetOperationSelect(
            left: PlainSelect(
                selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "id"))],
                from: TableFromItem(name: "active_users")
            ),
            operation: .union,
            isAll: true,
            right: PlainSelect(
                selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "id"))],
                from: TableFromItem(name: "roles")
            )
        )
    )

    let sql = StatementDeparser().deparse(withStatement)
    #expect(sql == "WITH active_users AS (SELECT id FROM users) SELECT id FROM active_users UNION ALL SELECT id FROM roles")
}
