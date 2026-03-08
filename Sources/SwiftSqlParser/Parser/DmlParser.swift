import Foundation

struct DmlParser {
  private let tokens: [Token]
  private let options: ParserOptions
  private var index: Int = 0

  init(sql: String, options: ParserOptions) throws {
    self.options = options
    self.tokens = try Tokenizer(sql: sql, options: options).tokenize()
  }

  mutating func parseStatement() throws -> any Statement {
    if matchKeyword("MERGE") {
      return try parseMerge()
    }

    if matchKeyword("REPLACE") {
      return try parseReplace()
    }

    if matchKeyword("INSERT") {
      return try parseInsert()
    }

    if matchKeyword("UPDATE") {
      return try parseUpdate()
    }

    if matchKeyword("DELETE") {
      return try parseDelete()
    }

    throw DmlParseFailure.expected("DML statement")
  }

  private mutating func parseMerge() throws -> MergeStatement {
    guard options.experimentalFeatures.contains(.mergeStatements),
      options.dialectFeatures.contains(.sqlServer) || options.dialectFeatures.contains(.oracle)
    else {
      throw DmlParseFailure.expected("MERGE enabled by dialect options")
    }

    try consumeKeyword("INTO")
    let targetTable = try consumeIdentifier()
    let targetAlias = try parseAliasIfPresent()

    try consumeKeyword("USING")
    let source = try parseTrailingSelectStatement(until: [["ON"]])
    let sourceAlias = try parseAliasIfPresent()
    try consumeKeyword("ON")
    let onCondition = try parseExpression()

    var clauses: [MergeClause] = []
    while matchKeyword("WHEN") {
      let isMatched: Bool
      if matchKeyword("MATCHED") {
        isMatched = true
      } else {
        try consumeKeyword("NOT")
        try consumeKeyword("MATCHED")
        isMatched = false
      }

      let predicate: String?
      if matchKeyword("AND") {
        predicate = try collectKeywordClauseUntilBoundary(boundaryStarts: [["THEN"]])
      } else {
        predicate = nil
      }

      try consumeKeyword("THEN")
      let action = try collectKeywordClauseUntilBoundary(boundaryStarts: [["WHEN"]])
      clauses.append(MergeClause(isMatched: isMatched, predicate: predicate, action: action))
    }

    try ensureAtEnd()
    return MergeStatement(
      targetTable: targetTable,
      targetAlias: targetAlias,
      source: source,
      sourceAlias: sourceAlias,
      onCondition: onCondition,
      clauses: clauses
    )
  }

  private mutating func parseReplace() throws -> ReplaceStatement {
    guard options.experimentalFeatures.contains(.replaceStatements),
      options.dialectFeatures.contains(.mysql)
    else {
      throw DmlParseFailure.expected("REPLACE enabled by dialect options")
    }

    try consumeKeyword("INTO")
    let table = try consumeIdentifier()

    var columns: [String] = []
    if match(symbol: "(") {
      columns = try parseIdentifierListUntilRightParen()
    }

    let source: InsertStatement.Source
    if matchKeyword("VALUES") {
      var rows: [[any Expression]] = []
      repeat {
        try consumeSymbol("(")
        rows.append(try parseExpressionListUntilRightParen())
      } while match(symbol: ",")
      source = .values(rows)
    } else {
      source = .select(try parseTrailingSelectStatement(until: []))
    }

    try ensureAtEnd()
    return ReplaceStatement(table: table, columns: columns, source: source)
  }

