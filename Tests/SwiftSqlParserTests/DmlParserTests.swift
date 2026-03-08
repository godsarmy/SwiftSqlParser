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
    #expect(insert.values.count == 1)
    #expect(insert.values[0].count == 2)
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
