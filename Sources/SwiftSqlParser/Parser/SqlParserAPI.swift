import Foundation

public struct RawStatement: Statement, Equatable, Sendable {
  public let sql: String

  public init(sql: String) {
    self.sql = sql
  }
}

private struct ScriptChunk {
  let sql: String
  let location: SqlSourceLocation
}

public enum SqlParseError: Error, Equatable, Sendable {
  case emptyInput(SqlDiagnostic)
  case emptyStatement(SqlDiagnostic)
  case unsupportedSyntax(SqlDiagnostic)

  public var diagnostic: SqlDiagnostic {
    switch self {
    case .emptyInput(let diagnostic):
      diagnostic
    case .emptyStatement(let diagnostic):
      diagnostic
    case .unsupportedSyntax(let diagnostic):
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

  public func parseStatement(_ sql: String, options: ParserOptions = .init()) throws
    -> any Statement
  {
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
    do {
      try validateSupportedSyntax(cleaned, options: options)
    } catch let error as SqlParseError {
      if options.recoverUnsupportedStatements {
        return UnsupportedStatement(sql: cleaned, diagnostic: error.diagnostic)
      }
      throw error
    }

    let uppercased = cleaned.uppercased()

    if uppercased.hasPrefix("EXPLAIN ") {
      do {
        let inner = String(cleaned.dropFirst("EXPLAIN".count)).trimmingCharacters(
          in: .whitespacesAndNewlines)
        return ExplainStatement(statement: try parseStatement(inner, options: options))
      } catch let error as SqlParseError {
        if options.recoverUnsupportedStatements {
          return UnsupportedStatement(sql: cleaned, diagnostic: error.diagnostic)
        }
        throw error
      }
    }

    if uppercased.hasPrefix("SHOW ") {
      return ShowStatement(
        subject: String(cleaned.dropFirst("SHOW".count)).trimmingCharacters(
          in: .whitespacesAndNewlines))
    }

    if uppercased.hasPrefix("SET ") {
      return try parseSetStatement(cleaned, options: options)
    }

    if uppercased.hasPrefix("RESET ") {
      return ResetStatement(
        name: String(cleaned.dropFirst("RESET".count)).trimmingCharacters(
          in: .whitespacesAndNewlines))
    }

    if uppercased.hasPrefix("USE ") {
      return UseStatement(
        target: String(cleaned.dropFirst("USE".count)).trimmingCharacters(
          in: .whitespacesAndNewlines))
    }

    if uppercased.hasPrefix("INSERT ") || uppercased.hasPrefix("UPDATE ")
      || uppercased.hasPrefix("DELETE ") || uppercased.hasPrefix("MERGE ")
      || uppercased.hasPrefix("REPLACE ") || uppercased.hasPrefix("UPSERT ")
    {
      do {
        var dmlParser = try DmlParser(sql: cleaned, options: options)
        return try dmlParser.parseStatement()
      } catch {
        let diagnostic = SqlDiagnostic(
          code: .unsupportedSyntax,
          message: "Statement uses unsupported DML syntax.",
          normalizedMessage: "unsupported_syntax:dml_parse_failure",
          location: .init(line: 1, column: 1, offset: 0),
          token: "DML"
        )
        if options.recoverUnsupportedStatements {
          return UnsupportedStatement(sql: cleaned, diagnostic: diagnostic)
        }
        throw SqlParseError.unsupportedSyntax(diagnostic)
      }
    }

    if uppercased.hasPrefix("CREATE ") || uppercased.hasPrefix("ALTER ")
      || uppercased.hasPrefix("DROP ") || uppercased.hasPrefix("TRUNCATE ")
    {
      do {
        var ddlParser = try DdlParser(sql: cleaned, options: options)
        return try ddlParser.parseStatement()
      } catch {
        let diagnostic = SqlDiagnostic(
          code: .unsupportedSyntax,
          message: "Statement uses unsupported DDL syntax.",
          normalizedMessage: "unsupported_syntax:ddl_parse_failure",
          location: .init(line: 1, column: 1, offset: 0),
          token: "DDL"
        )
        if options.recoverUnsupportedStatements {
          return UnsupportedStatement(sql: cleaned, diagnostic: diagnostic)
        }
        throw SqlParseError.unsupportedSyntax(diagnostic)
      }
    }

    if uppercased.hasPrefix("SELECT ") || uppercased.hasPrefix("WITH ")
      || uppercased.hasPrefix("VALUES ") || uppercased.hasPrefix("(")
    {
      do {
        var selectParser = try SelectCoreParser(sql: cleaned, options: options)
        return try selectParser.parseStatement()
      } catch {
        let diagnostic = SqlDiagnostic(
          code: .unsupportedSyntax,
          message: "Statement uses unsupported query syntax.",
          normalizedMessage: "unsupported_syntax:query_parse_failure",
          location: .init(line: 1, column: 1, offset: 0),
          token: "QUERY"
        )
        if options.recoverUnsupportedStatements {
          return UnsupportedStatement(sql: cleaned, diagnostic: diagnostic)
        }
        throw SqlParseError.unsupportedSyntax(diagnostic)
      }
    }

    return RawStatement(sql: cleaned)
  }

  public func parseStatementResult(_ sql: String, options: ParserOptions = .init())
    -> StatementParseResult
  {
    do {
      let statement = try parseStatement(sql, options: options)
      return StatementParseResult(
        statement: statement,
        diagnostic: nil,
        location: .init(line: 1, column: 1, offset: 0)
      )
    } catch let error as SqlParseError {
      return StatementParseResult(
        statement: nil, diagnostic: error.diagnostic, location: error.diagnostic.location)
    } catch {
      let diagnostic = SqlDiagnostic(
        code: .unsupportedSyntax,
        message: "Statement uses unsupported syntax.",
        normalizedMessage: "unsupported_syntax:statement uses unsupported syntax",
        location: .init(line: 1, column: 1, offset: 0)
      )
      return StatementParseResult(
        statement: nil, diagnostic: diagnostic, location: diagnostic.location)
    }
  }

  public func parseStatements(_ sql: String, options: ParserOptions = .init()) throws
    -> [any Statement]
  {
    let result = try parseStatementsResult(sql, options: options)
    if let diagnostic = result.diagnostics.first {
      switch diagnostic.code {
      case .emptyInput:
        throw SqlParseError.emptyInput(diagnostic)
      case .emptyStatement:
        throw SqlParseError.emptyStatement(diagnostic)
      case .unsupportedSyntax:
        throw SqlParseError.unsupportedSyntax(diagnostic)
      }
    }

    return result.statements
  }

  public func parseStatementsResult(_ sql: String, options: ParserOptions = .init()) throws
    -> StatementsParseResult
  {
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

    return parseStatementList(cleaned, options: options, recordEmptyStatements: true)
  }

  public func parseScript(_ sql: String, options: ParserOptions = .init()) -> ScriptParseResult {
    if options.scriptSeparators.contains(where: \.isEmpty) {
      return ScriptParseResult(
        slots: [
          StatementParseSlot(
            statement: nil,
            diagnostic: SqlDiagnostic(
              code: .emptyStatement,
              message: "Script separator cannot be empty.",
              normalizedMessage: "empty_statement:script separator cannot be empty",
              location: .init(line: 1, column: 1, offset: 0)
            ),
            location: .init(line: 1, column: 1, offset: 0))
        ])
    }

    return ScriptParseResult(
      slots: parseStatementList(
        sql,
        options: options,
        recordEmptyStatements: true,
        continueAfterErrors: options.recoverParseErrors
      ).slots)
  }

  private func parseStatementList(
    _ sql: String,
    options: ParserOptions,
    recordEmptyStatements: Bool,
    continueAfterErrors: Bool = true
  ) -> StatementsParseResult {
    let chunks = splitScriptChunks(sql, separators: options.scriptSeparators)
    var slots: [StatementParseSlot] = []

    for chunk in chunks {
      let trimmed = chunk.sql.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty {
        if recordEmptyStatements {
          slots.append(
            StatementParseSlot(
              statement: nil,
              diagnostic: SqlDiagnostic(
                code: .emptyStatement,
                message: "Script statement is empty.",
                normalizedMessage: "empty_statement:script statement is empty",
                location: chunk.location),
              location: chunk.location))
        }
        if continueAfterErrors == false {
          break
        }
        continue
      }

      do {
        let statement = try parseStatement(trimmed, options: options)
        slots.append(
          StatementParseSlot(statement: statement, diagnostic: nil, location: chunk.location))
      } catch let error as SqlParseError {
        slots.append(
          StatementParseSlot(statement: nil, diagnostic: error.diagnostic, location: chunk.location)
        )
        if continueAfterErrors == false {
          break
        }
      } catch {
        slots.append(
          StatementParseSlot(
            statement: nil,
            diagnostic: SqlDiagnostic(
              code: .unsupportedSyntax,
              message: "Statement uses unsupported syntax.",
              normalizedMessage: "unsupported_syntax:statement uses unsupported syntax",
              location: chunk.location),
            location: chunk.location))
        if continueAfterErrors == false {
          break
        }
      }
    }

    return StatementsParseResult(slots: slots)
  }

  private func splitScriptChunks(_ input: String, separators: [String]) -> [ScriptChunk] {
    guard separators.isEmpty == false else {
      return [ScriptChunk(sql: input, location: .init(line: 1, column: 1, offset: 0))]
    }

    var chunks: [ScriptChunk] = []
    var current = ""
    var chunkLine = 1
    var chunkColumn = 1
    var chunkOffset = 0
    var line = 1
    var column = 1
    var offset = 0
    var parenthesisDepth = 0
    var index = input.startIndex
    var quoteState: Character?
    var currentLineIsWhitespaceOnly = true

    while index < input.endIndex {
      let character = input[index]

      if let separatorMatch = matchSeparator(
        in: input,
        at: index,
        separators: separators,
        quoteState: quoteState,
        parenthesisDepth: parenthesisDepth,
        currentLineIsWhitespaceOnly: currentLineIsWhitespaceOnly
      ) {
        chunks.append(
          ScriptChunk(
            sql: current, location: .init(line: chunkLine, column: chunkColumn, offset: chunkOffset)
          ))
        current = ""

        let consumed = String(input[index..<separatorMatch.endIndex])
        for consumedCharacter in consumed {
          if consumedCharacter == "\n" {
            line += 1
            column = 1
            currentLineIsWhitespaceOnly = true
          } else {
            column += 1
            if consumedCharacter.isWhitespace == false {
              currentLineIsWhitespaceOnly = false
            }
          }
          offset += 1
        }

        index = separatorMatch.endIndex
        chunkLine = line
        chunkColumn = column
        chunkOffset = offset
        continue
      }

      if let quote = quoteState {
        current.append(character)
        if character == quote {
          if quote == "'" {
            let next = input.index(after: index)
            if next < input.endIndex, input[next] == "'" {
              current.append(input[next])
              index = next
              offset += 1
              column += 1
            } else {
              quoteState = nil
            }
          } else {
            quoteState = nil
          }
        }
      } else if character == "'" || character == "\"" || character == "`" {
        quoteState = character
        current.append(character)
      } else if character == "[" {
        quoteState = "]"
        current.append(character)
      } else if character == "(" {
        parenthesisDepth += 1
        current.append(character)
      } else if character == ")" {
        parenthesisDepth = max(0, parenthesisDepth - 1)
        current.append(character)
      } else {
        current.append(character)
      }

      if character == "\n" {
        line += 1
        column = 1
        currentLineIsWhitespaceOnly = true
      } else {
        column += 1
        if character.isWhitespace == false {
          currentLineIsWhitespaceOnly = false
        }
      }
      offset += 1
      index = input.index(after: index)
    }

    chunks.append(
      ScriptChunk(
        sql: current, location: .init(line: chunkLine, column: chunkColumn, offset: chunkOffset)))
    return chunks
  }

  private func matchSeparator(
    in input: String,
    at index: String.Index,
    separators: [String],
    quoteState: Character?,
    parenthesisDepth: Int,
    currentLineIsWhitespaceOnly: Bool
  ) -> (separator: String, endIndex: String.Index)? {
    guard quoteState == nil, parenthesisDepth == 0 else {
      return nil
    }

    if separators.contains(";"), input[index] == ";" {
      return (";", input.index(after: index))
    }

    if separators.contains("\n\n\n"), input[index...].hasPrefix("\n\n\n") {
      return ("\n\n\n", input.index(index, offsetBy: 3))
    }

    guard currentLineIsWhitespaceOnly else {
      return nil
    }

    let lineEnd = input[index...].firstIndex(of: "\n") ?? input.endIndex
    let lineText = input[index..<lineEnd].trimmingCharacters(in: .whitespacesAndNewlines)
    if separators.contains("GO"), lineText.uppercased() == "GO" {
      return ("GO", lineEnd < input.endIndex ? input.index(after: lineEnd) : lineEnd)
    }

    if separators.contains("/"), lineText == "/" {
      return ("/", lineEnd < input.endIndex ? input.index(after: lineEnd) : lineEnd)
    }

    return nil
  }

  private func parseSetStatement(_ sql: String, options: ParserOptions) throws -> SetStatement {
    let assignment = String(sql.dropFirst("SET".count)).trimmingCharacters(
      in: .whitespacesAndNewlines)
    guard let range = assignment.range(of: "=") else {
      throw SqlParseError.unsupportedSyntax(
        SqlDiagnostic(
          code: .unsupportedSyntax,
          message: "SET statements must assign a value.",
          normalizedMessage: "unsupported_syntax:set_parse_failure",
          location: .init(line: 1, column: 1, offset: 0),
          token: "SET"
        ))
    }

    let name = String(assignment[..<range.lowerBound]).trimmingCharacters(
      in: .whitespacesAndNewlines)
    let valueSql = String(assignment[range.upperBound...]).trimmingCharacters(
      in: .whitespacesAndNewlines)
    guard name.isEmpty == false, valueSql.isEmpty == false else {
      throw SqlParseError.unsupportedSyntax(
        SqlDiagnostic(
          code: .unsupportedSyntax,
          message: "SET statements must assign a value.",
          normalizedMessage: "unsupported_syntax:set_parse_failure",
          location: .init(line: 1, column: 1, offset: 0),
          token: "SET"
        ))
    }

    let wrapper = "SELECT \(valueSql) FROM settings"
    do {
      var parser = try SelectCoreParser(sql: wrapper, options: options)
      guard let select = try parser.parseStatement() as? PlainSelect,
        let item = select.selectItems.first as? ExpressionSelectItem
      else {
        throw SqlParseError.unsupportedSyntax(
          SqlDiagnostic(
            code: .unsupportedSyntax,
            message: "Statement uses unsupported SET syntax.",
            normalizedMessage: "unsupported_syntax:set_parse_failure",
            location: .init(line: 1, column: 1, offset: 0),
            token: "SET"
          ))
      }
      return SetStatement(name: name, value: item.expression)
    } catch let error as SqlParseError {
      throw error
    } catch {
      throw SqlParseError.unsupportedSyntax(
        SqlDiagnostic(
          code: .unsupportedSyntax,
          message: "Statement uses unsupported SET syntax.",
          normalizedMessage: "unsupported_syntax:set_parse_failure",
          location: .init(line: 1, column: 1, offset: 0),
          token: "SET"
        ))
    }
  }

  private func validateSupportedSyntax(_ sql: String, options: ParserOptions) throws {
    let uppercase = sql.uppercased()
    var unsupportedRules: [(token: String, gap: String)] = []

    if uppercase.contains("MERGE"),
      !(options.experimentalFeatures.contains(.mergeStatements)
        && (options.dialectFeatures.contains(.sqlServer)
          || options.dialectFeatures.contains(.oracle)))
    {
      unsupportedRules.append(("MERGE", "merge_statement"))
    }

    if uppercase.contains("PIVOT"), !uppercase.contains("UNPIVOT"),
      !(options.experimentalFeatures.contains(.pivotSyntax)
        && (options.dialectFeatures.contains(.sqlServer)
          || options.dialectFeatures.contains(.oracle)))
    {
      unsupportedRules.append(("PIVOT", "pivot_clause"))
    }

    if uppercase.contains("UNPIVOT"),
      !(options.experimentalFeatures.contains(.pivotSyntax)
        && (options.dialectFeatures.contains(.sqlServer)
          || options.dialectFeatures.contains(.oracle)))
    {
      unsupportedRules.append(("UNPIVOT", "unpivot_clause"))
    }

    unsupportedRules.append(("MATCH_RECOGNIZE", "match_recognize"))

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
