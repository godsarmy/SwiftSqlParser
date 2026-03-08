import Foundation

public struct RawStatement: Statement, Equatable, Sendable {
    public let sql: String

    public init(sql: String) {
        self.sql = sql
    }
}

public enum SqlParseError: Error, Equatable, Sendable {
    case emptyInput(SqlDiagnostic)
    case emptyStatement(SqlDiagnostic)
    case unsupportedSyntax(SqlDiagnostic)

    public var diagnostic: SqlDiagnostic {
        switch self {
        case let .emptyInput(diagnostic):
            diagnostic
        case let .emptyStatement(diagnostic):
            diagnostic
        case let .unsupportedSyntax(diagnostic):
            diagnostic
        }
    }

    public var normalizedMessage: String {
        diagnostic.normalizedMessage
    }
}

public struct SqlParser: Sendable {
    public let strategy: GrammarStrategy

    public init(strategy: GrammarStrategy = .init()) {
        self.strategy = strategy
    }

    public func parseStatement(_ sql: String, options: ParserOptions = .init()) throws -> any Statement {
        let cleaned = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else {
            throw SqlParseError.emptyInput(
                SqlDiagnostic(
                    code: .emptyInput,
                    message: "Input SQL is empty.",
                    normalizedMessage: "empty_input:input sql is empty",
                    location: .init(line: 1, column: 1, offset: 0)
                )
            )
        }

        _ = options
        try validateSupportedSyntax(cleaned)

        let uppercased = cleaned.uppercased()

        if uppercased.hasPrefix("INSERT ") || uppercased.hasPrefix("UPDATE ") || uppercased.hasPrefix("DELETE ") {
            do {
                var dmlParser = try DmlParser(sql: cleaned, options: options)
                return try dmlParser.parseStatement()
            } catch {
                throw SqlParseError.unsupportedSyntax(
                    SqlDiagnostic(
                        code: .unsupportedSyntax,
                        message: "Statement uses unsupported DML syntax.",
                        normalizedMessage: "unsupported_syntax:dml_parse_failure",
                        location: .init(line: 1, column: 1, offset: 0),
                        token: "DML"
                    )
                )
            }
        }

        if uppercased.hasPrefix("CREATE ") || uppercased.hasPrefix("ALTER ") || uppercased.hasPrefix("DROP ") || uppercased.hasPrefix("TRUNCATE ") {
            do {
                var ddlParser = try DdlParser(sql: cleaned, options: options)
                return try ddlParser.parseStatement()
            } catch {
                throw SqlParseError.unsupportedSyntax(
                    SqlDiagnostic(
                        code: .unsupportedSyntax,
                        message: "Statement uses unsupported DDL syntax.",
                        normalizedMessage: "unsupported_syntax:ddl_parse_failure",
                        location: .init(line: 1, column: 1, offset: 0),
                        token: "DDL"
                    )
                )
            }
        }

        if uppercased.hasPrefix("SELECT ") || uppercased.hasPrefix("WITH ") || uppercased.hasPrefix("(") {
            do {
                var selectParser = try SelectCoreParser(sql: cleaned, options: options)
                return try selectParser.parseStatement()
            } catch {
                throw SqlParseError.unsupportedSyntax(
                    SqlDiagnostic(
                        code: .unsupportedSyntax,
                        message: "Statement uses unsupported query syntax.",
                        normalizedMessage: "unsupported_syntax:query_parse_failure",
                        location: .init(line: 1, column: 1, offset: 0),
                        token: "QUERY"
                    )
                )
            }
        }

        return RawStatement(sql: cleaned)
    }