  private mutating func parseInsert() throws -> InsertStatement {
    try consumeKeyword("INTO")
    let table = try consumeIdentifier()

    var columns: [String] = []
    if match(symbol: "(") {
      columns = try parseIdentifierListUntilRightParen()
    }

    let source: InsertStatement.Source
    if matchKeyword("DEFAULT") {
      try consumeKeyword("VALUES")
      source = .defaultValues
    } else if matchKeyword("VALUES") {
      var rows: [[any Expression]] = []

      repeat {
        try consumeSymbol("(")
        let values = try parseExpressionListUntilRightParen()
        rows.append(values)
      } while match(symbol: ",")

      source = .values(rows)
    } else {
      source = .select(
        try parseTrailingSelectStatement(until: [
          ["ON", "CONFLICT"], ["ON", "DUPLICATE", "KEY", "UPDATE"], ["RETURNING"],
        ]))
    }

    let onConflict = try parseOnConflictClauseIfPresent()
    let onDuplicateKeyAssignments = try parseOnDuplicateKeyUpdateIfPresent()
    let returningClause = try parseReturningClauseIfPresent()

    try ensureAtEnd()
    return InsertStatement(
      table: table,
      columns: columns,
      source: source,
      onConflict: onConflict,
      onDuplicateKeyAssignments: onDuplicateKeyAssignments,
      returningClause: returningClause
    )
  }

  private mutating func parseUpdate() throws -> UpdateStatement {
    let table = try consumeIdentifier()
    try consumeKeyword("SET")

    let assignments = try parseAssignments()

    let from: (any FromItem)?
    let fromJoins: [Join]
    if matchKeyword("FROM") {
      from = try parseFromItem()
      fromJoins = try parseJoins()
    } else {
      from = nil
      fromJoins = []
    }

    let whereExpression: (any Expression)?
    if matchKeyword("WHERE") {
      whereExpression = try parseExpression()
    } else {
      whereExpression = nil
    }

    let returningClause = try parseReturningClauseIfPresent()

    try ensureAtEnd()
    return UpdateStatement(
      table: table,
      assignments: assignments,
      from: from,
      fromJoins: fromJoins,
      whereExpression: whereExpression,
      returningClause: returningClause
    )
  }

  private mutating func parseDelete() throws -> DeleteStatement {
    try consumeKeyword("FROM")
    let table = try consumeIdentifier()

    let usingItems = try parseUsingClauseIfPresent()

    let whereExpression: (any Expression)?
    if matchKeyword("WHERE") {
      whereExpression = try parseExpression()
    } else {
      whereExpression = nil
    }

    let returningClause = try parseReturningClauseIfPresent()

    try ensureAtEnd()
    return DeleteStatement(
      table: table,
      usingItems: usingItems,
      whereExpression: whereExpression,
      returningClause: returningClause
    )
  }

  private mutating func parseAssignments() throws -> [UpdateAssignment] {
    var assignments: [UpdateAssignment] = []
    while true {
      let column = try consumeIdentifier()
      try consumeSymbol("=")
      let value = try parseExpression()
      assignments.append(UpdateAssignment(column: column, value: value))

      if match(symbol: ",") {
        continue
      }

      break
    }
    return assignments
  }

  private mutating func parseReturningClauseIfPresent() throws -> ReturningClause? {
    guard matchKeyword("RETURNING") else {
      return nil
    }
    return ReturningClause(items: try parseSelectItemsUntilBoundary())
  }

  private mutating func parseOnConflictClauseIfPresent() throws -> InsertOnConflictClause? {
    guard checkKeywordSequence(["ON", "CONFLICT"]) else {
      return nil
    }
    try consumeKeyword("ON")
    try consumeKeyword("CONFLICT")

    var targetColumns: [String] = []
    if match(symbol: "(") {
      targetColumns = try parseIdentifierListUntilRightParen()
    }

    try consumeKeyword("DO")
    if matchKeyword("NOTHING") {
      return InsertOnConflictClause(targetColumns: targetColumns, action: .doNothing)
    }

    try consumeKeyword("UPDATE")
    try consumeKeyword("SET")
    let assignments = try parseAssignments()
    let whereExpression: (any Expression)?
    if matchKeyword("WHERE") {
      whereExpression = try parseExpression()
    } else {
      whereExpression = nil
    }

    return InsertOnConflictClause(
      targetColumns: targetColumns,
      action: .doUpdate(assignments: assignments, whereExpression: whereExpression)
    )
  }

