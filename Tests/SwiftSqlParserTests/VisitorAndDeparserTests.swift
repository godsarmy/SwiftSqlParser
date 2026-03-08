import Testing
@testable import SwiftSqlParser

private struct CountingStatementVisitor: StatementVisitor {
    var rawCount = 0
    var selectCount = 0
    var valuesCount = 0
    var withCount = 0
    var setOperationCount = 0
    var insertCount = 0
    var updateCount = 0
    var deleteCount = 0
    var createCount = 0
    var createIndexCount = 0
    var createViewCount = 0
    var alterCount = 0
    var dropCount = 0
    var truncateCount = 0

    mutating func visit(rawStatement: RawStatement) {
        rawCount += 1
    }

    mutating func visit(plainSelect: PlainSelect) {
        selectCount += 1
    }

    mutating func visit(valuesSelect: ValuesSelect) {
        valuesCount += 1
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

    mutating func visit(createTableStatement: CreateTableStatement) {
        createCount += 1
    }

    mutating func visit(createIndexStatement: CreateIndexStatement) {
        createIndexCount += 1
    }

    mutating func visit(createViewStatement: CreateViewStatement) {
        createViewCount += 1
    }

    mutating func visit(alterTableStatement: AlterTableStatement) {
        alterCount += 1
    }

    mutating func visit(dropTableStatement: DropTableStatement) {
        dropCount += 1
    }

    mutating func visit(truncateTableStatement: TruncateTableStatement) {
        truncateCount += 1
    }
}

private struct CountingExpressionVisitor: ExpressionVisitor {
    var caseCount = 0
    var castCount = 0
    var placeholderCount = 0

    mutating func visit(caseExpression: CaseExpression) {
        caseCount += 1
    }

    mutating func visit(castExpression: CastExpression) {
        castCount += 1
    }

    mutating func visit(placeholderExpression: PlaceholderExpression) {
        placeholderCount += 1
    }
}

@Test
func statementVisitorDispatchesExpectedType() {
    let statement = RawStatement(sql: "SELECT 1")
    var visitor = CountingStatementVisitor()

    AstVisit.statement(statement, visitor: &visitor)
    #expect(visitor.rawCount == 1)
    #expect(visitor.selectCount == 0)
    #expect(visitor.valuesCount == 0)
    #expect(visitor.withCount == 0)
    #expect(visitor.setOperationCount == 0)
    #expect(visitor.insertCount == 0)
    #expect(visitor.updateCount == 0)
    #expect(visitor.deleteCount == 0)
    #expect(visitor.createCount == 0)
    #expect(visitor.createIndexCount == 0)
    #expect(visitor.createViewCount == 0)
    #expect(visitor.alterCount == 0)
    #expect(visitor.dropCount == 0)
    #expect(visitor.truncateCount == 0)
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
func selectDeparserBuildsExtendedQueryClauses() {
    let select = PlainSelect(
        isDistinct: true,
        selectItems: [
            ExpressionSelectItem(expression: IdentifierExpression(name: "department_id")),
            ExpressionSelectItem(
                expression: FunctionExpression(
                    name: "count",
                    arguments: [IdentifierExpression(name: "id")]
                )
            )
        ],
        from: TableFromItem(name: "users"),
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "active"),
            operator: .equals,
            right: NumberLiteralExpression(value: 1)
        ),
        groupByExpressions: [IdentifierExpression(name: "department_id")],
        havingExpression: BinaryExpression(
            left: FunctionExpression(name: "count", arguments: [IdentifierExpression(name: "id")]),
            operator: .equals,
            right: NumberLiteralExpression(value: 2)
        ),
        qualifyExpression: BinaryExpression(
            left: FunctionExpression(
                name: "count",
                arguments: [IdentifierExpression(name: "id")],
                overClause: WindowSpecification(partitionBy: [IdentifierExpression(name: "department_id")])
            ),
            operator: .greaterThan,
            right: NumberLiteralExpression(value: 1)
        ),
        orderBy: [
            OrderByElement(
                expression: IdentifierExpression(name: "department_id"),
                direction: .descending
            ),
            OrderByElement(
                expression: FunctionExpression(name: "count", arguments: [IdentifierExpression(name: "id")]),
                direction: .ascending
            )
        ],
        limit: 10,
        offset: 20
    )

    let sql = StatementDeparser().deparse(select)
    #expect(sql == "SELECT DISTINCT department_id, count(id) FROM users WHERE active = 1 GROUP BY department_id HAVING count(id) = 2 QUALIFY count(id) OVER (PARTITION BY department_id) > 1 ORDER BY department_id DESC, count(id) ASC LIMIT 10 OFFSET 20")
}

@Test
func deparserHandlesValuesAndAdvancedJoins() {
    let values = ValuesSelect(rows: [[NumberLiteralExpression(value: 1), StringLiteralExpression(value: "a")]])
    #expect(StatementDeparser().deparse(values) == "VALUES (1, 'a')")

    let select = PlainSelect(
        selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "u.id"))],
        from: TableFromItem(name: "users", alias: "u"),
        joins: [
            Join(
                type: .crossApply,
                fromItem: SubqueryFromItem(
                    statement: PlainSelect(
                        selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "id"))],
                        from: TableFromItem(name: "roles")),
                    alias: "r",
                    isLateral: true
                )
            )
        ]
    )
    #expect(StatementDeparser().deparse(select) == "SELECT u.id FROM users u CROSS APPLY LATERAL (SELECT id FROM roles) r")
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

@Test
func expressionDeparserHandlesAdvancedExpressions() {
    let caseExpression = CaseExpression(
        whenClauses: [
            CaseWhenClause(
                condition: BinaryExpression(
                    left: IdentifierExpression(name: "score"),
                    operator: .greaterThanOrEquals,
                    right: NumberLiteralExpression(value: 90)
                ),
                result: StringLiteralExpression(value: "A")
            )
        ],
        elseExpression: StringLiteralExpression(value: "B")
    )
    #expect(ExpressionDeparser().deparse(caseExpression) == "CASE WHEN score >= 90 THEN 'A' ELSE 'B' END")

    let castExpression = CastExpression(
        expression: IdentifierExpression(name: "name"),
        typeName: "TEXT",
        style: .postgres
    )
    #expect(ExpressionDeparser().deparse(castExpression) == "name::TEXT")

    let predicate = InListExpression(
        expression: IdentifierExpression(name: "id"),
        values: [NumberLiteralExpression(value: 1), NumberLiteralExpression(value: 2)]
    )
    #expect(ExpressionDeparser().deparse(predicate) == "id IN (1, 2)")
}

@Test
func expressionVisitorDispatchesAdvancedTypes() {
    var visitor = CountingExpressionVisitor()

    AstVisit.expression(CaseExpression(whenClauses: [], elseExpression: nil), visitor: &visitor)
    AstVisit.expression(CastExpression(expression: IdentifierExpression(name: "name"), typeName: "TEXT"), visitor: &visitor)
    AstVisit.expression(PlaceholderExpression(token: "?"), visitor: &visitor)

    #expect(visitor.caseCount == 1)
    #expect(visitor.castCount == 1)
    #expect(visitor.placeholderCount == 1)
}
