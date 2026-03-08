import Foundation

struct DdlParser {
  private let tokens: [Token]
  private let options: ParserOptions
  private var index: Int = 0

  init(sql: String, options: ParserOptions) throws {
    self.options = options
    self.tokens = try Tokenizer(sql: sql, options: options).tokenize()
  }

  mutating func parseStatement() throws -> any Statement {
    if matchKeyword("CREATE") {
      return try parseCreate()
    }

    if matchKeyword("ALTER") {
      return try parseAlter()
    }

    if matchKeyword("DROP") {
      return try parseDrop()
    }

    if matchKeyword("TRUNCATE") {
      return try parseTruncate()
    }

    throw DdlParseFailure.expected("DDL statement")
  }

  private mutating func parseCreate() throws -> any Statement {
    let isUnique = matchKeyword("UNIQUE")

    if matchKeyword("TABLE") {
      return try parseCreateTable()
    }

    if isUnique || matchKeyword("INDEX") {
      if isUnique {
        try consumeKeyword("INDEX")
      }
      return try parseCreateIndex(isUnique: isUnique)
    }

    if matchKeyword("VIEW") {
      return try parseCreateView()
    }

    throw DdlParseFailure.expected("TABLE, INDEX, or VIEW")
  }

  private mutating func parseCreateTable() throws -> CreateTableStatement {
    let table = try consumeIdentifier()
    try consumeSymbol("(")

    var columns: [TableColumnDefinition] = []
    var constraints: [TableConstraintDefinition] = []

    while true {
      if checkKeyword("CONSTRAINT") || checkKeyword("PRIMARY") || checkKeyword("FOREIGN")
        || checkKeyword("CHECK")
      {
        constraints.append(try parseTableConstraint())
      } else {
        columns.append(try parseColumnDefinition())
      }

      if match(symbol: ",") {
        continue
      }
      break
    }

    try consumeSymbol(")")
    try ensureAtEnd()
    return CreateTableStatement(table: table, columns: columns, constraints: constraints)
  }

  private mutating func parseCreateIndex(isUnique: Bool) throws -> CreateIndexStatement {
    let name = try consumeIdentifier()
    try consumeKeyword("ON")
    let table = try consumeIdentifier()
    try consumeSymbol("(")
    let columns = try parseIdentifierListUntilRightParen()
    try ensureAtEnd()
    return CreateIndexStatement(name: name, table: table, columns: columns, isUnique: isUnique)
  }

  private mutating func parseCreateView() throws -> CreateViewStatement {
    let name = try consumeIdentifier()
    try consumeKeyword("AS")
    let selectSql = collectRemainingSql()
    let select = try SqlParser().parseStatement(selectSql, options: options)
    return CreateViewStatement(name: name, select: select)
  }

  private mutating func parseAlter() throws -> AlterTableStatement {
    try consumeKeyword("TABLE")
    let table = try consumeIdentifier()

    if matchKeyword("ADD") {
      if checkKeyword("CONSTRAINT") || checkKeyword("PRIMARY") || checkKeyword("FOREIGN")
        || checkKeyword("CHECK")
      {
        let constraint = try parseTableConstraint()
        try ensureAtEnd()
        return AlterTableStatement(table: table, operation: .addConstraint(constraint))
      }

      _ = matchKeyword("COLUMN")
      let column = try parseColumnDefinition()
      try ensureAtEnd()
      return AlterTableStatement(table: table, operation: .addColumn(column))
    } else if matchKeyword("DROP") {
      _ = matchKeyword("COLUMN")
      if matchKeyword("CONSTRAINT") {
        let constraintName = try consumeIdentifier()
        try ensureAtEnd()
        return AlterTableStatement(table: table, operation: .dropConstraint(constraintName))
      }

      let columnName = try consumeIdentifier()
      try ensureAtEnd()
      return AlterTableStatement(table: table, operation: .dropColumn(columnName))
    } else if matchKeyword("RENAME") {
      if matchKeyword("COLUMN") {
        let oldName = try consumeIdentifier()
        try consumeKeyword("TO")
        let newName = try consumeIdentifier()
        try ensureAtEnd()
        return AlterTableStatement(
          table: table, operation: .renameColumn(oldName: oldName, newName: newName))
      }

      try consumeKeyword("TO")
      let newName = try consumeIdentifier()
      try ensureAtEnd()
      return AlterTableStatement(table: table, operation: .renameTable(newName))
    }

    throw DdlParseFailure.expected("ALTER TABLE operation")
  }

