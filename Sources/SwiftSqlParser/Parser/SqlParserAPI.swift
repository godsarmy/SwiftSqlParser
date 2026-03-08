import Foundation

public struct RawStatement: Statement, Equatable, Sendable {
    public let sql: String

    public init(sql: String) {
        self.sql = sql
    }
}

public enum SqlParseError: Error, Equatable, Sendable {
    case emptyInput
    case emptyStatement(index: Int)
}

public struct SqlParser: Sendable {
    public let strategy: GrammarStrategy

    public init(strategy: GrammarStrategy = .init()) {
        self.strategy = strategy
    }

    public func parseStatement(_ sql: String, options: ParserOptions = .init()) throws -> any Statement {
        let cleaned = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else {
            throw SqlParseError.emptyInput
        }

        _ = options
        return RawStatement(sql: cleaned)
    }

    public func parseStatements(_ sql: String, options: ParserOptions = .init()) throws -> [any Statement] {
        let cleaned = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else {
            throw SqlParseError.emptyInput
        }

        let statements: [String] = options.scriptSeparators.reduce([cleaned]) { partial, separator in
            partial.flatMap { $0.components(separatedBy: separator) }
        }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let containsEmptyChunk = statements.contains(where: \String.isEmpty)
        if containsEmptyChunk {
            let firstEmpty = statements.firstIndex(of: "") ?? 0
            throw SqlParseError.emptyStatement(index: firstEmpty)
        }

        return statements.map(RawStatement.init(sql:))
    }
}

public func parseStatement(
    _ sql: String,
    options: ParserOptions = .init(),
    strategy: GrammarStrategy = .init()
) throws -> any Statement {
    try SqlParser(strategy: strategy).parseStatement(sql, options: options)
}

public func parseStatements(
    _ sql: String,
    options: ParserOptions = .init(),
    strategy: GrammarStrategy = .init()
) throws -> [any Statement] {
    try SqlParser(strategy: strategy).parseStatements(sql, options: options)
}
