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

        if let values = statement as? ValuesSelect {
            let rows = values.rows.map { "(\($0.map(expressionDeparser.deparse).joined(separator: ", ")))" }.joined(separator: ", ")
            return "VALUES \(rows)"
        }

        if let withSelect = statement as? WithSelect {
            let ctes = withSelect.expressions
                .map { "\($0.name) AS (\(deparse($0.statement)))" }
                .joined(separator: ", ")
            return "WITH \(ctes) \(deparse(withSelect.body))"
        }

        if let setOperation = statement as? SetOperationSelect {
            let operationKeyword = switch setOperation.operation {
            case .union: "UNION"
            case .intersect: "INTERSECT"
            case .except: "EXCEPT"
            }
            let allKeyword = setOperation.isAll ? " ALL" : ""
            return "\(deparse(setOperation.left)) \(operationKeyword)\(allKeyword) \(deparse(setOperation.right))"
        }

        if let insert = statement as? InsertStatement {
            let columns = insert.columns.isEmpty ? "" : " (\(insert.columns.joined(separator: ", ")))"
            var sql = "INSERT INTO \(insert.table)\(columns)"
            switch insert.source {
            case let .values(rows):
                let rowSql = rows
                    .map { "(\($0.map(expressionDeparser.deparse).joined(separator: ", ")))" }
                    .joined(separator: ", ")
                sql += " VALUES \(rowSql)"
            case let .select(statement):
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

        if let update = statement as? UpdateStatement {
            let selectDeparser = SelectDeparser(expressionDeparser: expressionDeparser)
            let assignments = update.assignments
                .map { "\($0.column) = \(expressionDeparser.deparse($0.value))" }
                .joined(separator: ", ")
            var sql = "UPDATE \(update.table) SET \(assignments)"
            if let from = update.from {
                let joins = update.fromJoins.isEmpty ? "" : " \(update.fromJoins.map(selectDeparser.deparseJoin).joined(separator: " "))"
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
                let usingItems = delete.usingItems.map(selectDeparser.deparseFromItem).joined(separator: ", ")
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
            return "CREATE \(unique)INDEX \(createIndex.name) ON \(createIndex.table) (\(createIndex.columns.joined(separator: ", ")))"
        }

        if let createView = statement as? CreateViewStatement {
            return "CREATE VIEW \(createView.name) AS \(deparse(createView.select))"
        }

        if let alter = statement as? AlterTableStatement {
            switch alter.operation {
            case let .addColumn(column):
                return "ALTER TABLE \(alter.table) ADD COLUMN \(deparseColumnDefinition(column))"
            case let .dropColumn(columnName):
                return "ALTER TABLE \(alter.table) DROP COLUMN \(columnName)"
            case let .renameColumn(oldName, newName):
                return "ALTER TABLE \(alter.table) RENAME COLUMN \(oldName) TO \(newName)"
            case let .renameTable(newName):
                return "ALTER TABLE \(alter.table) RENAME TO \(newName)"
            case let .addConstraint(constraint):
                return "ALTER TABLE \(alter.table) ADD \(deparseTableConstraint(constraint))"
            case let .dropConstraint(name):
                return "ALTER TABLE \(alter.table) DROP CONSTRAINT \(name)"
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
        let target = clause.targetColumns.isEmpty ? "" : " (\(clause.targetColumns.joined(separator: ", ")))"
        switch clause.action {
        case .doNothing:
            return " ON CONFLICT\(target) DO NOTHING"
        case let .doUpdate(assignments, whereExpression):
            let assignmentSql = assignments
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
        case let .references(table, columns):
            let columnList = columns.isEmpty ? "" : " (\(columns.joined(separator: ", ")))"
            return "REFERENCES \(table)\(columnList)"
        case let .check(expression):
            return "CHECK (\(expressionDeparser.deparse(expression)))"
        }
    }

    private func deparseTableConstraint(_ constraint: TableConstraintDefinition) -> String {
        let prefix = constraint.name.map { "CONSTRAINT \($0) " } ?? ""
        switch constraint.kind {
        case let .primaryKey(columns):
            return "\(prefix)PRIMARY KEY (\(columns.joined(separator: ", ")))"
        case let .foreignKey(columns, referencesTable, referencesColumns):
            return "\(prefix)FOREIGN KEY (\(columns.joined(separator: ", "))) REFERENCES \(referencesTable) (\(referencesColumns.joined(separator: ", ")))"
        case let .check(expression):
            return "\(prefix)CHECK (\(expressionDeparser.deparse(expression)))"
        }
    }
}
