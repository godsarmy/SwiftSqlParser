import Foundation

public struct ExpressionDeparser {
    public init() {}

    public func deparse(_ expression: any Expression) -> String {
        if let identifier = expression as? IdentifierExpression {
            return identifier.name
        }

        if let stringLiteral = expression as? StringLiteralExpression {
            let escaped = stringLiteral.value.replacingOccurrences(of: "'", with: "''")
            return "'\(escaped)'"
        }

        if let numberLiteral = expression as? NumberLiteralExpression {
            if numberLiteral.value.rounded() == numberLiteral.value {
                return String(Int(numberLiteral.value))
            }
            return String(numberLiteral.value)
        }

        if let unary = expression as? UnaryExpression {
            let op = switch unary.operator {
            case .plus: "+"
            case .minus: "-"
            case .not: "NOT "
            }
            return "\(op)\(deparse(unary.expression))"
        }

        if let binary = expression as? BinaryExpression {
            let op = switch binary.operator {
            case .equals: "="
            case .notEquals: "<>"
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

        if let function = expression as? FunctionExpression {
            let args = function.arguments.map(deparse).joined(separator: ", ")
            return "\(function.name)(\(args))"
        }

        if let subquery = expression as? SubqueryExpression {
            return "(\(StatementDeparser(expressionDeparser: self).deparse(subquery.statement)))"
        }

        return "<unsupported-expression>"
    }
}
