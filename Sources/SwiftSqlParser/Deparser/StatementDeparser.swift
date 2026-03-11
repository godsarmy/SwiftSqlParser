public struct StatementDeparser {
  public let expressionDeparser: ExpressionDeparser

  public init(expressionDeparser: ExpressionDeparser = .init()) {
    self.expressionDeparser = expressionDeparser
  }

  public func deparse(_ statement: any Statement) -> String {
    if let raw = statement as? RawStatement {
      return raw.sql
    }

    if let select = statement as? PlainSelect {
      return SelectDeparser(expressionDeparser: expressionDeparser).deparse(select)
    }

    if let unsupported = statement as? UnsupportedStatement {
      return unsupported.sql
    }

    if let explain = statement as? ExplainStatement {
      return "EXPLAIN \(deparse(explain.statement))"
    }

    if let show = statement as? ShowStatement {
      return "SHOW \(show.subject)"
    }

    if let set = statement as? SetStatement {
      return "SET \(set.name) = \(expressionDeparser.deparse(set.value))"
    }

    if let reset = statement as? ResetStatement {
      return "RESET \(reset.name)"
    }

    if let use = statement as? UseStatement {
      return "USE \(use.target)"
    }

    if let values = statement as? ValuesSelect {
      let rows = values.rows.map {
        "(\($0.map(expressionDeparser.deparse).joined(separator: ", ")))"
      }.joined(separator: ", ")
      return "VALUES \(rows)"
    }

    if let withSelect = statement as? WithSelect {
      let ctes = withSelect.expressions
        .map { "\($0.name) AS (\(deparse($0.statement)))" }
        .joined(separator: ", ")
      return "WITH \(ctes) \(deparse(withSelect.body))"
    }

    if let setOperation = statement as? SetOperationSelect {
      let operationKeyword =
        switch setOperation.operation {
        case .union: "UNION"
        case .intersect: "INTERSECT"
        case .except: "EXCEPT"
        }
      let allKeyword = setOperation.isAll ? " ALL" : ""
      return
        "\(deparse(setOperation.left)) \(operationKeyword)\(allKeyword) \(deparse(setOperation.right))"
    }

    if let merge = statement as? MergeStatement {
      var sql = "MERGE INTO \(merge.targetTable)"
      if let alias = merge.targetAlias {
        sql += " \(alias)"
      }
      sql += " USING \(deparse(merge.source))"
      if let sourceAlias = merge.sourceAlias {
        sql += " \(sourceAlias)"
      }
      sql += " ON \(expressionDeparser.deparse(merge.onCondition))"
      for clause in merge.clauses {
        sql += clause.isMatched ? " WHEN MATCHED" : " WHEN NOT MATCHED"
        if let predicate = clause.predicate {
          sql += " AND \(predicate)"
        }
        sql += " THEN \(clause.action)"
      }
      return sql
    }

    if let replace = statement as? ReplaceStatement {
      let columns = replace.columns.isEmpty ? "" : " (\(replace.columns.joined(separator: ", ")))"
      var sql = "REPLACE INTO \(replace.table)\(columns)"
      switch replace.source {
      case .values(let rows):
        let rowSql =
          rows
          .map { "(\($0.map(expressionDeparser.deparse).joined(separator: ", ")))" }
          .joined(separator: ", ")
        sql += " VALUES \(rowSql)"
      case .select(let statement):
        sql += " \(deparse(statement))"
      case .defaultValues:
        sql += " DEFAULT VALUES"
      }
      return sql
    }

    if let insert = statement as? InsertStatement {
      let columns = insert.columns.isEmpty ? "" : " (\(insert.columns.joined(separator: ", ")))"
      var sql = "INSERT INTO \(insert.table)\(columns)"
      switch insert.source {
      case .values(let rows):
        let rowSql =
          rows
          .map { "(\($0.map(expressionDeparser.deparse).joined(separator: ", ")))" }
          .joined(separator: ", ")
        sql += " VALUES \(rowSql)"
      case .select(let statement):
        sql += " \(deparse(statement))"
      case .defaultValues:
        sql += " DEFAULT VALUES"
      }

      if let onConflict = insert.onConflict {
        sql += deparseOnConflictClause(onConflict)
      }

      if insert.onDuplicateKeyAssignments.isEmpty == false {
        let assignments = insert.onDuplicateKeyAssignments
          .map { "\($0.column) = \(expressionDeparser.deparse($0.value))" }
          .joined(separator: ", ")
        sql += " ON DUPLICATE KEY UPDATE \(assignments)"
      }

      if let returningClause = insert.returningClause {
        sql += " RETURNING \(deparseReturningClause(returningClause))"
      }

      return sql
    }

    if let upsert = statement as? UpsertStatement {
      let columns = upsert.columns.isEmpty ? "" : " (\(upsert.columns.joined(separator: ", ")))"
      var sql = "UPSERT INTO \(upsert.table)\(columns)"
      switch upsert.source {
      case .values(let rows):
        let rowSql =
          rows
          .map { "(\($0.map(expressionDeparser.deparse).joined(separator: ", ")))" }
          .joined(separator: ", ")
        sql += " VALUES \(rowSql)"
      case .select(let statement):
        sql += " \(deparse(statement))"
      case .defaultValues:
        sql += " DEFAULT VALUES"
      }

      if let onConflict = upsert.onConflict {
        sql += deparseOnConflictClause(onConflict)
      }

      if upsert.onDuplicateKeyAssignments.isEmpty == false {
        let assignments = upsert.onDuplicateKeyAssignments
          .map { "\($0.column) = \(expressionDeparser.deparse($0.value))" }
          .joined(separator: ", ")
        sql += " ON DUPLICATE KEY UPDATE \(assignments)"
      }

      if let returningClause = upsert.returningClause {
        sql += " RETURNING \(deparseReturningClause(returningClause))"
      }

      return sql
    }

    if let update = statement as? UpdateStatement {
      let selectDeparser = SelectDeparser(expressionDeparser: expressionDeparser)
      let assignments = update.assignments
        .map { "\($0.column) = \(expressionDeparser.deparse($0.value))" }
        .joined(separator: ", ")
      var sql = "UPDATE \(update.table) SET \(assignments)"
      if let from = update.from {
        let joins =
          update.fromJoins.isEmpty
          ? "" : " \(update.fromJoins.map(selectDeparser.deparseJoin).joined(separator: " "))"
        sql += " FROM \(selectDeparser.deparseFromItem(from))\(joins)"
      }
      if let whereExpression = update.whereExpression {
        sql += " WHERE \(expressionDeparser.deparse(whereExpression))"
      }
      if let returningClause = update.returningClause {
        sql += " RETURNING \(deparseReturningClause(returningClause))"
      }
      return sql
    }

    if let delete = statement as? DeleteStatement {
      let selectDeparser = SelectDeparser(expressionDeparser: expressionDeparser)
      var sql = "DELETE FROM \(delete.table)"
      if delete.usingItems.isEmpty == false {
        let usingItems = delete.usingItems.map(selectDeparser.deparseFromItem).joined(
          separator: ", ")
        sql += " USING \(usingItems)"
      }
      if let whereExpression = delete.whereExpression {
        sql += " WHERE \(expressionDeparser.deparse(whereExpression))"
      }
      if let returningClause = delete.returningClause {
        sql += " RETURNING \(deparseReturningClause(returningClause))"
      }
      return sql
    }

    if let create = statement as? CreateTableStatement {
      let columns = create.columns.map(deparseColumnDefinition)
      let constraints = create.constraints.map(deparseTableConstraint)
      let elements = (columns + constraints).joined(separator: ", ")
      return "CREATE TABLE \(create.table) (\(elements))"
    }

    if let createIndex = statement as? CreateIndexStatement {
      let unique = createIndex.isUnique ? "UNIQUE " : ""
      return
        "CREATE \(unique)INDEX \(createIndex.name) ON \(createIndex.table) (\(createIndex.columns.joined(separator: ", ")))"
    }

    if let createView = statement as? CreateViewStatement {
      return "CREATE VIEW \(createView.name) AS \(deparse(createView.select))"
    }

    if let createPolicy = statement as? CreatePolicyStatement {
      var sql = "CREATE POLICY \(createPolicy.name) ON \(createPolicy.table)"
      if let scope = createPolicy.scope {
        sql += " AS \(scope == .permissive ? "PERMISSIVE" : "RESTRICTIVE")"
      }
      if let command = createPolicy.command {
        sql += " FOR \(command.rawValue.uppercased())"
      }
      if createPolicy.roles.isEmpty == false {
        sql += " TO \(createPolicy.roles.joined(separator: ", "))"
      }
      if let usingExpression = createPolicy.usingExpression {
        sql += " USING (\(expressionDeparser.deparse(usingExpression)))"
      }
      if let withCheckExpression = createPolicy.withCheckExpression {
        sql += " WITH CHECK (\(expressionDeparser.deparse(withCheckExpression)))"
      }
      return sql
    }

    if let alter = statement as? AlterTableStatement {
      switch alter.operation {
      case .addColumn(let column):
        return "ALTER TABLE \(alter.table) ADD COLUMN \(deparseColumnDefinition(column))"
      case .dropColumn(let columnName):
        return "ALTER TABLE \(alter.table) DROP COLUMN \(columnName)"
      case .renameColumn(let oldName, let newName):
        return "ALTER TABLE \(alter.table) RENAME COLUMN \(oldName) TO \(newName)"
      case .renameTable(let newName):
        return "ALTER TABLE \(alter.table) RENAME TO \(newName)"
      case .addConstraint(let constraint):
        return "ALTER TABLE \(alter.table) ADD \(deparseTableConstraint(constraint))"
      case .dropConstraint(let name):
        return "ALTER TABLE \(alter.table) DROP CONSTRAINT \(name)"
      case .rowLevelSecurity(let mode):
        switch mode {
        case .enable:
          return "ALTER TABLE \(alter.table) ENABLE ROW LEVEL SECURITY"
        case .disable:
          return "ALTER TABLE \(alter.table) DISABLE ROW LEVEL SECURITY"
        case .force:
          return "ALTER TABLE \(alter.table) FORCE ROW LEVEL SECURITY"
        case .noForce:
          return "ALTER TABLE \(alter.table) NO FORCE ROW LEVEL SECURITY"
        }
      }
    }

    if let drop = statement as? DropTableStatement {
      return "DROP TABLE \(drop.table)"
    }

    if let truncate = statement as? TruncateTableStatement {
      return "TRUNCATE TABLE \(truncate.table)"
    }

    return "<unsupported-statement>"
  }

  private func deparseReturningClause(_ clause: ReturningClause) -> String {
    let selectDeparser = SelectDeparser(expressionDeparser: expressionDeparser)
    return clause.items.map(selectDeparser.deparseSelectItem).joined(separator: ", ")
  }

  private func deparseOnConflictClause(_ clause: InsertOnConflictClause) -> String {
    let target =
      clause.targetColumns.isEmpty ? "" : " (\(clause.targetColumns.joined(separator: ", ")))"
    switch clause.action {
    case .doNothing:
      return " ON CONFLICT\(target) DO NOTHING"
    case .doUpdate(let assignments, let whereExpression):
      let assignmentSql =
        assignments
        .map { "\($0.column) = \(expressionDeparser.deparse($0.value))" }
        .joined(separator: ", ")
      let whereSql = whereExpression.map { " WHERE \(expressionDeparser.deparse($0))" } ?? ""
      return " ON CONFLICT\(target) DO UPDATE SET \(assignmentSql)\(whereSql)"
    }
  }

  private func deparseColumnDefinition(_ column: TableColumnDefinition) -> String {
    var parts = ["\(column.name) \(column.typeName)"]
    if let defaultExpression = column.defaultExpression {
      parts.append("DEFAULT \(expressionDeparser.deparse(defaultExpression))")
    }
    parts.append(contentsOf: column.constraints.map(deparseColumnConstraint))
    return parts.joined(separator: " ")
  }

  private func deparseColumnConstraint(_ constraint: ColumnConstraint) -> String {
    switch constraint {
    case .notNull:
      return "NOT NULL"
    case .primaryKey:
      return "PRIMARY KEY"
    case .unique:
      return "UNIQUE"
    case .references(let table, let columns):
      let columnList = columns.isEmpty ? "" : " (\(columns.joined(separator: ", ")))"
      return "REFERENCES \(table)\(columnList)"
    case .check(let expression):
      return "CHECK (\(expressionDeparser.deparse(expression)))"
    }
  }

  private func deparseTableConstraint(_ constraint: TableConstraintDefinition) -> String {
    let prefix = constraint.name.map { "CONSTRAINT \($0) " } ?? ""
    switch constraint.kind {
    case .primaryKey(let columns):
      return "\(prefix)PRIMARY KEY (\(columns.joined(separator: ", ")))"
    case .foreignKey(let columns, let referencesTable, let referencesColumns):
      return
        "\(prefix)FOREIGN KEY (\(columns.joined(separator: ", "))) REFERENCES \(referencesTable) (\(referencesColumns.joined(separator: ", ")))"
    case .check(let expression):
      return "\(prefix)CHECK (\(expressionDeparser.deparse(expression)))"
    }
  }
}