  private mutating func parseOnDuplicateKeyUpdateIfPresent() throws -> [UpdateAssignment] {
    guard checkKeywordSequence(["ON", "DUPLICATE", "KEY", "UPDATE"]) else {
      return []
    }
    try consumeKeyword("ON")
    try consumeKeyword("DUPLICATE")
    try consumeKeyword("KEY")
    try consumeKeyword("UPDATE")
    return try parseAssignments()
  }

  private mutating func parseUsingClauseIfPresent() throws -> [any FromItem] {
    guard matchKeyword("USING") else {
      return []
    }

    var items: [any FromItem] = []
    while true {
      items.append(try parseFromItem())
      if match(symbol: ",") {
        continue
      }
      break
    }
    return items
  }

  private mutating func parseSelectItemsUntilBoundary() throws -> [any SelectItem] {
    var items: [any SelectItem] = []

    while true {
      if match(symbol: "*") {
        items.append(AllColumnsSelectItem())
      } else {
        let expression = try parseExpression()
        let alias = try parseAliasIfPresent()
        items.append(ExpressionSelectItem(expression: expression, alias: alias))
      }

      if match(symbol: ",") {
        continue
      }
      break
    }

    return items
  }

  private mutating func parseAliasIfPresent() throws -> String? {
    if matchKeyword("AS") {
      return try consumeIdentifier()
    }

    guard let next = peek(), next.kind == .identifier else {
      return nil
    }

    let boundaryKeywords = [
      "FROM", "WHERE", "GROUP", "HAVING", "ORDER", "LIMIT", "OFFSET", "ON", "RETURNING",
      "INNER", "LEFT", "RIGHT", "FULL", "CROSS", "JOIN", "USING",
    ]
    if boundaryKeywords.contains(next.uppercased) {
      return nil
    }

    _ = advance()
    return next.text
  }

  private mutating func parseFromItem() throws -> any FromItem {
    if match(symbol: "(") {
      let nestedSql = try collectBalancedParenthesisText()
      let nestedStatement = try SqlParser().parseStatement(nestedSql, options: options)
      let alias = try parseAliasIfPresent()
      return SubqueryFromItem(statement: nestedStatement, alias: alias)
    }

    let tableName = try consumeIdentifier()
    let alias = try parseAliasIfPresent()
    return TableFromItem(name: tableName, alias: alias)
  }

  private mutating func parseJoins() throws -> [Join] {
    var joins: [Join] = []

    while true {
      let joinType: Join.JoinType
      if matchKeyword("INNER") {
        try consumeKeyword("JOIN")
        joinType = .inner
      } else if matchKeyword("LEFT") {
        try consumeKeyword("JOIN")
        joinType = .left
      } else if matchKeyword("RIGHT") {
        try consumeKeyword("JOIN")
        joinType = .right
      } else if matchKeyword("FULL") {
        try consumeKeyword("JOIN")
        joinType = .full
      } else if matchKeyword("CROSS") {
        try consumeKeyword("JOIN")
        joinType = .cross
      } else if matchKeyword("JOIN") {
        joinType = .inner
      } else {
        break
      }

      let fromItem = try parseFromItem()
      let onExpression: (any Expression)?
      if joinType != .cross && matchKeyword("ON") {
        onExpression = try parseExpression()
      } else {
        onExpression = nil
      }

      joins.append(Join(type: joinType, fromItem: fromItem, onExpression: onExpression))
    }

    return joins
  }

  private mutating func parseTrailingSelectStatement(until keywordSequences: [[String]]) throws
    -> any Statement
  {
    let sql = try collectTrailingSqlUntilTopLevelKeywords(keywordSequences)
    return try SqlParser().parseStatement(sql, options: options)
  }

