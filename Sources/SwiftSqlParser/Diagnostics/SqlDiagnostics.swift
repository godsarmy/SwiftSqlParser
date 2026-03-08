public struct SqlSourceLocation: Sendable, Equatable {
    public let line: Int
    public let column: Int
    public let offset: Int

    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }
}

public enum SqlDiagnosticCode: String, Sendable {
    case emptyInput = "empty_input"
    case emptyStatement = "empty_statement"
}

public struct SqlDiagnostic: Error, Sendable, Equatable {
    public let code: SqlDiagnosticCode
    public let message: String
    public let normalizedMessage: String
    public let location: SqlSourceLocation
    public let token: String?

    public init(
        code: SqlDiagnosticCode,
        message: String,
        normalizedMessage: String,
        location: SqlSourceLocation,
        token: String? = nil
    ) {
        self.code = code
        self.message = message
        self.normalizedMessage = normalizedMessage
        self.location = location
        self.token = token
    }
}

public struct ScriptParseResult: Sendable {
    public let statements: [any Statement]
    public let diagnostics: [SqlDiagnostic]

    public init(statements: [any Statement], diagnostics: [SqlDiagnostic]) {
        self.statements = statements
        self.diagnostics = diagnostics
    }
}
