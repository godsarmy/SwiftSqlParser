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
            let rows = insert.values
                .map { "(\($0.map(expressionDeparser.deparse).joined(separator: ", ")))" }
                .joined(separator: ", ")
            return "INSERT INTO \(insert.table)\(columns) VALUES \(rows)"
        }

        if let update = statement as? UpdateStatement {
            let assignments = update.assignments
                .map { "\($0.column) = \(expressionDeparser.deparse($0.value))" }
                .joined(separator: ", ")
            if let whereExpression = update.whereExpression {
                return "UPDATE \(update.table) SET \(assignments) WHERE \(expressionDeparser.deparse(whereExpression))"
            }
            return "UPDATE \(update.table) SET \(assignments)"
        }

        if let delete = statement as? DeleteStatement {
            if let whereExpression = delete.whereExpression {
                return "DELETE FROM \(delete.table) WHERE \(expressionDeparser.deparse(whereExpression))"
            }
            return "DELETE FROM \(delete.table)"
        }

        if let create = statement as? CreateTableStatement {
            let columns = create.columns
                .map { "\($0.name) \($0.typeName)" }
                .joined(separator: ", ")
            return "CREATE TABLE \(create.table) (\(columns))"
        }

        if let alter = statement as? AlterTableStatement {
            switch alter.operation {
            case let .addColumn(column):
                return "ALTER TABLE \(alter.table) ADD COLUMN \(column.name) \(column.typeName)"
            case let .dropColumn(columnName):
                return "ALTER TABLE \(alter.table) DROP COLUMN \(columnName)"
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
}