  private mutating func collectKeywordClauseUntilBoundary(boundaryStarts: [[String]]) throws
    -> String
  {
    let start = index
    var depth = 0
    var current = index

    while current < tokens.count {
      let token = tokens[current]
      if token.kind == .symbol, token.text == "(" {
        depth += 1
      } else if token.kind == .symbol, token.text == ")" {
        depth -= 1
      }

      if depth == 0 {
        for sequence in boundaryStarts where matchesKeywordSequence(sequence, at: current) {
          let sql = tokens[start..<current].map(\.sqlText).joined(separator: " ")
          index = current
          return sql
        }
      }

      current += 1
    }

    index = tokens.count
    return tokens[start..<tokens.count].map(\.sqlText).joined(separator: " ")
  }

  private mutating func collectTrailingSqlUntilTopLevelKeywords(_ keywordSequences: [[String]])
    throws -> String
  {
    let start = index
    var depth = 0
    var current = index

    while current < tokens.count {
      let token = tokens[current]
      if token.kind == .symbol, token.text == "(" {
        depth += 1
      } else if token.kind == .symbol, token.text == ")" {
        depth -= 1
      }

      if depth == 0 {
        for sequence in keywordSequences where matchesKeywordSequence(sequence, at: current) {
          let sql = tokens[start..<current].map(\.sqlText).joined(separator: " ")
          index = current
          return sql
        }
      }

      current += 1
    }

    index = tokens.count
    return tokens[start..<tokens.count].map(\.sqlText).joined(separator: " ")
  }

  private func matchesKeywordSequence(_ sequence: [String], at start: Int) -> Bool {
    guard start + sequence.count <= tokens.count else {
      return false
    }

    for (offset, keyword) in sequence.enumerated() {
      let token = tokens[start + offset]
      guard token.kind == .identifier, token.uppercased == keyword else {
        return false
      }
    }

    return true
  }

