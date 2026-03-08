import Foundation

public struct ExpressionDeparser {
  public init() {}

  public func deparse(_ expression: any Expression) -> String {
    if let raw = expression as? RawExpression {
      return raw.sql
    }

    if let identifier = expression as? IdentifierExpression {
      return identifier.name
    }

    if let stringLiteral = expression as? StringLiteralExpression {
      let escaped = stringLiteral.value.replacingOccurrences(of: "'", with: "''")
      return "'\(escaped)'"
    }

    if expression is NullLiteralExpression {
      return "NULL"
    }

    if let numberLiteral = expression as? NumberLiteralExpression {
      if numberLiteral.value.rounded() == numberLiteral.value {
        return String(Int(numberLiteral.value))
      }
      return String(numberLiteral.value)
    }

    if let unary = expression as? UnaryExpression {
      let op =
        switch unary.operator {
        case .plus: "+"
        case .minus: "-"
        case .not: "NOT "
        }
      return "\(op)\(deparse(unary.expression))"
    }

    if let binary = expression as? BinaryExpression {
      let op =
        switch binary.operator {
        case .equals: "="
        case .notEquals: "<>"
        case .lessThan: "<"
        case .lessThanOrEquals: "<="
        case .greaterThan: ">"
        case .greaterThanOrEquals: ">="
        case .like: "LIKE"
        case .ilike: "ILIKE"
        case .and: "AND"
        case .or: "OR"
        case .plus: "+"
        case .minus: "-"
        case .multiply: "*"
        case .divide: "/"
        }
      return "\(deparse(binary.left)) \(op) \(deparse(binary.right))"
    }

    if let isNull = expression as? IsNullExpression {
      return isNull.isNegated
        ? "\(deparse(isNull.expression)) IS NOT NULL" : "\(deparse(isNull.expression)) IS NULL"
    }

    if let inList = expression as? InListExpression {
      let values = inList.values.map(deparse).joined(separator: ", ")
      let keyword = inList.isNegated ? "NOT IN" : "IN"
      return "\(deparse(inList.expression)) \(keyword) (\(values))"
    }

    if let between = expression as? BetweenExpression {
      let keyword = between.isNegated ? "NOT BETWEEN" : "BETWEEN"
      return
        "\(deparse(between.expression)) \(keyword) \(deparse(between.lowerBound)) AND \(deparse(between.upperBound))"
    }

    if let exists = expression as? ExistsExpression {
      return "EXISTS (\(StatementDeparser(expressionDeparser: self).deparse(exists.statement)))"
    }

    if let function = expression as? FunctionExpression {
      let args = function.arguments.map(deparse).joined(separator: ", ")
      var sql = "\(function.name)(\(args))"
      if let overClause = function.overClause {
        sql += " OVER \(deparseWindowSpecification(overClause))"
      }
      return sql
    }

    if let caseExpression = expression as? CaseExpression {
      var components = ["CASE"]
      if let baseExpression = caseExpression.baseExpression {
        components.append(deparse(baseExpression))
      }
      for whenClause in caseExpression.whenClauses {
        components.append(
          "WHEN \(deparse(whenClause.condition)) THEN \(deparse(whenClause.result))")
      }
      if let elseExpression = caseExpression.elseExpression {
        components.append("ELSE \(deparse(elseExpression))")
      }
      components.append("END")
      return components.joined(separator: " ")
    }

    if let cast = expression as? CastExpression {
      switch cast.style {
      case .standard:
        return "CAST(\(deparse(cast.expression)) AS \(cast.typeName))"
      case .postgres:
        return "\(deparse(cast.expression))::\(cast.typeName)"
      }
    }

    if let placeholder = expression as? PlaceholderExpression {
      return placeholder.token
    }

    if let subquery = expression as? SubqueryExpression {
      return "(\(StatementDeparser(expressionDeparser: self).deparse(subquery.statement)))"
    }

    return "<unsupported-expression>"
  }

  private func deparseWindowSpecification(_ specification: WindowSpecification) -> String {
    if let namedWindow = specification.namedWindow {
      return namedWindow
    }

    var parts: [String] = []
    if specification.partitionBy.isEmpty == false {
      parts.append("PARTITION BY \(specification.partitionBy.map(deparse).joined(separator: ", "))")
    }
    if specification.orderBy.isEmpty == false {
      let orderBy = specification.orderBy.map { element in
        let expression = deparse(element.expression)
        switch element.direction {
        case .ascending: return "\(expression) ASC"
        case .descending: return "\(expression) DESC"
        case nil: return expression
        }
      }.joined(separator: ", ")
      parts.append("ORDER BY \(orderBy)")
    }
    return "(\(parts.joined(separator: " ")))"
  }
}