  private mutating func parseDrop() throws -> DropTableStatement {
    try consumeKeyword("TABLE")
    let table = try consumeIdentifier()
    try ensureAtEnd()
    return DropTableStatement(table: table)
  }

  private mutating func parseTruncate() throws -> TruncateTableStatement {
    _ = matchKeyword("TABLE")
    let table = try consumeIdentifier()
    try ensureAtEnd()
    return TruncateTableStatement(table: table)
  }

  private mutating func parseColumnDefinition() throws -> TableColumnDefinition {
    let name = try consumeIdentifier()
    let typeName = try parseTypeName()
    var defaultExpression: (any Expression)?
    var constraints: [ColumnConstraint] = []

    while let token = peek(), isTerminatorToken(token) == false {
      if matchKeyword("DEFAULT") {
        defaultExpression = RawExpression(sql: try collectExpressionUntilConstraintBoundary())
      } else if matchKeyword("NOT") {
        try consumeKeyword("NULL")
        constraints.append(.notNull)
      } else if matchKeyword("PRIMARY") {
        try consumeKeyword("KEY")
        constraints.append(.primaryKey)
      } else if matchKeyword("UNIQUE") {
        constraints.append(.unique)
      } else if matchKeyword("REFERENCES") {
        let table = try consumeIdentifier()
        var columns: [String] = []
        if match(symbol: "(") {
          columns = try parseIdentifierListUntilRightParen()
        }
        constraints.append(.references(table: table, columns: columns))
      } else if matchKeyword("CHECK") {
        try consumeSymbol("(")
        constraints.append(.check(RawExpression(sql: try collectBalancedParenthesisSql())))
      } else {
        break
      }
    }

    return TableColumnDefinition(
      name: name, typeName: typeName, defaultExpression: defaultExpression, constraints: constraints
    )
  }

  private mutating func parseTableConstraint() throws -> TableConstraintDefinition {
    let name: String?
    if matchKeyword("CONSTRAINT") {
      name = try consumeIdentifier()
    } else {
      name = nil
    }

    let kind: TableConstraintKind
    if matchKeyword("PRIMARY") {
      try consumeKeyword("KEY")
      try consumeSymbol("(")
      kind = .primaryKey(columns: try parseIdentifierListUntilRightParen())
    } else if matchKeyword("FOREIGN") {
      try consumeKeyword("KEY")
      try consumeSymbol("(")
      let columns = try parseIdentifierListUntilRightParen()
      try consumeKeyword("REFERENCES")
      let refTable = try consumeIdentifier()
      try consumeSymbol("(")
      let refColumns = try parseIdentifierListUntilRightParen()
      kind = .foreignKey(columns: columns, referencesTable: refTable, referencesColumns: refColumns)
    } else if matchKeyword("CHECK") {
      try consumeSymbol("(")
      kind = .check(RawExpression(sql: try collectBalancedParenthesisSql()))
    } else {
      throw DdlParseFailure.expected("table constraint")
    }

    return TableConstraintDefinition(name: name, kind: kind)
  }

  private mutating func parseIdentifierListUntilRightParen() throws -> [String] {
    var identifiers: [String] = []
    while true {
      identifiers.append(try consumeIdentifier())
      if match(symbol: ",") {
        continue
      }
      try consumeSymbol(")")
      return identifiers
    }
  }

  private mutating func parseTypeName() throws -> String {
    var typeName = try consumeIdentifier()
    if match(symbol: "(") {
      typeName += "(\(try collectBalancedParenthesisSql()))"
    }
    return typeName
  }

  private mutating func collectBalancedParenthesisSql() throws -> String {
    var depth = 1
    var parts: [String] = []

    while let token = advance() {
      if token.kind == .symbol, token.text == "(" {
        depth += 1
      } else if token.kind == .symbol, token.text == ")" {
        depth -= 1
        if depth == 0 {
          return parts.joined(separator: " ")
        }
      }
      parts.append(token.sqlText)
    }

    throw DdlParseFailure.expected(")")
  }