  private func checkKeywordSequence(_ sequence: [String]) -> Bool {
    matchesKeywordSequence(sequence, at: index)
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

  private mutating func parseExpressionListUntilRightParen() throws -> [any Expression] {
    var expressions: [any Expression] = []
    while true {
      expressions.append(try parseExpression())
      if match(symbol: ",") {
        continue
      }
      try consumeSymbol(")")
      return expressions
    }
  }

  private mutating func parseExpression() throws -> any Expression {
    try parseOrExpression()
  }

  private mutating func parseOrExpression() throws -> any Expression {
    var expression = try parseAndExpression()
    while matchKeyword("OR") {
      let rhs = try parseAndExpression()
      expression = BinaryExpression(left: expression, operator: .or, right: rhs)
    }
    return expression
  }

  private mutating func parseAndExpression() throws -> any Expression {
    var expression = try parseComparisonExpression()
    while matchKeyword("AND") {
      let rhs = try parseComparisonExpression()
      expression = BinaryExpression(left: expression, operator: .and, right: rhs)
    }
    return expression
  }

  private mutating func parseComparisonExpression() throws -> any Expression {
    var expression = try parseAdditiveExpression()

    while true {
      if match(symbol: "=") {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .equals, right: rhs)
      } else if match(symbol: "<") {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .lessThan, right: rhs)
      } else if match(symbol: "<=") {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .lessThanOrEquals, right: rhs)
      } else if match(symbol: ">") {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .greaterThan, right: rhs)
      } else if match(symbol: ">=") {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .greaterThanOrEquals, right: rhs)
      } else if options.dialectFeatures.contains(.postgres)
        && options.experimentalFeatures.contains(.postgresIlike)
        && matchKeyword("ILIKE")
      {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .ilike, right: rhs)
      } else if matchKeyword("LIKE") {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .like, right: rhs)
      } else if matchKeyword("NOT") && matchKeyword("LIKE") {
        let rhs = try parseAdditiveExpression()
        let likeExpression = BinaryExpression(left: expression, operator: .like, right: rhs)
        expression = UnaryExpression(operator: .not, expression: likeExpression)
      } else if match(symbol: "<>") || match(symbol: "!=") {
        let rhs = try parseAdditiveExpression()
        expression = BinaryExpression(left: expression, operator: .notEquals, right: rhs)
      } else if matchKeyword("IS") {
        let isNegated = matchKeyword("NOT")
        try consumeKeyword("NULL")
        expression = IsNullExpression(expression: expression, isNegated: isNegated)
      } else if matchKeyword("NOT") && matchKeyword("IN") {
        expression = try parseInListExpression(expression: expression, isNegated: true)
      } else if matchKeyword("IN") {
        expression = try parseInListExpression(expression: expression)
      } else if matchKeyword("NOT") && matchKeyword("BETWEEN") {
        expression = try parseBetweenExpression(expression: expression, isNegated: true)
      } else if matchKeyword("BETWEEN") {
        expression = try parseBetweenExpression(expression: expression)
      } else {
        break
      }
    }

    return expression
  }

  private mutating func parseAdditiveExpression() throws -> any Expression {
    var expression = try parseMultiplicativeExpression()

    while true {
      if match(symbol: "+") {
        let rhs = try parseMultiplicativeExpression()
        expression = BinaryExpression(left: expression, operator: .plus, right: rhs)
      } else if match(symbol: "-") {
        let rhs = try parseMultiplicativeExpression()
        expression = BinaryExpression(left: expression, operator: .minus, right: rhs)
      } else {
        break
      }
    }

    return expression
  }

  private mutating func parseMultiplicativeExpression() throws -> any Expression {
    var expression = try parseUnaryExpression()

    while true {
      if match(symbol: "*") {
        let rhs = try parseUnaryExpression()
        expression = BinaryExpression(left: expression, operator: .multiply, right: rhs)
      } else if match(symbol: "/") {
        let rhs = try parseUnaryExpression()
        expression = BinaryExpression(left: expression, operator: .divide, right: rhs)
      } else {
        break
      }
    }

    return expression
  }

  private mutating func parseUnaryExpression() throws -> any Expression {
    if match(symbol: "+") {
      return UnaryExpression(operator: .plus, expression: try parseUnaryExpression())
    }
    if match(symbol: "-") {
      return UnaryExpression(operator: .minus, expression: try parseUnaryExpression())
    }
    if matchKeyword("NOT") {
      return UnaryExpression(operator: .not, expression: try parseUnaryExpression())
    }
    if matchKeyword("EXISTS") {
      try consumeSymbol("(")
      let nestedSql = try collectBalancedParenthesisText()
      let select = try SqlParser().parseStatement(nestedSql, options: options)
      return ExistsExpression(statement: select)
    }

    return try parsePostfixExpression()
  }

  private mutating func parsePostfixExpression() throws -> any Expression {
    var expression = try parsePrimaryExpression()

    while match(symbol: "::") {
      let typeName = try parseTypeName()
      expression = CastExpression(expression: expression, typeName: typeName, style: .postgres)
    }

    return expression
  }

  private mutating func parsePrimaryExpression() throws -> any Expression {
    if match(symbol: "(") {
      if checkKeyword("SELECT") || checkKeyword("WITH") {
        let nestedSql = try collectBalancedParenthesisText()
        let select = try SqlParser().parseStatement(nestedSql, options: options)
        return SubqueryExpression(statement: select)
      }
      let expression = try parseExpression()
      try consumeSymbol(")")
      return expression
    }

    if let number = consumeNumberIfPresent() {
      return NumberLiteralExpression(value: number)
    }

    if let stringValue = consumeStringIfPresent() {
      return StringLiteralExpression(value: stringValue)
    }

    if matchKeyword("NULL") {
      return NullLiteralExpression()
    }

    if let placeholder = consumePlaceholderIfPresent() {
      return PlaceholderExpression(token: placeholder)
    }

    if matchKeyword("CASE") {
      return try parseCaseExpression()
    }

    if matchKeyword("CAST") {
      return try parseCastExpression()
    }

    let identifier = try consumeIdentifier()
    if match(symbol: "(") {
      var args: [any Expression] = []
      if match(symbol: ")") == false {
        while true {
          args.append(try parseExpression())
          if match(symbol: ",") {
            continue
          }
          try consumeSymbol(")")
          break
        }
      }
      return FunctionExpression(name: identifier, arguments: args)
    }

    return IdentifierExpression(name: identifier)
  }

  private mutating func parseInListExpression(expression: any Expression, isNegated: Bool = false)
    throws -> any Expression
  {
    try consumeSymbol("(")
    var values: [any Expression] = []
    if match(symbol: ")") == false {
      while true {
        values.append(try parseExpression())
        if match(symbol: ",") {
          continue
        }
        try consumeSymbol(")")
        break
      }
    }
    return InListExpression(expression: expression, values: values, isNegated: isNegated)
  }

  private mutating func parseBetweenExpression(expression: any Expression, isNegated: Bool = false)
    throws -> any Expression
  {
    let lowerBound = try parseAdditiveExpression()
    try consumeKeyword("AND")
    let upperBound = try parseAdditiveExpression()
    return BetweenExpression(
      expression: expression, lowerBound: lowerBound, upperBound: upperBound, isNegated: isNegated)
  }

  private mutating func parseCaseExpression() throws -> any Expression {
    let baseExpression: (any Expression)?
    if checkKeyword("WHEN") {
      baseExpression = nil
    } else {
      baseExpression = try parseExpression()
    }

    var whenClauses: [CaseWhenClause] = []
    while matchKeyword("WHEN") {
      let condition = try parseExpression()
      try consumeKeyword("THEN")
      let result = try parseExpression()
      whenClauses.append(CaseWhenClause(condition: condition, result: result))
    }

    let elseExpression: (any Expression)?
    if matchKeyword("ELSE") {
      elseExpression = try parseExpression()
    } else {
      elseExpression = nil
    }

    try consumeKeyword("END")
    return CaseExpression(
      baseExpression: baseExpression, whenClauses: whenClauses, elseExpression: elseExpression)
  }

  private mutating func parseCastExpression() throws -> any Expression {
    try consumeSymbol("(")
    let expression = try parseExpression()
    try consumeKeyword("AS")
    let typeName = try parseTypeName()
    try consumeSymbol(")")
    return CastExpression(expression: expression, typeName: typeName)
  }

  private mutating func parseTypeName() throws -> String {
    var typeName = try consumeIdentifier()

    if match(symbol: "(") {
      var components: [String] = []
      while true {
        guard let token = advance() else {
          throw DmlParseFailure.expected("type modifier")
        }
        if token.kind == .symbol, token.text == ")" {
          break
        }
        components.append(token.text)
      }
      typeName += "(\(components.joined(separator: " ")))"
    }

    return typeName
  }

  private mutating func ensureAtEnd() throws {
    guard peek() == nil else {
      throw DmlParseFailure.unexpectedToken(peek()?.text ?? "")
    }
  }

  private mutating func consumeKeyword(_ keyword: String) throws {
    guard matchKeyword(keyword) else {
      throw DmlParseFailure.expected(keyword)
    }
  }

  private mutating func consumeSymbol(_ symbol: String) throws {
    guard match(symbol: symbol) else {
      throw DmlParseFailure.expected(symbol)
    }
  }

  private mutating func consumeIdentifier() throws -> String {
    guard let first = peek(), first.kind == .identifier else {
      throw DmlParseFailure.expected("identifier")
    }
    _ = advance()

    var identifier = first.text
    while match(symbol: ".") {
      guard let next = peek(), next.kind == .identifier else {
        throw DmlParseFailure.expected("identifier after '.'")
      }
      _ = advance()
      identifier += ".\(next.text)"
    }

    return identifier
  }

  private mutating func consumeNumberIfPresent() -> Double? {
    guard let token = peek(), token.kind == .number else {
      return nil
    }
    _ = advance()
    return Double(token.text)
  }

  private mutating func consumeStringIfPresent() -> String? {
    guard let token = peek(), token.kind == .string else {
      return nil
    }
    _ = advance()
    return token.text
  }

  private mutating func consumePlaceholderIfPresent() -> String? {
    guard let token = peek(), token.kind == .placeholder else {
      return nil
    }
    _ = advance()
    return token.text
  }

  private mutating func collectBalancedParenthesisText() throws -> String {
    var depth = 1
    var collected: [String] = []

    while let token = advance() {
      if token.kind == .symbol, token.text == "(" {
        depth += 1
      } else if token.kind == .symbol, token.text == ")" {
        depth -= 1
        if depth == 0 {
          return collected.joined(separator: " ")
        }
      }

      collected.append(token.sqlText)
    }

    throw DmlParseFailure.expected(")")
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

private enum DmlParseFailure: Error {
  case expected(String)
  case unexpectedToken(String)
}

private struct Token {
  enum Kind {
    case identifier
    case number
    case string
    case placeholder
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

      if character == "q" || character == "Q",
        options.dialectFeatures.contains(.oracle),
        options.experimentalFeatures.contains(.oracleAlternativeQuoting),
        let (value, nextIndex) = try consumeOracleAlternativeStringIfPresent(from: index)
      {
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

      if character == "?" {
        tokens.append(Token(text: String(character), kind: .placeholder))
        index = sql.index(after: index)
        continue
      }

      if character == "$" {
        let (placeholder, nextIndex) = consumePlaceholder(from: index)
        tokens.append(Token(text: placeholder, kind: .placeholder))
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
        if ["<>", "!=", ">=", "<=", "||", "::"].contains(pair) {
          tokens.append(Token(text: pair, kind: .symbol))
          index = sql.index(after: nextIndex)
          continue
        }
      }

      if [",", "*", "(", ")", "=", "+", "-", "/", ".", "<", ">"].contains(character) {
        tokens.append(Token(text: String(character), kind: .symbol))
        index = nextIndex
        continue
      }

      throw DmlParseFailure.unexpectedToken(String(character))
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
    var sawDot = false

    while current < sql.endIndex {
      let character = sql[current]
      if character.isNumber {
        current = sql.index(after: current)
        continue
      }

      if character == "." && sawDot == false {
        sawDot = true
        current = sql.index(after: current)
        continue
      }

      break
    }

    return (String(sql[start..<current]), current)
  }

  private func consumePlaceholder(from start: String.Index) -> (String, String.Index) {
    var current = sql.index(after: start)
    while current < sql.endIndex, sql[current].isNumber {
      current = sql.index(after: current)
    }
    return (String(sql[start..<current]), current)
  }

  private func consumeOracleAlternativeStringIfPresent(from start: String.Index) throws -> (
    String, String.Index
  )? {
    guard start < sql.endIndex, sql[start] == "q" || sql[start] == "Q" else {
      return nil
    }
    let quoteIndex = sql.index(after: start)
    guard quoteIndex < sql.endIndex, sql[quoteIndex] == "'" else {
      return nil
    }
    let openerIndex = sql.index(after: quoteIndex)
    guard openerIndex < sql.endIndex else {
      throw DmlParseFailure.expected("oracle q quote opener")
    }
    let opener = sql[openerIndex]
    let closer: Character =
      switch opener {
      case "[": "]"
      case "(": ")"
      case "{": "}"
      case "<": ">"
      default: opener
      }
    var current = sql.index(after: openerIndex)
    var value = ""
    while current < sql.endIndex {
      if sql[current] == closer {
        let quoteEnd = sql.index(after: current)
        guard quoteEnd < sql.endIndex, sql[quoteEnd] == "'" else {
          throw DmlParseFailure.expected("oracle q closing quote")
        }
        return (value, sql.index(after: quoteEnd))
      }
      value.append(sql[current])
      current = sql.index(after: current)
    }
    throw DmlParseFailure.expected("oracle q closing quote")
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

    throw DmlParseFailure.expected("closing quote")
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

    throw DmlParseFailure.expected("closing identifier quote")
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

    throw DmlParseFailure.expected("closing bracket identifier")
  }
}
