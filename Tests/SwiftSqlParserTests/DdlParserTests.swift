import Testing

@testable import SwiftSqlParser

@Test
func createTableParsesIntoCreateTableStatement() throws {
  let parsed = try parseStatement(
    "CREATE TABLE users (id INT PRIMARY KEY, name TEXT DEFAULT 'anon' NOT NULL, role_id INT REFERENCES roles (id), CONSTRAINT users_name_check CHECK (name <> ''), PRIMARY KEY (id), FOREIGN KEY (role_id) REFERENCES roles (id))"
  )
  guard let create = parsed as? CreateTableStatement else {
    Issue.record("Expected CreateTableStatement")
    return
  }

  #expect(create.table == "users")
  #expect(create.columns.count == 3)
  #expect(create.constraints.count == 3)
  #expect(create.columns[0].constraints.contains(.primaryKey))
  #expect(create.columns[1].defaultExpression != nil)
  #expect(create.columns[1].constraints.contains(.notNull))
}

@Test
func alterTableParsesAddAndDropColumn() throws {
  let addParsed = try parseStatement("ALTER TABLE users ADD COLUMN email TEXT DEFAULT 'none'")
  guard let add = addParsed as? AlterTableStatement else {
    Issue.record("Expected AlterTableStatement")
    return
  }

  if case .addColumn(let column) = add.operation {
    #expect(column.name == "email")
    #expect(column.defaultExpression != nil)
  } else {
    Issue.record("Expected add column operation")
  }

  let dropParsed = try parseStatement("ALTER TABLE users DROP COLUMN email")
  guard let drop = dropParsed as? AlterTableStatement else {
    Issue.record("Expected AlterTableStatement")
    return
  }

  if case .dropColumn(let columnName) = drop.operation {
    #expect(columnName == "email")
  } else {
    Issue.record("Expected drop column operation")
  }

  let renameColumnParsed = try parseStatement(
    "ALTER TABLE users RENAME COLUMN email TO primary_email")
  guard let renameColumn = renameColumnParsed as? AlterTableStatement else {
    Issue.record("Expected AlterTableStatement")
    return
  }
  if case .renameColumn(let oldName, let newName) = renameColumn.operation {
    #expect(oldName == "email")
    #expect(newName == "primary_email")
  } else {
    Issue.record("Expected rename column operation")
  }

  let renameTableParsed = try parseStatement("ALTER TABLE users RENAME TO app_users")
  guard let renameTable = renameTableParsed as? AlterTableStatement else {
    Issue.record("Expected AlterTableStatement")
    return
  }
  if case .renameTable(let newName) = renameTable.operation {
    #expect(newName == "app_users")
  } else {
    Issue.record("Expected rename table operation")
  }

  let addConstraintParsed = try parseStatement(
    "ALTER TABLE users ADD CONSTRAINT users_pk PRIMARY KEY (id)")
  guard let addConstraint = addConstraintParsed as? AlterTableStatement else {
    Issue.record("Expected AlterTableStatement")
    return
  }
  if case .addConstraint(let constraint) = addConstraint.operation {
    #expect(constraint.name == "users_pk")
  } else {
    Issue.record("Expected add constraint operation")
  }

  let dropConstraintParsed = try parseStatement("ALTER TABLE users DROP CONSTRAINT users_pk")
  guard let dropConstraint = dropConstraintParsed as? AlterTableStatement else {
    Issue.record("Expected AlterTableStatement")
    return
  }
  if case .dropConstraint(let name) = dropConstraint.operation {
    #expect(name == "users_pk")
  } else {
    Issue.record("Expected drop constraint operation")
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
      TableColumnDefinition(name: "id", typeName: "INT", constraints: [.primaryKey]),
      TableColumnDefinition(
        name: "name", typeName: "TEXT", defaultExpression: StringLiteralExpression(value: "anon"),
        constraints: [.notNull]),
    ],
    constraints: [
      TableConstraintDefinition(kind: .check(RawExpression(sql: "name <> ''")))
    ]
  )
  #expect(
    deparser.deparse(create)
      == "CREATE TABLE users (id INT PRIMARY KEY, name TEXT DEFAULT 'anon' NOT NULL, CHECK (name <> ''))"
  )

  let createIndex = CreateIndexStatement(
    name: "users_name_idx", table: "users", columns: ["name"], isUnique: true)
  #expect(deparser.deparse(createIndex) == "CREATE UNIQUE INDEX users_name_idx ON users (name)")

  let createView = CreateViewStatement(
    name: "active_users",
    select: PlainSelect(
      selectItems: [ExpressionSelectItem(expression: IdentifierExpression(name: "id"))],
      from: TableFromItem(name: "users"),
      whereExpression: BinaryExpression(
        left: IdentifierExpression(name: "active"), operator: .equals,
        right: NumberLiteralExpression(value: 1))
    )
  )
  #expect(
    deparser.deparse(createView)
      == "CREATE VIEW active_users AS SELECT id FROM users WHERE active = 1")

  let alter = AlterTableStatement(
    table: "users",
    operation: .addColumn(
      TableColumnDefinition(
        name: "email", typeName: "TEXT", defaultExpression: StringLiteralExpression(value: "none")))
  )
  #expect(deparser.deparse(alter) == "ALTER TABLE users ADD COLUMN email TEXT DEFAULT 'none'")

  let renameColumn = AlterTableStatement(
    table: "users", operation: .renameColumn(oldName: "email", newName: "primary_email"))
  #expect(
    deparser.deparse(renameColumn) == "ALTER TABLE users RENAME COLUMN email TO primary_email")

  let renameTable = AlterTableStatement(table: "users", operation: .renameTable("app_users"))
  #expect(deparser.deparse(renameTable) == "ALTER TABLE users RENAME TO app_users")

  let addConstraint = AlterTableStatement(
    table: "users",
    operation: .addConstraint(
      TableConstraintDefinition(name: "users_pk", kind: .primaryKey(columns: ["id"])))
  )
  #expect(
    deparser.deparse(addConstraint) == "ALTER TABLE users ADD CONSTRAINT users_pk PRIMARY KEY (id)")

  let drop = DropTableStatement(table: "users")
  #expect(deparser.deparse(drop) == "DROP TABLE users")

  let truncate = TruncateTableStatement(table: "users")
  #expect(deparser.deparse(truncate) == "TRUNCATE TABLE users")
}

@Test
func createIndexParsesIntoDedicatedNode() throws {
  let indexParsed = try parseStatement("CREATE UNIQUE INDEX users_name_idx ON users (name)")
  guard let index = indexParsed as? CreateIndexStatement else {
    Issue.record("Expected CreateIndexStatement")
    return
  }
  #expect(index.isUnique)
  #expect(index.columns == ["name"])
}

@Test
func createViewParsesIntoDedicatedNode() throws {
  let viewParsed = try parseStatement(
    "CREATE VIEW active_users AS SELECT id FROM users WHERE active = 1")
  guard let view = viewParsed as? CreateViewStatement else {
    Issue.record("Expected CreateViewStatement")
    return
  }
  #expect(view.name == "active_users")
  #expect(view.select is PlainSelect)
}
