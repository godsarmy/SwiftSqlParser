public struct SelectDeparser {
  public let expressionDeparser: ExpressionDeparser

  public init(expressionDeparser: ExpressionDeparser = .init()) {
    self.expressionDeparser = expressionDeparser
  }

  public func deparse(_ statement: PlainSelect) -> String {
    let selectItems = statement.selectItems
      .map(deparseSelectItem)
      .joined(separator: ", ")
    var modifiers: [String] = []
    if statement.isDistinct, statement.distinctOnExpressions.isEmpty {
      modifiers.append("DISTINCT")
    }
    if statement.distinctOnExpressions.isEmpty == false {
      let distinctOn = statement.distinctOnExpressions.map(expressionDeparser.deparse).joined(
        separator: ", ")
      modifiers.append("DISTINCT ON (\(distinctOn))")
    }
    if let top = statement.top {
      modifiers.append("TOP \(top)")
    }
    if let selectQualifier = statement.selectQualifier {
      switch selectQualifier {
      case .asStruct:
        modifiers.append("AS STRUCT")
      case .asValue:
        modifiers.append("AS VALUE")
      }
    }

    let modifierSql = modifiers.isEmpty ? "" : "\(modifiers.joined(separator: " ")) "
    var query = "SELECT \(modifierSql)\(selectItems)"

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
    let joinKeyword =
      switch join.type {
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
      guard let allColumns = item as? AllColumnsSelectItem else {
        return "*"
      }
      var sql = "*"
      if allColumns.exceptColumns.isEmpty == false {
        sql += " EXCEPT (\(allColumns.exceptColumns.joined(separator: ", ")))"
      }
      if allColumns.replacements.isEmpty == false {
        let replacements = allColumns.replacements.map { replacement in
          "\(expressionDeparser.deparse(replacement.expression)) AS \(replacement.alias)"
        }.joined(separator: ", ")
        sql += " REPLACE (\(replacements))"
      }
      return sql
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
      let timeTravelClause = table.timeTravelClause.map { " \($0)" } ?? ""
      let timeTravelClauseAfterAlias = table.timeTravelClauseAfterAlias.map { " \($0)" } ?? ""
      if let alias = table.alias {
        return "\(lateral)\(table.name)\(timeTravelClause) \(alias)\(timeTravelClauseAfterAlias)"
      }
      return "\(lateral)\(table.name)\(timeTravelClause)"
    }

    if let subquery = item as? SubqueryFromItem {
      let statementDeparser = StatementDeparser(expressionDeparser: expressionDeparser)
      let lateral = subquery.isLateral ? "LATERAL " : ""
      if let alias = subquery.alias {
        return "\(lateral)(\(statementDeparser.deparse(subquery.statement))) \(alias)"
      }
      return "\(lateral)(\(statementDeparser.deparse(subquery.statement)))"
    }

    if let pivot = item as? PivotFromItem {
      let aggregate = expressionDeparser.deparse(pivot.aggregateFunction)
      let values = pivot.values.map { value in
        let expression = expressionDeparser.deparse(value.expression)
        if let alias = value.alias {
          return "\(expression) AS \(alias)"
        }
        return expression
      }.joined(separator: ", ")
      let alias = pivot.alias.map { " \($0)" } ?? ""
      return
        "\(deparseFromItem(pivot.source)) PIVOT (\(aggregate) FOR \(pivot.pivotColumn) IN (\(values)))\(alias)"
    }

    if let unpivot = item as? UnpivotFromItem {
      let alias = unpivot.alias.map { " \($0)" } ?? ""
      return
        "\(deparseFromItem(unpivot.source)) UNPIVOT (\(unpivot.valueColumn) FOR \(unpivot.nameColumn) IN (\(unpivot.columns.joined(separator: ", "))))\(alias)"
    }

    return "<unsupported-from-item>"
  }
}
