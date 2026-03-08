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
  case unsupportedSyntax = "unsupported_syntax"
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
  public let slots: [StatementParseSlot]
  public let statements: [any Statement]
  public let diagnostics: [SqlDiagnostic]

  public init(
    slots: [StatementParseSlot], statements: [any Statement], diagnostics: [SqlDiagnostic]
  ) {
    self.slots = slots
    self.statements = statements
    self.diagnostics = diagnostics
  }

  public init(slots: [StatementParseSlot]) {
    self.init(
      slots: slots,
      statements: slots.compactMap(\.statement),
      diagnostics: slots.compactMap(\.diagnostic))
  }
}

public struct StatementParseSlot: Sendable {
  public let statement: (any Statement)?
  public let diagnostic: SqlDiagnostic?
  public let location: SqlSourceLocation

  public init(statement: (any Statement)?, diagnostic: SqlDiagnostic?, location: SqlSourceLocation)
  {
    self.statement = statement
    self.diagnostic = diagnostic
    self.location = location
  }
}

public struct StatementParseResult: Sendable {
  public let statement: (any Statement)?
  public let diagnostic: SqlDiagnostic?
  public let location: SqlSourceLocation

  public init(statement: (any Statement)?, diagnostic: SqlDiagnostic?, location: SqlSourceLocation)
  {
    self.statement = statement
    self.diagnostic = diagnostic
    self.location = location
  }
}

public struct StatementsParseResult: Sendable {
  public let slots: [StatementParseSlot]
  public let statements: [any Statement]
  public let diagnostics: [SqlDiagnostic]

  public init(slots: [StatementParseSlot]) {
    self.slots = slots
    self.statements = slots.compactMap(\.statement)
    self.diagnostics = slots.compactMap(\.diagnostic)
  }
}
