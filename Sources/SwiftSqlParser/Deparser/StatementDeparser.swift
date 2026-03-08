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

        return "<unsupported-statement>"
    }
}
