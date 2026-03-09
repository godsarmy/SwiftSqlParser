import Testing

@testable import SwiftSqlParser

@Test
func upstreamCreateTableCompositeConstraintCaseParsesAndDeparses() throws {
  let sql =
    "CREATE TABLE public.order_items (order_id INT NOT NULL, item_id INT NOT NULL, sku TEXT UNIQUE, CONSTRAINT order_items_pk PRIMARY KEY (order_id, item_id), CONSTRAINT order_items_order_fk FOREIGN KEY (order_id, item_id) REFERENCES public.orders (id, item_id))"
  let parsed = try parseStatement(sql)

  guard let create = parsed as? CreateTableStatement else {
    Issue.record("Expected CreateTableStatement")
    return
  }

  #expect(create.table == "public.order_items")
  #expect(create.columns.count == 3)
  #expect(create.constraints.count == 2)

  guard case .primaryKey(let columns) = create.constraints[0].kind else {
    Issue.record("Expected primary key constraint")
    return
  }
  #expect(columns == ["order_id", "item_id"])

  guard
    case .foreignKey(let columns, let referencesTable, let referencesColumns) = create.constraints[
      1
    ].kind
  else {
    Issue.record("Expected foreign key constraint")
    return
  }
  #expect(columns == ["order_id", "item_id"])
  #expect(referencesTable == "public.orders")
  #expect(referencesColumns == ["id", "item_id"])
  #expect(StatementDeparser().deparse(create) == sql)
}

@Test
func upstreamCreateViewWithSetOperationParsesAndDeparses() throws {
  let sql =
    "CREATE VIEW active_entities AS SELECT id FROM users UNION ALL SELECT id FROM service_accounts"
  let parsed = try parseStatement(sql)

  guard let view = parsed as? CreateViewStatement else {
    Issue.record("Expected CreateViewStatement")
    return
  }

  #expect(view.name == "active_entities")
  #expect(view.select is SetOperationSelect)
  #expect(StatementDeparser().deparse(view) == sql)
}

@Test
func upstreamAlterDropAndTruncateCasesParseAndDeparse() throws {
  let alterSql =
    "ALTER TABLE users ADD CONSTRAINT users_name_check CHECK (name <> '' AND active = 1)"
  let alterParsed = try parseStatement(alterSql)
  guard let alter = alterParsed as? AlterTableStatement else {
    Issue.record("Expected AlterTableStatement")
    return
  }

  guard case .addConstraint(let constraint) = alter.operation else {
    Issue.record("Expected add constraint operation")
    return
  }
  #expect(constraint.name == "users_name_check")
  #expect(StatementDeparser().deparse(alter) == alterSql)

  let dropSql = "DROP TABLE public.order_items"
  let dropParsed = try parseStatement(dropSql)
  guard let drop = dropParsed as? DropTableStatement else {
    Issue.record("Expected DropTableStatement")
    return
  }
  #expect(drop.table == "public.order_items")
  #expect(StatementDeparser().deparse(drop) == dropSql)

  let truncateSql = "TRUNCATE public.order_items"
  let truncateParsed = try parseStatement(truncateSql)
  guard let truncate = truncateParsed as? TruncateTableStatement else {
    Issue.record("Expected TruncateTableStatement")
    return
  }
  #expect(truncate.table == "public.order_items")
  #expect(StatementDeparser().deparse(truncate) == "TRUNCATE TABLE public.order_items")
}
