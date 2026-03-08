import Testing
@testable import SwiftSqlParser

@Test
func insertParsesIntoInsertStatement() throws {
    let parsed = try parseStatement("INSERT INTO users (id, name) VALUES (1, 'Alice')")
    guard let insert = parsed as? InsertStatement else {
        Issue.record("Expected InsertStatement")
        return
    }

    #expect(insert.table == "users")
    #expect(insert.columns == ["id", "name"])
    guard case let .values(rows) = insert.source else {
        Issue.record("Expected values source")
        return
    }
    #expect(rows.count == 1)
    #expect(rows[0].count == 2)
}

@Test
func updateParsesIntoUpdateStatement() throws {
    let parsed = try parseStatement("UPDATE users SET active = 1, name = 'Alice' WHERE id = 1")
    guard let update = parsed as? UpdateStatement else {
        Issue.record("Expected UpdateStatement")
        return
    }

    #expect(update.table == "users")
    #expect(update.assignments.count == 2)
    #expect(update.whereExpression != nil)
}

@Test
func deleteParsesIntoDeleteStatement() throws {
    let parsed = try parseStatement("DELETE FROM users WHERE id = 2")
    guard let delete = parsed as? DeleteStatement else {
        Issue.record("Expected DeleteStatement")
        return
    }

    #expect(delete.table == "users")
    #expect(delete.whereExpression != nil)
}

@Test
func deparserHandlesDmlStatements() {
    let deparser = StatementDeparser()

    let insert = InsertStatement(
        table: "users",
        columns: ["id", "name"],
        values: [[NumberLiteralExpression(value: 1), StringLiteralExpression(value: "Alice")]]
    )
    #expect(deparser.deparse(insert) == "INSERT INTO users (id, name) VALUES (1, 'Alice')")

    let update = UpdateStatement(
        table: "users",
        assignments: [
            UpdateAssignment(column: "active", value: NumberLiteralExpression(value: 1)),
            UpdateAssignment(column: "name", value: StringLiteralExpression(value: "Alice"))
        ],
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "id"),
            operator: .equals,
            right: NumberLiteralExpression(value: 1)
        )
    )
    #expect(deparser.deparse(update) == "UPDATE users SET active = 1, name = 'Alice' WHERE id = 1")

    let delete = DeleteStatement(
        table: "users",
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "id"),
            operator: .equals,
            right: NumberLiteralExpression(value: 2)
        )
    )
    #expect(deparser.deparse(delete) == "DELETE FROM users WHERE id = 2")
}

@Test
func insertSupportsSelectConflictDuplicateAndReturning() throws {
    let insertFromSelect = try parseStatement(
        "INSERT INTO archived_users (id, name) SELECT id, name FROM users RETURNING id"
    )
    guard let insert = insertFromSelect as? InsertStatement else {
        Issue.record("Expected InsertStatement")
        return
    }
    guard case .select = insert.source else {
        Issue.record("Expected select source")
        return
    }
    #expect(insert.returningClause != nil)

    let conflictInsert = try parseStatement(
        "INSERT INTO users (id, name) VALUES (1, 'Alice') ON CONFLICT (id) DO UPDATE SET name = 'Bob' WHERE id = 1 RETURNING id"
    )
    guard let conflict = conflictInsert as? InsertStatement else {
        Issue.record("Expected InsertStatement")
        return
    }
    #expect(conflict.onConflict != nil)
    #expect(conflict.returningClause != nil)

    let duplicateInsert = try parseStatement(
        "INSERT INTO users (id, name) VALUES (1, 'Alice') ON DUPLICATE KEY UPDATE name = 'Bob'"
    )
    guard let duplicate = duplicateInsert as? InsertStatement else {
        Issue.record("Expected InsertStatement")
        return
    }
    #expect(duplicate.onDuplicateKeyAssignments.count == 1)
}

@Test
func insertSupportsDefaultValues() throws {
    let parsed = try parseStatement("INSERT INTO users DEFAULT VALUES")
    guard let insert = parsed as? InsertStatement else {
        Issue.record("Expected InsertStatement")
        return
    }
    guard case .defaultValues = insert.source else {
        Issue.record("Expected default values source")
        return
    }
}