  private mutating func collectExpressionUntilConstraintBoundary() throws -> String {
    var depth = 0
    var parts: [String] = []

    while let token = peek() {
      if depth == 0 && (isTerminatorToken(token) || startsColumnConstraint()) {
        break
      }
      _ = advance()
      if token.kind == .symbol, token.text == "(" {
        depth += 1
      } else if token.kind == .symbol, token.text == ")" {
        depth -= 1
      }
      parts.append(token.sqlText)
    }

    return parts.joined(separator: " ")
  }

  private func collectRemainingSql() -> String {
    let remaining = tokens[index...].map(\.sqlText).joined(separator: " ")
    return remaining
  }

  private func isTerminatorToken(_ token: Token) -> Bool {
    token.kind == .symbol && (token.text == "," || token.text == ")")
  }

  private func startsColumnConstraint() -> Bool {
    checkKeyword("NOT") || checkKeyword("PRIMARY") || checkKeyword("UNIQUE")
      || checkKeyword("REFERENCES") || checkKeyword("CHECK")
  }

  private mutating func ensureAtEnd() throws {
    guard peek() == nil else {
      throw DdlParseFailure.unexpectedToken(peek()?.text ?? "")
    }
  }

  private mutating func consumeKeyword(_ keyword: String) throws {
    guard matchKeyword(keyword) else {
      throw DdlParseFailure.expected(keyword)
    }
  }

  private mutating func consumeSymbol(_ symbol: String) throws {
    guard match(symbol: symbol) else {
      throw DdlParseFailure.expected(symbol)
    }
  }

  private mutating func consumeIdentifier() throws -> String {
    guard let first = peek(), first.kind == .identifier else {
      throw DdlParseFailure.expected("identifier")
    }
    _ = advance()

    var identifier = first.text
    while match(symbol: ".") {
      guard let next = peek(), next.kind == .identifier else {
        throw DdlParseFailure.expected("identifier after '.'")
      }
      _ = advance()
      identifier += ".\(next.text)"
    }

    return identifier
  }

  private func checkKeyword(_ keyword: String) -> Bool {
    guard let token = peek() else {
      return false
    }
    return token.kind == .identifier && token.uppercased == keyword.uppercased()
  }

  @discardableResult
  private mutating func matchKeyword(_ keyword: String) -> Bool {
    guard checkKeyword(keyword) else {
      return false
    }
    _ = advance()
    return true
  }

  @discardableResult
  private mutating func match(symbol: String) -> Bool {
    guard let token = peek(), token.kind == .symbol, token.text == symbol else {
      return false
    }
    _ = advance()
    return true
  }

  private func peek() -> Token? {
    guard index < tokens.count else {
      return nil
    }
    return tokens[index]
  }

  private mutating func advance() -> Token? {
    guard index < tokens.count else {
      return nil
    }
    defer { index += 1 }
    return tokens[index]
  }
}

private enum DdlParseFailure: Error {
  case expected(String)
  case unexpectedToken(String)
}

private struct Token {
  enum Kind {
    case identifier
    case number
    case string
    case symbol
  }

  let text: String
  let kind: Kind

  var uppercased: String { text.uppercased() }
  var sqlText: String {
    switch kind {
    case .string:
      return "'\(text.replacingOccurrences(of: "'", with: "''"))'"
    default:
      return text
    }
  }
}

private struct Tokenizer {
  private let sql: String
  private let options: ParserOptions

  init(sql: String, options: ParserOptions) {
    self.sql = sql
    self.options = options
  }

