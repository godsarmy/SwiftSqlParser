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

  let createPolicy = CreatePolicyStatement(
    name: "users_policy",
    table: "users",
    scope: .restrictive,
    command: .select,
    roles: ["app_user"],
    usingExpression: RawExpression(sql: "tenant_id = current_tenant()"),
    withCheckExpression: RawExpression(sql: "tenant_id = current_tenant()")
  )
  #expect(
    deparser.deparse(createPolicy)
      == "CREATE POLICY users_policy ON users AS RESTRICTIVE FOR SELECT TO app_user USING (tenant_id = current_tenant()) WITH CHECK (tenant_id = current_tenant())"
  )

  let enableRls = AlterTableStatement(table: "users", operation: .rowLevelSecurity(.enable))
  #expect(deparser.deparse(enableRls) == "ALTER TABLE users ENABLE ROW LEVEL SECURITY")
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

@Test
func postgresCreatePolicyParsesWhenDialectEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.postgres])
  let parsed = try parseStatement(
    "CREATE POLICY users_policy ON users AS RESTRICTIVE FOR SELECT TO app_user USING (tenant_id = current_tenant()) WITH CHECK (tenant_id = current_tenant())",
    options: options
  )
  guard let policy = parsed as? CreatePolicyStatement else {
    Issue.record("Expected CreatePolicyStatement")
    return
  }

  #expect(policy.name == "users_policy")
  #expect(policy.table == "users")
  #expect(policy.scope == .restrictive)
  #expect(policy.command == .select)
  #expect(policy.roles == ["app_user"])
  #expect(policy.usingExpression != nil)
  #expect(policy.withCheckExpression != nil)
}

@Test
func postgresCreatePolicySupportsMinimalForm() throws {
  let options = ParserOptions(dialectFeatures: [.postgres])
  let parsed = try parseStatement("CREATE POLICY users_policy ON users", options: options)
  guard let policy = parsed as? CreatePolicyStatement else {
    Issue.record("Expected CreatePolicyStatement")
    return
  }

  #expect(policy.scope == nil)
  #expect(policy.command == nil)
  #expect(policy.roles.isEmpty)
  #expect(policy.usingExpression == nil)
  #expect(policy.withCheckExpression == nil)
}

@Test
func postgresRlsAlterOperationsParseWhenDialectEnabled() throws {
  let options = ParserOptions(dialectFeatures: [.postgres])
  let enableParsed = try parseStatement(
    "ALTER TABLE users ENABLE ROW LEVEL SECURITY",
    options: options
  )
  let disableParsed = try parseStatement(
    "ALTER TABLE users DISABLE ROW LEVEL SECURITY",
    options: options
  )
  let forceParsed = try parseStatement(
    "ALTER TABLE users FORCE ROW LEVEL SECURITY",
    options: options
  )
  let noForceParsed = try parseStatement(
    "ALTER TABLE users NO FORCE ROW LEVEL SECURITY",
    options: options
  )

  guard let enable = enableParsed as? AlterTableStatement,
    let disable = disableParsed as? AlterTableStatement,
    let force = forceParsed as? AlterTableStatement,
    let noForce = noForceParsed as? AlterTableStatement
  else {
    Issue.record("Expected AlterTableStatement values")
    return
  }

  if case .rowLevelSecurity(let mode) = enable.operation {
    #expect(mode == .enable)
  } else {
    Issue.record("Expected enable row level security operation")
  }

  if case .rowLevelSecurity(let mode) = disable.operation {
    #expect(mode == .disable)
  } else {
    Issue.record("Expected disable row level security operation")
  }

  if case .rowLevelSecurity(let mode) = force.operation {
    #expect(mode == .force)
  } else {
    Issue.record("Expected force row level security operation")
  }

  if case .rowLevelSecurity(let mode) = noForce.operation {
    #expect(mode == .noForce)
  } else {
    Issue.record("Expected no force row level security operation")
  }
}

@Test
func deparserHandlesAllPostgresRlsModes() {
  let deparser = StatementDeparser()

  #expect(
    deparser.deparse(AlterTableStatement(table: "users", operation: .rowLevelSecurity(.enable)))
      == "ALTER TABLE users ENABLE ROW LEVEL SECURITY"
  )
  #expect(
    deparser.deparse(AlterTableStatement(table: "users", operation: .rowLevelSecurity(.disable)))
      == "ALTER TABLE users DISABLE ROW LEVEL SECURITY"
  )
  #expect(
    deparser.deparse(AlterTableStatement(table: "users", operation: .rowLevelSecurity(.force)))
      == "ALTER TABLE users FORCE ROW LEVEL SECURITY"
  )
  #expect(
    deparser.deparse(AlterTableStatement(table: "users", operation: .rowLevelSecurity(.noForce)))
      == "ALTER TABLE users NO FORCE ROW LEVEL SECURITY"
  )
}

@Test
func postgresPolicyAndRlsRequireDialectFlag() {
  #expect(throws: SqlParseError.self) {
    try parseStatement("CREATE POLICY users_policy ON users")
  }

  #expect(throws: SqlParseError.self) {
    try parseStatement("ALTER TABLE users ENABLE ROW LEVEL SECURITY")
  }
}