@Test
func updateAndDeleteSupportFromUsingAndReturning() throws {
    let updateParsed = try parseStatement(
        "UPDATE users SET role_name = roles.name FROM roles WHERE users.role_id = roles.id RETURNING users.id"
    )
    guard let update = updateParsed as? UpdateStatement else {
        Issue.record("Expected UpdateStatement")
        return
    }
    #expect(update.from != nil)
    #expect(update.returningClause != nil)

    let deleteParsed = try parseStatement(
        "DELETE FROM users USING roles WHERE users.role_id = roles.id RETURNING users.id"
    )
    guard let delete = deleteParsed as? DeleteStatement else {
        Issue.record("Expected DeleteStatement")
        return
    }
    #expect(delete.usingItems.count == 1)
    #expect(delete.returningClause != nil)
}

@Test
func deparserHandlesExtendedDmlStatements() {
    let deparser = StatementDeparser()

    let insert = InsertStatement(
        table: "archived_users",
        columns: ["id", "name"],
        source: .select(
            PlainSelect(
                selectItems: [
                    ExpressionSelectItem(expression: IdentifierExpression(name: "id")),
                    ExpressionSelectItem(expression: IdentifierExpression(name: "name"))
                ],
                from: TableFromItem(name: "users")
            )
        ),
        onConflict: InsertOnConflictClause(
            targetColumns: ["id"],
            action: .doUpdate(
                assignments: [UpdateAssignment(column: "name", value: StringLiteralExpression(value: "Bob"))],
                whereExpression: BinaryExpression(
                    left: IdentifierExpression(name: "id"),
                    operator: .equals,
                    right: NumberLiteralExpression(value: 1)
                )
            )
        ),
        returningClause: ReturningClause(items: [ExpressionSelectItem(expression: IdentifierExpression(name: "id"))])
    )
    #expect(
        deparser.deparse(insert)
            == "INSERT INTO archived_users (id, name) SELECT id, name FROM users ON CONFLICT (id) DO UPDATE SET name = 'Bob' WHERE id = 1 RETURNING id"
    )

    let update = UpdateStatement(
        table: "users",
        assignments: [UpdateAssignment(column: "role_name", value: IdentifierExpression(name: "roles.name"))],
        from: TableFromItem(name: "roles"),
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "users.role_id"),
            operator: .equals,
            right: IdentifierExpression(name: "roles.id")
        ),
        returningClause: ReturningClause(items: [ExpressionSelectItem(expression: IdentifierExpression(name: "users.id"))])
    )
    #expect(deparser.deparse(update) == "UPDATE users SET role_name = roles.name FROM roles WHERE users.role_id = roles.id RETURNING users.id")

    let delete = DeleteStatement(
        table: "users",
        usingItems: [TableFromItem(name: "roles")],
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "users.role_id"),
            operator: .equals,
            right: IdentifierExpression(name: "roles.id")
        ),
        returningClause: ReturningClause(items: [ExpressionSelectItem(expression: IdentifierExpression(name: "users.id"))])
    )
    #expect(deparser.deparse(delete) == "DELETE FROM users USING roles WHERE users.role_id = roles.id RETURNING users.id")
}

@Test
func updateParsesAdvancedExpressions() throws {
    let sql = "UPDATE users SET status = CASE WHEN score >= 90 THEN 'A' ELSE 'B' END, nickname = CAST(name AS TEXT), deleted_at = NULL WHERE id = $1 AND archived_at IS NULL AND score BETWEEN 10 AND 20 AND email LIKE ?"
    let parsed = try parseStatement(sql)

    guard let update = parsed as? UpdateStatement else {
        Issue.record("Expected UpdateStatement")
        return
    }

    #expect(update.assignments.count == 3)
    #expect(update.assignments[0].value is CaseExpression)
    #expect(update.assignments[1].value is CastExpression)
    #expect(update.assignments[2].value is NullLiteralExpression)
    #expect(update.whereExpression != nil)
}
