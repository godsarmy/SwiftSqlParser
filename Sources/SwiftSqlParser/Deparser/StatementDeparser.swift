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

        return "<unsupported-statement>"
    }
}