  func tokenize() throws -> [Token] {
    var tokens: [Token] = []
    var index = sql.startIndex

    while index < sql.endIndex {
      let character = sql[index]

      if character.isWhitespace {
        index = sql.index(after: index)
        continue
      }

      if character == "'" {
        let (value, nextIndex) = try consumeString(from: index)
        tokens.append(Token(text: value, kind: .string))
        index = nextIndex
        continue
      }

      if character == "\"", options.experimentalFeatures.contains(.quotedIdentifiers) {
        let (identifier, nextIndex) = try consumeQuotedIdentifier(from: index, quote: "\"")
        tokens.append(Token(text: identifier, kind: .identifier))
        index = nextIndex
        continue
      }

      if character == "[",
        options.experimentalFeatures.contains(.quotedIdentifiers)
          && (options.identifierQuoting == .squareBrackets
            || options.dialectFeatures.contains(.sqlServer))
      {
        let (identifier, nextIndex) = try consumeBracketIdentifier(from: index)
        tokens.append(Token(text: identifier, kind: .identifier))
        index = nextIndex
        continue
      }

      if character == "`",
        options.experimentalFeatures.contains(.quotedIdentifiers)
          && (options.dialectFeatures.contains(.mysql)
            || options.dialectFeatures.contains(.bigQuery)
            || options.dialectFeatures.contains(.snowflake))
      {
        let (identifier, nextIndex) = try consumeQuotedIdentifier(from: index, quote: "`")
        tokens.append(Token(text: identifier, kind: .identifier))
        index = nextIndex
        continue
      }

      if character.isNumber {
        let (number, nextIndex) = consumeNumber(from: index)
        tokens.append(Token(text: number, kind: .number))
        index = nextIndex
        continue
      }

      if character.isLetter || character == "_" {
        let (identifier, nextIndex) = consumeIdentifier(from: index)
        tokens.append(Token(text: identifier, kind: .identifier))
        index = nextIndex
        continue
      }

      let nextIndex = sql.index(after: index)
      if nextIndex < sql.endIndex {
        let pair = String([character, sql[nextIndex]])
        if ["<>", "!=", ">=", "<=", "::"].contains(pair) {
          tokens.append(Token(text: pair, kind: .symbol))
          index = sql.index(after: nextIndex)
          continue
        }
      }

      if [",", "(", ")", ".", "=", "<", ">", "+", "-", "*", "/"].contains(character) {
        tokens.append(Token(text: String(character), kind: .symbol))
        index = nextIndex
        continue
      }

      throw DdlParseFailure.unexpectedToken(String(character))
    }

    return tokens
  }

  private func consumeIdentifier(from start: String.Index) -> (String, String.Index) {
    var current = start
    while current < sql.endIndex {
      let character = sql[current]
      if character.isLetter || character.isNumber || character == "_" {
        current = sql.index(after: current)
      } else {
        break
      }
    }
    return (String(sql[start..<current]), current)
  }

  private func consumeNumber(from start: String.Index) -> (String, String.Index) {
    var current = start
    while current < sql.endIndex, sql[current].isNumber {
      current = sql.index(after: current)
    }
    return (String(sql[start..<current]), current)
  }

  private func consumeString(from start: String.Index) throws -> (String, String.Index) {
    var current = sql.index(after: start)
    var value = ""
    while current < sql.endIndex {
      let character = sql[current]
      if character == "'" {
        let next = sql.index(after: current)
        if next < sql.endIndex, sql[next] == "'" {
          value.append("'")
          current = sql.index(after: next)
          continue
        }
        return (value, next)
      }
      value.append(character)
      current = sql.index(after: current)
    }

    throw DdlParseFailure.expected("closing quote")
  }

  private func consumeQuotedIdentifier(from start: String.Index, quote: Character) throws -> (
    String, String.Index
  ) {
    var current = sql.index(after: start)
    var value = ""

    while current < sql.endIndex {
      let character = sql[current]
      if character == quote {
        return (value, sql.index(after: current))
      }
      value.append(character)
      current = sql.index(after: current)
    }

    throw DdlParseFailure.expected("closing identifier quote")
  }

  private func consumeBracketIdentifier(from start: String.Index) throws -> (String, String.Index) {
    var current = sql.index(after: start)
    var value = ""

    while current < sql.endIndex {
      let character = sql[current]
      if character == "]" {
        return (value, sql.index(after: current))
      }
      value.append(character)
      current = sql.index(after: current)
    }

    throw DdlParseFailure.expected("closing bracket identifier")
  }
}
