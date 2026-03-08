public struct SelectDeparser {
    public let expressionDeparser: ExpressionDeparser

    public init(expressionDeparser: ExpressionDeparser = .init()) {
        self.expressionDeparser = expressionDeparser
    }

    public func deparse(_ statement: PlainSelect) -> String {
        let selectItems = statement.selectItems
            .map(deparseSelectItem)
            .joined(separator: ", ")
        var query = statement.isDistinct ? "SELECT DISTINCT \(selectItems)" : "SELECT \(selectItems)"

        query += " FROM \(deparseFromItem(statement.from))"

        if statement.joins.isEmpty == false {
            let joins = statement.joins.map(deparseJoin).joined(separator: " ")
            query += " \(joins)"
        }

        if let whereExpression = statement.whereExpression {
            query += " WHERE \(expressionDeparser.deparse(whereExpression))"
        }

        if statement.groupByExpressions.isEmpty == false {
            let groupBy = statement.groupByExpressions
                .map(expressionDeparser.deparse)
                .joined(separator: ", ")
            query += " GROUP BY \(groupBy)"
        }

        if let havingExpression = statement.havingExpression {
            query += " HAVING \(expressionDeparser.deparse(havingExpression))"
        }

        if let qualifyExpression = statement.qualifyExpression {
            query += " QUALIFY \(expressionDeparser.deparse(qualifyExpression))"
        }

        if statement.orderBy.isEmpty == false {
            let orderBy = statement.orderBy
                .map(deparseOrderByElement)
                .joined(separator: ", ")
            query += " ORDER BY \(orderBy)"
        }

        if let limit = statement.limit {
            query += " LIMIT \(limit)"
        }

        if let offset = statement.offset {
            query += " OFFSET \(offset)"
        }

        return query
    }

    private func deparseOrderByElement(_ element: OrderByElement) -> String {
        let expression = expressionDeparser.deparse(element.expression)
        switch element.direction {
        case .ascending:
            return "\(expression) ASC"
        case .descending:
            return "\(expression) DESC"
        case nil:
            return expression
        }
    }

    func deparseJoin(_ join: Join) -> String {
        let joinKeyword = switch join.type {
        case .inner: "INNER JOIN"
        case .left: "LEFT JOIN"
        case .right: "RIGHT JOIN"
        case .full: "FULL JOIN"
        case .cross: "CROSS JOIN"
        case .crossApply: "CROSS APPLY"
        case .outerApply: "OUTER APPLY"
        }

        let naturalPrefix = join.isNatural ? "NATURAL " : ""
        let base = "\(naturalPrefix)\(joinKeyword) \(deparseFromItem(join.fromItem))"

        if let onExpression = join.onExpression {
            return "\(base) ON \(expressionDeparser.deparse(onExpression))"
        }

        if join.usingColumns.isEmpty == false {
            return "\(base) USING (\(join.usingColumns.joined(separator: ", ")))"
        }

        return base
    }

    func deparseSelectItem(_ item: any SelectItem) -> String {
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

    func deparseFromItem(_ item: any FromItem) -> String {
        if let table = item as? TableFromItem {
            let lateral = table.isLateral ? "LATERAL " : ""
            if let alias = table.alias {
                return "\(lateral)\(table.name) \(alias)"
            }
            return "\(lateral)\(table.name)"
        }

        if let subquery = item as? SubqueryFromItem {
            let statementDeparser = StatementDeparser(expressionDeparser: expressionDeparser)
            let lateral = subquery.isLateral ? "LATERAL " : ""
            if let alias = subquery.alias {
                return "\(lateral)(\(statementDeparser.deparse(subquery.statement))) \(alias)"
            }
            return "\(lateral)(\(statementDeparser.deparse(subquery.statement)))"
        }

        return "<unsupported-from-item>"
    }
}
