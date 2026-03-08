public struct SelectDeparser {
    public let expressionDeparser: ExpressionDeparser

    public init(expressionDeparser: ExpressionDeparser = .init()) {
        self.expressionDeparser = expressionDeparser
    }

    public func deparse(_ statement: PlainSelect) -> String {
        let selectItems = statement.selectItems
            .map(deparseSelectItem)
            .joined(separator: ", ")
        var query = "SELECT \(selectItems)"

        query += " FROM \(deparseFromItem(statement.from))"

        if statement.joins.isEmpty == false {
            let joins = statement.joins.map(deparseJoin).joined(separator: " ")
            query += " \(joins)"
        }

        if let whereExpression = statement.whereExpression {
            query += " WHERE \(expressionDeparser.deparse(whereExpression))"
        }

        return query
    }

    private func deparseJoin(_ join: Join) -> String {
        let joinKeyword = switch join.type {
        case .inner: "INNER JOIN"
        case .left: "LEFT JOIN"
        case .right: "RIGHT JOIN"
        case .full: "FULL JOIN"
        case .cross: "CROSS JOIN"
        }

        if let onExpression = join.onExpression {
            return "\(joinKeyword) \(deparseFromItem(join.fromItem)) ON \(expressionDeparser.deparse(onExpression))"
        }

        return "\(joinKeyword) \(deparseFromItem(join.fromItem))"
    }

    private func deparseSelectItem(_ item: any SelectItem) -> String {
        if item is AllColumnsSelectItem {
            return "*"
        }

        if let expressionItem = item as? ExpressionSelectItem {
            let expressionText = expressionDeparser.deparse(expressionItem.expression)
            if let alias = expressionItem.alias {
                return "\(expressionText) AS \(alias)"
            }
            return expressionText
        }

        return "<unsupported-select-item>"
    }

    private func deparseFromItem(_ item: any FromItem) -> String {
        if let table = item as? TableFromItem {
            if let alias = table.alias {
                return "\(table.name) \(alias)"
            }
            return table.name
        }

        if let subquery = item as? SubqueryFromItem {
            let statementDeparser = StatementDeparser(expressionDeparser: expressionDeparser)
            if let alias = subquery.alias {
                return "(\(statementDeparser.deparse(subquery.statement))) \(alias)"
            }
            return "(\(statementDeparser.deparse(subquery.statement)))"
        }

        return "<unsupported-from-item>"
    }
}