    public func parseStatements(_ sql: String, options: ParserOptions = .init()) throws -> [any Statement] {
        let cleaned = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else {
            throw SqlParseError.emptyInput(
                SqlDiagnostic(
                    code: .emptyInput,
                    message: "Input SQL is empty.",
                    normalizedMessage: "empty_input:input sql is empty",
                    location: .init(line: 1, column: 1, offset: 0)
                )
            )
        }

        let statements: [String] = options.scriptSeparators.reduce([cleaned]) { partial, separator in
            partial.flatMap { splitStatementChunks($0, separator: separator) }
        }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let containsEmptyChunk = statements.contains(where: \String.isEmpty)
        if containsEmptyChunk {
            let firstEmpty = statements.firstIndex(of: "") ?? 0
            throw SqlParseError.emptyStatement(
                SqlDiagnostic(
                    code: .emptyStatement,
                    message: "Statement at index \(firstEmpty) is empty.",
                    normalizedMessage: "empty_statement:statement chunk is empty",
                    location: .init(line: 1, column: firstEmpty + 1, offset: firstEmpty)
                )
            )
        }

        return try statements.map { try parseStatement($0, options: options) }
    }

    public func parseScript(_ sql: String, options: ParserOptions = .init()) -> ScriptParseResult {
        let separator = options.scriptSeparators.first ?? ";"
        if separator.isEmpty {
            return ScriptParseResult(statements: [], diagnostics: [
                SqlDiagnostic(
                    code: .emptyStatement,
                    message: "Script separator cannot be empty.",
                    normalizedMessage: "empty_statement:script separator cannot be empty",
                    location: .init(line: 1, column: 1, offset: 0)
                )
            ])
        }

        let chunks = splitStatementChunks(sql, separator: separator)
        var line = 1
        var column = 1
        var offset = 0
        var statements: [any Statement] = []
        var diagnostics: [SqlDiagnostic] = []

        for chunk in chunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                diagnostics.append(
                    SqlDiagnostic(
                        code: .emptyStatement,
                        message: "Script statement is empty.",
                        normalizedMessage: "empty_statement:script statement is empty",
                        location: .init(line: line, column: column, offset: offset),
                        token: separator
                    )
                )
            } else {
                do {
                    statements.append(try parseStatement(trimmed, options: options))
                } catch let error as SqlParseError {
                    diagnostics.append(error.diagnostic)
                } catch {
                    diagnostics.append(
                        SqlDiagnostic(
                            code: .unsupportedSyntax,
                            message: "Statement uses unsupported syntax.",
                            normalizedMessage: "unsupported_syntax:statement uses unsupported syntax",
                            location: .init(line: line, column: column, offset: offset)
                        )
                    )
                }
            }

            for character in chunk {
                offset += 1
                if character == "\n" {
                    line += 1
                    column = 1
                } else {
                    column += 1
                }
            }

            offset += separator.count
            column += separator.count
        }

        return ScriptParseResult(statements: statements, diagnostics: diagnostics)
    }

    private func splitStatementChunks(_ input: String, separator: String) -> [String] {
        guard separator.isEmpty == false else {
            return [input]
        }

        var parts: [String] = []
        parts.reserveCapacity(max(1, input.count / max(separator.count, 1)))

        var start = input.startIndex
        while let range = input.range(of: separator, range: start..<input.endIndex) {
            parts.append(String(input[start..<range.lowerBound]))
            start = range.upperBound
        }
        parts.append(String(input[start..<input.endIndex]))
        return parts
    }

    private func validateSupportedSyntax(_ sql: String) throws {
        let uppercase = sql.uppercased()
        let unsupportedRules: [(token: String, gap: String)] = [
            ("MERGE", "merge_statement"),
            ("QUALIFY", "qualify_clause"),
            ("PIVOT", "pivot_clause"),
            ("UNPIVOT", "unpivot_clause"),
            ("MATCH_RECOGNIZE", "match_recognize")
        ]

        for rule in unsupportedRules where uppercase.contains(rule.token) {
            throw SqlParseError.unsupportedSyntax(
                SqlDiagnostic(
                    code: .unsupportedSyntax,
                    message: "Unsupported syntax token '\(rule.token)'.",
                    normalizedMessage: "unsupported_syntax:\(rule.gap)",
                    location: .init(line: 1, column: 1, offset: 0),
                    token: rule.token
                )
            )
        }
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

public func parseScript(
    _ sql: String,
    options: ParserOptions = .init(),
    strategy: GrammarStrategy = .init()
) -> ScriptParseResult {
    SqlParser(strategy: strategy).parseScript(sql, options: options)
}
