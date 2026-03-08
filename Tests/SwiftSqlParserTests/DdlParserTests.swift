import Testing
@testable import SwiftSqlParser

@Test
func createTableParsesIntoCreateTableStatement() throws {
    let parsed = try parseStatement("CREATE TABLE users (id INT, name TEXT)")
    guard let create = parsed as? CreateTableStatement else {
        Issue.record("Expected CreateTableStatement")
        return
    }

    #expect(create.table == "users")
    #expect(create.columns.count == 2)
    #expect(create.columns[0] == TableColumnDefinition(name: "id", typeName: "INT"))
}

@Test
func alterTableParsesAddAndDropColumn() throws {
    let addParsed = try parseStatement("ALTER TABLE users ADD COLUMN email TEXT")
    guard let add = addParsed as? AlterTableStatement else {
        Issue.record("Expected AlterTableStatement")
        return
    }

    if case let .addColumn(column) = add.operation {
        #expect(column == TableColumnDefinition(name: "email", typeName: "TEXT"))
    } else {
        Issue.record("Expected add column operation")
    }

    let dropParsed = try parseStatement("ALTER TABLE users DROP COLUMN email")
    guard let drop = dropParsed as? AlterTableStatement else {
        Issue.record("Expected AlterTableStatement")
        return
    }

    if case let .dropColumn(columnName) = drop.operation {
        #expect(columnName == "email")
    } else {
        Issue.record("Expected drop column operation")
    }
}

@Test
func dropAndTruncateParseIntoDedicatedNodes() throws {
    let dropParsed = try parseStatement("DROP TABLE users")
    #expect(dropParsed is DropTableStatement)

    let truncateParsed = try parseStatement("TRUNCATE TABLE users")
    #expect(truncateParsed is TruncateTableStatement)
}

@Test
func deparserHandlesDdlStatements() {
    let deparser = StatementDeparser()

    let create = CreateTableStatement(
        table: "users",
        columns: [
            TableColumnDefinition(name: "id", typeName: "INT"),
            TableColumnDefinition(name: "name", typeName: "TEXT")
        ]
    )
    #expect(deparser.deparse(create) == "CREATE TABLE users (id INT, name TEXT)")

    let alter = AlterTableStatement(
        table: "users",
        operation: .addColumn(TableColumnDefinition(name: "email", typeName: "TEXT"))
    )
    #expect(deparser.deparse(alter) == "ALTER TABLE users ADD COLUMN email TEXT")

    let drop = DropTableStatement(table: "users")
    #expect(deparser.deparse(drop) == "DROP TABLE users")

    let truncate = TruncateTableStatement(table: "users")
    #expect(deparser.deparse(truncate) == "TRUNCATE TABLE users")
}
