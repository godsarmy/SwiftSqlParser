import Foundation

struct SelectCoreParser {
  private let tokens: [Token]
  private let options: ParserOptions
  private var index: Int = 0

  init(sql: String, options: ParserOptions) throws {
    self.options = options
    self.tokens = try Tokenizer(sql: sql, options: options).tokenize()
  }

  private init(tokens: [Token], options: ParserOptions) {
    self.tokens = tokens
    self.options = options
  }

  mutating func parseStatement() throws -> any Statement {
    let statement: any Statement
    if matchKeyword("WITH") {
      statement = try parseWithSelect()
    } else {
      statement = try parseSetOperationChain()
    }

    try ensureAtEnd()
    return statement
  }

  private mutating func parseWithSelect() throws -> WithSelect {
    var expressions: [CommonTableExpression] = []

    while true {
      let name = try consumeIdentifier()
      try consumeKeyword("AS")
      try consumeSymbol("(")
      let cteTokens = try collectBalancedParenthesisContent()
      var nested = SelectCoreParser(tokens: cteTokens, options: options)
      let cteStatement = try nested.parseStatement()
      expressions.append(CommonTableExpression(name: name, statement: cteStatement))

      if match(symbol: ",") {
        continue
      }

      break
    }

    let body = try parseSetOperationChain()
    return WithSelect(expressions: expressions, body: body)
  }

  private mutating func parseSetOperationChain() throws -> any Statement {
    var statement: any Statement = try parsePrimarySelectStatement()

    while true {
      let operation: SetOperationSelect.Operation
      if matchKeyword("UNION") {
        operation = .union
      } else if matchKeyword("INTERSECT") {
        operation = .intersect
      } else if matchKeyword("EXCEPT") {
        operation = .except
      } else {
        break
      }

      let isAll = matchKeyword("ALL")
      let rhs = try parsePrimarySelectStatement()
      statement = SetOperationSelect(
        left: statement, operation: operation, isAll: isAll, right: rhs)
    }

    return statement
  }

  private mutating func parsePrimarySelectStatement() throws -> any Statement {
    if match(symbol: "(") {
      let nestedTokens = try collectBalancedParenthesisContent()
      var nested = SelectCoreParser(tokens: nestedTokens, options: options)
      return try nested.parseStatement()
    }

    if checkKeyword("VALUES") {
      return try parseValuesSelect()
    }

    if checkKeyword("FROM") {
      return try parsePipedFromStatement()
    }

    return try parsePlainSelect()
  }

  private mutating func parsePipedFromStatement() throws -> any Statement {
    guard options.experimentalFeatures.contains(.pipedSql) else {
      throw SelectParseFailure.expected("Piped SQL requires experimental pipedSql feature")
    }

    try consumeKeyword("FROM")
    var from = try parseFromItem()
    var joins = try parseJoins()

    var isDistinct = false
    var selectItems: [any SelectItem] = [AllColumnsSelectItem()]
    var whereExpression: (any Expression)?
    var groupByExpressions: [any Expression] = []
    var havingExpression: (any Expression)?
    var qualifyExpression: (any Expression)?
    var orderBy: [OrderByElement] = []
    var limit: Int?
    var offset: Int?
    var statement: (any Statement)?

    func buildPlainSelect() -> PlainSelect {
      PlainSelect(
        isDistinct: isDistinct,
        selectItems: selectItems,
        from: from,
        joins: joins,
        whereExpression: whereExpression,
        groupByExpressions: groupByExpressions,
        havingExpression: havingExpression,
        qualifyExpression: qualifyExpression,
        orderBy: orderBy,
        limit: limit,
        offset: offset
      )
    }

    func buildCurrentStatement() -> any Statement {
      statement ?? buildPlainSelect()
    }

    func resetSelectPipeline(with fromItem: any FromItem) {
      from = fromItem
      joins = []
      isDistinct = false
      selectItems = [AllColumnsSelectItem()]
      whereExpression = nil
      groupByExpressions = []
      havingExpression = nil
      qualifyExpression = nil
      orderBy = []
      limit = nil
      offset = nil
      statement = nil
    }

    func ensureSelectPipeline() {
      guard statement != nil else {
        return
      }

      resetSelectPipeline(with: SubqueryFromItem(statement: buildCurrentStatement()))
    }

    while match(symbol: "|>") {
      if matchKeyword("WHERE") {
        ensureSelectPipeline()
        whereExpression = try parseExpression()
        continue
      }

      if matchKeyword("SELECT") {
        ensureSelectPipeline()
        selectItems = try parseSelectItems()
        continue
      }

      if matchKeyword("DISTINCT") {
        ensureSelectPipeline()
        isDistinct = true
        continue
      }

      if matchKeyword("EXTEND") {
        ensureSelectPipeline()
        selectItems = appendPipeSelectItems(try parseSelectItems(), to: selectItems)
        continue
      }

      if matchKeyword("RENAME") {
        ensureSelectPipeline()
        selectItems = try applyPipeRename(try parseSelectItems(), to: selectItems)
        continue
      }

      if matchKeyword("DROP") {
        ensureSelectPipeline()
        selectItems = try applyPipeDrop(columns: try parsePipeIdentifierList(), to: selectItems)
        continue
      }

      if matchKeyword("ORDER") {
        ensureSelectPipeline()
        try consumeKeyword("BY")
        orderBy = try parseOrderByElements()
        continue
      }

      if matchKeyword("HAVING") {
        ensureSelectPipeline()
        havingExpression = try parseExpression()
        continue
      }

      if matchKeyword("QUALIFY") {
        ensureSelectPipeline()
        qualifyExpression = try parseExpression()
        continue
      }

      if matchKeyword("LIMIT") {
        ensureSelectPipeline()
        limit = try consumeIntegerLiteral()
        if matchKeyword("OFFSET") {
          offset = try consumeIntegerLiteral()
        }
        continue
      }

      if matchKeyword("OFFSET") {
        ensureSelectPipeline()
        offset = try consumeIntegerLiteral()
        continue
      }

      if matchKeyword("AS") {
        let alias = try consumeIdentifier()
        resetSelectPipeline(
          with: SubqueryFromItem(statement: buildCurrentStatement(), alias: alias))
        continue
      }

      if isPipeJoinStart() {
        ensureSelectPipeline()
        joins.append(try parseSingleJoin())
        continue
      }

      if matchKeyword("AGGREGATE") {
        ensureSelectPipeline()
        selectItems = try parseSelectItems()
        if matchKeyword("GROUP") {
          try consumeKeyword("BY")
          groupByExpressions = try parseExpressionList()
        } else {
          groupByExpressions = []
        }
        continue
      }

      if checkKeyword("PIVOT") || checkKeyword("UNPIVOT") {
        ensureSelectPipeline()
        from = try parsePivotOrUnpivotIfPresent(source: from)
        continue
      }

      if checkKeyword("TABLESAMPLE") {
        ensureSelectPipeline()
        from = try parseTableSampleIfPresent(source: from)
        continue
      }

      let operation: SetOperationSelect.Operation
      if matchKeyword("UNION") {
        operation = .union
      } else if matchKeyword("INTERSECT") {
        operation = .intersect
      } else if matchKeyword("EXCEPT") {
        operation = .except
      } else {
        throw SelectParseFailure.expected(
          "supported pipe operator (WHERE, SELECT, DISTINCT, EXTEND, RENAME, DROP, HAVING, QUALIFY, ORDER BY, LIMIT, OFFSET, AS, JOIN, AGGREGATE, PIVOT, UNPIVOT, TABLESAMPLE, UNION, INTERSECT, EXCEPT)"
        )
      }

      let isAll = matchKeyword("ALL")
      let lhs = buildCurrentStatement()
      let rhs = try parsePrimarySelectStatement()
      statement = SetOperationSelect(left: lhs, operation: operation, isAll: isAll, right: rhs)
    }

    return buildCurrentStatement()
  }

  private mutating func parsePipeIdentifierList() throws -> [String] {
    var columns: [String] = []

    while true {
      columns.append(try consumeIdentifier())
      if match(symbol: ",") {
        continue
      }
      break
    }

    return columns
  }

  private func appendPipeSelectItems(_ additions: [any SelectItem], to existing: [any SelectItem])
    -> [any SelectItem]
  {
    existing + additions
  }

  private func applyPipeRename(_ renameItems: [any SelectItem], to existing: [any SelectItem])
    throws
    -> [any SelectItem]
  {
    var renamed = existing

    for renameItem in renameItems {
      guard let expressionItem = renameItem as? ExpressionSelectItem,
        let alias = expressionItem.alias,
        let sourceName = identifierName(from: expressionItem.expression)
      else {
        throw SelectParseFailure.expected("RENAME requires source_column AS new_name")
      }

      if let allColumns = renamed.first as? AllColumnsSelectItem {
        let exceptColumns = Array(Set(allColumns.exceptColumns + [sourceName])).sorted()
        renamed[0] = AllColumnsSelectItem(
          exceptColumns: exceptColumns, replacements: allColumns.replacements)
        renamed.append(ExpressionSelectItem(expression: expressionItem.expression, alias: alias))
        continue
      }

      var didRename = false
      renamed = renamed.compactMap { item in
        guard let outputName = selectItemOutputName(item), outputName == sourceName else {
          return item
        }

        didRename = true
        if let renamedItem = item as? ExpressionSelectItem {
          return ExpressionSelectItem(expression: renamedItem.expression, alias: alias)
        }

        return item
      }

      if didRename == false {
        throw SelectParseFailure.expected("RENAME requires projected columns or * output")
      }
    }

    return renamed
  }

  private func applyPipeDrop(columns: [String], to existing: [any SelectItem]) throws
    -> [any SelectItem]
  {
    if let allColumns = existing.first as? AllColumnsSelectItem {
      let exceptColumns = Array(Set(allColumns.exceptColumns + columns)).sorted()
      var updated: [any SelectItem] = [
        AllColumnsSelectItem(exceptColumns: exceptColumns, replacements: allColumns.replacements)
      ]
      updated.append(
        contentsOf: existing.dropFirst().filter { item in
          guard let outputName = selectItemOutputName(item) else {
            return true
          }
          return columns.contains(outputName) == false
        })
      return updated
    }

    let filtered = existing.filter { item in
      guard let outputName = selectItemOutputName(item) else {
        return true
      }
      return columns.contains(outputName) == false
    }

    guard filtered.isEmpty == false else {
      throw SelectParseFailure.expected("DROP cannot remove every projected column")
    }

    return filtered
  }

  private func selectItemOutputName(_ item: any SelectItem) -> String? {
    if let expressionItem = item as? ExpressionSelectItem {
      if let alias = expressionItem.alias {
        return alias
      }
      return identifierName(from: expressionItem.expression)
    }

    return nil
  }

  private func identifierName(from expression: any Expression) -> String? {
    guard let identifier = expression as? IdentifierExpression else {
      return nil
    }
    return identifier.name.split(separator: ".").last.map(String.init)
  }

  private func isPipeJoinStart() -> Bool {
    checkKeyword("JOIN") || checkKeyword("INNER") || checkKeyword("LEFT") || checkKeyword("RIGHT")
      || checkKeyword("FULL") || checkKeyword("CROSS") || checkKeyword("OUTER")
      || checkKeyword("NATURAL")
  }

  private mutating func parseSingleJoin() throws -> Join {
    let joinType: Join.JoinType
    let isNatural: Bool
    if matchKeyword("INNER") {
      try consumeKeyword("JOIN")
      joinType = .inner
      isNatural = false
    } else if matchKeyword("LEFT") {
      try consumeKeyword("JOIN")
      joinType = .left
      isNatural = false
    } else if matchKeyword("RIGHT") {
      try consumeKeyword("JOIN")
      joinType = .right
      isNatural = false
    } else if matchKeyword("FULL") {
      try consumeKeyword("JOIN")
      joinType = .full
      isNatural = false
    } else if matchKeyword("CROSS") {
      if matchKeyword("APPLY") {
        joinType = .crossApply
      } else {
        try consumeKeyword("JOIN")
        joinType = .cross
      }
      isNatural = false
    } else if matchKeyword("OUTER") {
      try consumeKeyword("APPLY")
      joinType = .outerApply
      isNatural = false
    } else if matchKeyword("NATURAL") {
      isNatural = true
      if matchKeyword("LEFT") {
        try consumeKeyword("JOIN")
        joinType = .left
      } else if matchKeyword("RIGHT") {
        try consumeKeyword("JOIN")
        joinType = .right
      } else if matchKeyword("FULL") {
        try consumeKeyword("JOIN")
        joinType = .full
      } else {
        try consumeKeyword("JOIN")
        joinType = .inner
      }
    } else {
      try consumeKeyword("JOIN")
      joinType = .inner
      isNatural = false
    }

    let fromItem = try parseFromItem()
    let onExpression: (any Expression)?
    let usingColumns: [String]
    if joinType != .cross && joinType != .crossApply && joinType != .outerApply
      && matchKeyword("ON")
    {
      onExpression = try parseExpression()
      usingColumns = []
    } else if joinType != .crossApply && joinType != .outerApply && matchKeyword("USING") {
      try consumeSymbol("(")
      usingColumns = try parseIdentifierListUntilRightParen()
      onExpression = nil
    } else {
      onExpression = nil
      usingColumns = []
    }

    return Join(
      type: joinType,
      isNatural: isNatural,
      fromItem: fromItem,
      onExpression: onExpression,
      usingColumns: usingColumns
    )
  }

  private mutating func parseValuesSelect() throws -> ValuesSelect {
    try consumeKeyword("VALUES")
    var rows: [[any Expression]] = []

    repeat {
      try consumeSymbol("(")
      var row: [any Expression] = []
      if match(symbol: ")") == false {
        while true {
          row.append(try parseExpression())
          if match(symbol: ",") {
            continue
          }
          try consumeSymbol(")")
          break
        }
      }
      rows.append(row)
    } while match(symbol: ",")

    return ValuesSelect(rows: rows)
  }

  private mutating func parsePlainSelect() throws -> PlainSelect {
    try consumeKeyword("SELECT")
    let top = try parseTopClauseIfPresent()
    let isDistinct = matchKeyword("DISTINCT")
    let distinctOnExpressions = try parseDistinctOnClauseIfPresent(isDistinct: isDistinct)
    let selectQualifier = try parseBigQuerySelectQualifierIfPresent()
    let selectItems = try parseSelectItems()
    try consumeKeyword("FROM")
    let from = try parseFromItem()
    let joins = try parseJoins()
    let whereExpression = try parseWhereClauseIfPresent()
    let groupByExpressions = try parseGroupByClauseIfPresent()
    let havingExpression = try parseHavingClauseIfPresent()
    let qualifyExpression = try parseQualifyClauseIfPresent()
    let orderBy = try parseOrderByClauseIfPresent()
    let limit = try parseLimitClauseIfPresent()
    let offset = try parseOffsetClauseIfPresent()

    return PlainSelect(
      distinctOnExpressions: distinctOnExpressions,
      top: top,
      isDistinct: isDistinct,
      selectQualifier: selectQualifier,
      selectItems: selectItems,
      from: from,
      joins: joins,
      whereExpression: whereExpression,
      groupByExpressions: groupByExpressions,
      havingExpression: havingExpression,
      qualifyExpression: qualifyExpression,
      orderBy: orderBy,
      limit: limit,
      offset: offset
    )
  }

  private mutating func parseTopClauseIfPresent() throws -> Int? {
    guard checkKeyword("TOP") else {
      return nil
    }
    guard options.dialectFeatures.contains(.sqlServer) || options.dialectFeatures.contains(.sybase),
      options.experimentalFeatures.contains(.sqlServerTop)
    else {
      throw SelectParseFailure.expected("TOP enabled by dialect options")
    }
    _ = advance()
    return try consumeIntegerLiteral()
  }

  private mutating func parseDistinctOnClauseIfPresent(isDistinct: Bool) throws -> [any Expression]
  {
    guard isDistinct, checkKeyword("ON") else {
      return []
    }
    guard options.dialectFeatures.contains(.postgres),
      options.experimentalFeatures.contains(.postgresDistinctOn)
    else {
      throw SelectParseFailure.expected("DISTINCT ON enabled by dialect options")
    }

    try consumeKeyword("ON")
    try consumeSymbol("(")
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

  private mutating func parseSelectItems() throws -> [any SelectItem] {
    var items: [any SelectItem] = []

    while true {
      if match(symbol: "*") {
        items.append(try parseAllColumnsSelectItem())
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

    if items.isEmpty {
      throw SelectParseFailure.expected("select item")
    }

    return items
  }

  private mutating func parseAllColumnsSelectItem() throws -> AllColumnsSelectItem {
    var exceptColumns: [String] = []
    var replacements: [AllColumnsSelectItem.Replacement] = []

    while true {
      if matchKeyword("EXCEPT") {
        guard options.dialectFeatures.contains(.bigQuery) else {
          throw SelectParseFailure.expected("EXCEPT in SELECT * requires BigQuery dialect")
        }
        try consumeSymbol("(")
        exceptColumns = try parseIdentifierListUntilRightParen()
        continue
      }

      if matchKeyword("REPLACE") {
        guard options.dialectFeatures.contains(.bigQuery) else {
          throw SelectParseFailure.expected("REPLACE in SELECT * requires BigQuery dialect")
        }
        try consumeSymbol("(")
        while true {
          let expression = try parseExpression()
          try consumeKeyword("AS")
          let alias = try consumeIdentifier()
          replacements.append(.init(expression: expression, alias: alias))
          if match(symbol: ",") {
            continue
          }
          try consumeSymbol(")")
          break
        }
        continue
      }

      break
    }

    return AllColumnsSelectItem(exceptColumns: exceptColumns, replacements: replacements)
  }

  private mutating func parseAliasIfPresent() throws -> String? {
    if matchKeyword("AS") {
      return try consumeIdentifier()
    }

    guard let next = peek(), next.kind == .identifier else {
      return nil
    }

    let keywordBoundary = [
      "FROM", "WHERE", "INNER", "LEFT", "RIGHT", "FULL", "CROSS", "JOIN", "ON", "USING", "APPLY",
      "PIVOT", "UNPIVOT", "TABLESAMPLE",
      "UNION", "INTERSECT", "EXCEPT", "ALL", "GROUP", "HAVING", "QUALIFY", "ORDER", "LIMIT",
      "OFFSET", "AT", "BEFORE", "CHANGES", "FOR",
    ]
    if keywordBoundary.contains(next.uppercased) {
      return nil
    }

    _ = advance()
    return next.text
  }

  private mutating func parseFromItem() throws -> any FromItem {
    let isLateral = matchKeyword("LATERAL")

    var fromItem: any FromItem

    if match(symbol: "(") {
      let nestedTokens = try collectBalancedParenthesisContent()
      var nested = SelectCoreParser(tokens: nestedTokens, options: options)
      let nestedStatement = try nested.parseStatement()
      let alias = try parseAliasIfPresent()
      fromItem = SubqueryFromItem(statement: nestedStatement, alias: alias, isLateral: isLateral)
    } else {
      let tableName = try consumeIdentifier()
      let timeTravelClause = try parseTimeTravelClauseIfPresent()
      let alias = try parseAliasIfPresent()
      let timeTravelClauseAfterAlias = try parseTimeTravelClauseIfPresent()
      fromItem = TableFromItem(
        name: tableName,
        timeTravelClause: timeTravelClause,
        alias: alias,
        timeTravelClauseAfterAlias: timeTravelClauseAfterAlias,
        isLateral: isLateral
      )
    }

    let pivoted = try parsePivotOrUnpivotIfPresent(source: fromItem)
    return try parseTableSampleIfPresent(source: pivoted)
  }

  private mutating func parseTableSampleIfPresent(source: any FromItem) throws -> any FromItem {
    guard matchKeyword("TABLESAMPLE") else {
      return source
    }

    let method = try consumeIdentifier()
    try consumeSymbol("(")
    let size = try consumeNumberLiteralText()
    let unit = try consumeIdentifier()
    try consumeSymbol(")")
    return TableSampleFromItem(source: source, method: method, size: size, unit: unit)
  }

  private mutating func parsePivotOrUnpivotIfPresent(source: any FromItem) throws -> any FromItem {
    if matchKeyword("PIVOT") {
      guard options.experimentalFeatures.contains(.pivotSyntax),
        options.dialectFeatures.contains(.sqlServer) || options.dialectFeatures.contains(.sybase)
          || options.dialectFeatures.contains(.oracle)
      else {
        throw SelectParseFailure.expected("PIVOT enabled by dialect options")
      }

      try consumeSymbol("(")
      let aggregateName = try consumeIdentifier()
      try consumeSymbol("(")
      let aggregateArguments = try parseExpressionListUntilRightParen()
      let aggregateFunction = FunctionExpression(name: aggregateName, arguments: aggregateArguments)
      try consumeKeyword("FOR")
      let pivotColumn = try consumeIdentifier()
      try consumeKeyword("IN")
      try consumeSymbol("(")
      var values: [PivotValue] = []
      while true {
        let expression = try parseExpression()
        let alias = try parseAliasIfPresent()
        values.append(PivotValue(expression: expression, alias: alias))
        if match(symbol: ",") {
          continue
        }
        try consumeSymbol(")")
        break
      }
      try consumeSymbol(")")
      let alias = try parseAliasIfPresent()
      return PivotFromItem(
        source: source, aggregateFunction: aggregateFunction, pivotColumn: pivotColumn,
        values: values, alias: alias)
    }

    if matchKeyword("UNPIVOT") {
      guard options.experimentalFeatures.contains(.pivotSyntax),
        options.dialectFeatures.contains(.sqlServer) || options.dialectFeatures.contains(.sybase)
          || options.dialectFeatures.contains(.oracle)
      else {
        throw SelectParseFailure.expected("UNPIVOT enabled by dialect options")
      }

      try consumeSymbol("(")
      let valueColumn = try consumeIdentifier()
      try consumeKeyword("FOR")
      let nameColumn = try consumeIdentifier()
      try consumeKeyword("IN")
      try consumeSymbol("(")
      let columns = try parseIdentifierListUntilRightParen()
      try consumeSymbol(")")
      let alias = try parseAliasIfPresent()
      return UnpivotFromItem(
        source: source, valueColumn: valueColumn, nameColumn: nameColumn, columns: columns,
        alias: alias)
    }

    return source
  }

  private mutating func parseJoins() throws -> [Join] {
    var joins: [Join] = []

    while true {
      let joinType: Join.JoinType
      let isNatural: Bool
      if matchKeyword("INNER") {
        try consumeKeyword("JOIN")
        joinType = .inner
        isNatural = false
      } else if matchKeyword("LEFT") {
        try consumeKeyword("JOIN")
        joinType = .left
        isNatural = false
      } else if matchKeyword("RIGHT") {
        try consumeKeyword("JOIN")
        joinType = .right
        isNatural = false
      } else if matchKeyword("FULL") {
        try consumeKeyword("JOIN")
        joinType = .full
        isNatural = false
      } else if matchKeyword("CROSS") {
        if matchKeyword("APPLY") {
          joinType = .crossApply
        } else {
          try consumeKeyword("JOIN")
          joinType = .cross
        }
        isNatural = false
      } else if matchKeyword("OUTER") {
        try consumeKeyword("APPLY")
        joinType = .outerApply
        isNatural = false
      } else if matchKeyword("NATURAL") {
        isNatural = true
        if matchKeyword("LEFT") {
          try consumeKeyword("JOIN")
          joinType = .left
        } else if matchKeyword("RIGHT") {
          try consumeKeyword("JOIN")
          joinType = .right
        } else if matchKeyword("FULL") {
          try consumeKeyword("JOIN")
          joinType = .full
        } else {
          try consumeKeyword("JOIN")
          joinType = .inner
        }
      } else if matchKeyword("JOIN") {
        joinType = .inner
        isNatural = false
      } else {
        break
      }

      let fromItem = try parseFromItem()
      let onExpression: (any Expression)?
      let usingColumns: [String]
      if joinType != .cross && joinType != .crossApply && joinType != .outerApply
        && matchKeyword("ON")
      {
        onExpression = try parseExpression()
        usingColumns = []
      } else if joinType != .crossApply && joinType != .outerApply && matchKeyword("USING") {
        try consumeSymbol("(")
        usingColumns = try parseIdentifierListUntilRightParen()
        onExpression = nil
      } else {
        onExpression = nil
        usingColumns = []
      }

      joins.append(
        Join(
          type: joinType, isNatural: isNatural, fromItem: fromItem, onExpression: onExpression,
          usingColumns: usingColumns))
    }

    return joins
  }

  private mutating func parseWhereClauseIfPresent() throws -> (any Expression)? {
    guard matchKeyword("WHERE") else {
      return nil
    }

    return try parseExpression()
  }

  private mutating func parseGroupByClauseIfPresent() throws -> [any Expression] {
    guard matchKeyword("GROUP") else {
      return []
    }

    try consumeKeyword("BY")

    var expressions: [any Expression] = []
    while true {
      expressions.append(try parseExpression())
      if match(symbol: ",") {
        continue
      }
      break
    }

    return expressions
  }

  private mutating func parseHavingClauseIfPresent() throws -> (any Expression)? {
    guard matchKeyword("HAVING") else {
      return nil
    }

    return try parseExpression()
  }

  private mutating func parseQualifyClauseIfPresent() throws -> (any Expression)? {
    guard matchKeyword("QUALIFY") else {
      return nil
    }

    return try parseExpression()
  }

  private mutating func parseOrderByClauseIfPresent() throws -> [OrderByElement] {
    guard matchKeyword("ORDER") else {
      return []
    }

    try consumeKeyword("BY")

    return try parseOrderByElements()
  }

  private mutating func parseOrderByElements() throws -> [OrderByElement] {

    var elements: [OrderByElement] = []
    while true {
      let expression = try parseExpression()
      let direction: OrderByElement.Direction?
      if matchKeyword("ASC") {
        direction = .ascending
      } else if matchKeyword("DESC") {
        direction = .descending
      } else {
        direction = nil
      }
      elements.append(OrderByElement(expression: expression, direction: direction))
      if match(symbol: ",") {
        continue
      }
      break
    }

    return elements
  }

  private mutating func parseExpressionList() throws -> [any Expression] {
    var expressions: [any Expression] = []
    while true {
      expressions.append(try parseExpression())
      if match(symbol: ",") {
        continue
      }
      break
    }
    return expressions
  }

  private mutating func parseLimitClauseIfPresent() throws -> Int? {
    guard matchKeyword("LIMIT") else {
      return nil
    }

    return try consumeIntegerLiteral()
  }

  private mutating func parseOffsetClauseIfPresent() throws -> Int? {
    guard matchKeyword("OFFSET") else {
      return nil
    }

    return try consumeIntegerLiteral()
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
      } else if matchKeyword("INCLUDES") {
        expression = try parseSoqlIncludesExcludesExpression(
          expression: expression,
          operator: .includes
        )
      } else if matchKeyword("EXCLUDES") {
        expression = try parseSoqlIncludesExcludesExpression(
          expression: expression,
          operator: .excludes
        )
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
      let nestedTokens = try collectBalancedParenthesisContent()
      var nested = SelectCoreParser(tokens: nestedTokens, options: options)
      let select = try nested.parseStatement()
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
      if checkKeyword("SELECT") || checkKeyword("WITH") || checkKeyword("VALUES") {
        let nestedTokens = try collectBalancedParenthesisContent()
        var nested = SelectCoreParser(tokens: nestedTokens, options: options)
        let select = try nested.parseStatement()
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
          let argument: any Expression
          if match(symbol: "*") {
            argument = IdentifierExpression(name: "*")
          } else {
            argument = try parseExpression()
          }
          args.append(argument)
          if match(symbol: ",") {
            continue
          }
          try consumeSymbol(")")
          break
        }
      }
      return FunctionExpression(
        name: identifier, arguments: args, overClause: try parseOverClauseIfPresent())
    }

    return IdentifierExpression(name: identifier)
  }

  private mutating func parseOverClauseIfPresent() throws -> WindowSpecification? {
    guard matchKeyword("OVER") else {
      return nil
    }

    if match(symbol: "(") == false {
      return WindowSpecification(namedWindow: try consumeIdentifier())
    }

    var partitionBy: [any Expression] = []
    var orderBy: [OrderByElement] = []

    if matchKeyword("PARTITION") {
      try consumeKeyword("BY")
      while true {
        partitionBy.append(try parseExpression())
        if match(symbol: ",") {
          continue
        }
        break
      }
    }

    if matchKeyword("ORDER") {
      try consumeKeyword("BY")
      orderBy = try parseOrderByElements()
    }

    try consumeSymbol(")")
    return WindowSpecification(partitionBy: partitionBy, orderBy: orderBy)
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

  private mutating func parseSoqlIncludesExcludesExpression(
    expression: any Expression,
    operator: SoqlIncludesExcludesExpression.Operator
  ) throws -> any Expression {
    guard options.dialectFeatures.contains(.salesforceSoql) else {
      throw SelectParseFailure.expected("INCLUDES/EXCLUDES requires Salesforce SOQL dialect")
    }
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
    return SoqlIncludesExcludesExpression(
      expression: expression, values: values, operator: `operator`)
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
    let format: String?
    if matchKeyword("FORMAT") {
      guard options.dialectFeatures.contains(.bigQuery) else {
        throw SelectParseFailure.expected("FORMAT in CAST requires BigQuery dialect")
      }
      guard let formatLiteral = consumeStringIfPresent() else {
        throw SelectParseFailure.expected("format string")
      }
      format = formatLiteral
    } else {
      format = nil
    }
    try consumeSymbol(")")
    return CastExpression(expression: expression, typeName: typeName, format: format)
  }

  private mutating func parseTypeName() throws -> String {
    var typeName = try consumeIdentifier()

    if match(symbol: "(") {
      var components: [String] = []
      while true {
        guard let token = advance() else {
          throw SelectParseFailure.expected("type modifier")
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

  private mutating func parseBigQuerySelectQualifierIfPresent() throws -> PlainSelect
    .SelectQualifier?
  {
    guard matchKeyword("AS") else {
      return nil
    }
    guard options.dialectFeatures.contains(.bigQuery) else {
      throw SelectParseFailure.expected("AS STRUCT/AS VALUE requires BigQuery dialect")
    }
    if matchKeyword("STRUCT") {
      return .asStruct
    }
    if matchKeyword("VALUE") {
      return .asValue
    }
    throw SelectParseFailure.expected("STRUCT or VALUE")
  }

  private mutating func parseTimeTravelClauseIfPresent() throws -> String? {
    if checkKeyword("FOR") {
      guard options.dialectFeatures.contains(.bigQuery) else {
        throw SelectParseFailure.expected("FOR SYSTEM_TIME AS OF requires BigQuery dialect")
      }
      try consumeKeyword("FOR")
      try consumeKeyword("SYSTEM_TIME")
      try consumeKeyword("AS")
      try consumeKeyword("OF")
      let clause = collectClauseTextUntilBoundary()
      guard clause.isEmpty == false else {
        throw SelectParseFailure.expected("system time expression")
      }
      return "FOR SYSTEM_TIME AS OF \(clause)"
    }

    if checkKeyword("AT") || checkKeyword("BEFORE") || checkKeyword("CHANGES") {
      guard options.dialectFeatures.contains(.snowflake) else {
        throw SelectParseFailure.expected("time travel clause requires Snowflake dialect")
      }
      let keyword = try consumeIdentifier().uppercased()
      let clause = collectClauseTextUntilBoundary()
      if clause.isEmpty {
        return keyword
      }
      return "\(keyword) \(clause)"
    }

    return nil
  }

  private mutating func collectClauseTextUntilBoundary() -> String {
    var collected: [Token] = []
    var nesting = 0

    while let token = peek() {
      if token.kind == .symbol {
        if token.text == "(" {
          nesting += 1
        } else if token.text == ")" {
          if nesting == 0 {
            break
          }
          nesting -= 1
        }
      }

      if nesting == 0, token.kind == .identifier,
        [
          "INNER", "LEFT", "RIGHT", "FULL", "CROSS", "JOIN", "ON", "USING", "APPLY", "WHERE",
          "GROUP", "HAVING", "QUALIFY", "ORDER", "LIMIT", "OFFSET", "UNION", "INTERSECT", "EXCEPT",
        ].contains(token.uppercased)
      {
        break
      }

      collected.append(token)
      _ = advance()
    }

    return SelectCoreParser.renderTokens(collected)
  }

  private static func renderTokens(_ tokens: [Token]) -> String {
    guard tokens.isEmpty == false else {
      return ""
    }

    var result = ""
    var previous: Token?

    for token in tokens {
      let text: String
      if token.kind == .string {
        let escaped = token.text.replacingOccurrences(of: "'", with: "''")
        text = "'\(escaped)'"
      } else {
        text = token.text
      }

      let needsSpace: Bool
      if result.isEmpty {
        needsSpace = false
      } else if token.kind == .symbol {
        needsSpace = token.text == "("
      } else if previous?.kind == .symbol {
        needsSpace = previous?.text != "(" && previous?.text != "."
      } else {
        needsSpace = true
      }

      if needsSpace {
        result.append(" ")
      }
      result.append(text)
      previous = token
    }

    return result
  }

  private mutating func ensureAtEnd() throws {
    guard peek() == nil else {
      throw SelectParseFailure.unexpectedToken(peek()?.text ?? "")
    }
  }

  private mutating func consumeKeyword(_ keyword: String) throws {
    guard matchKeyword(keyword) else {
      throw SelectParseFailure.expected(keyword)
    }
  }

  private mutating func consumeSymbol(_ symbol: String) throws {
    guard match(symbol: symbol) else {
      throw SelectParseFailure.expected(symbol)
    }
  }

  private mutating func consumeIdentifier() throws -> String {
    guard let first = peek(), first.kind == .identifier else {
      throw SelectParseFailure.expected("identifier")
    }
    _ = advance()

    var identifier = first.text
    while match(symbol: ".") {
      guard let next = peek(), next.kind == .identifier else {
        throw SelectParseFailure.expected("identifier after '.'")
      }
      _ = advance()
      identifier += ".\(next.text)"
    }

    return identifier
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

  private mutating func consumeNumberIfPresent() -> Double? {
    guard let token = peek(), token.kind == .number else {
      return nil
    }
    _ = advance()
    return Double(token.text)
  }

  private mutating func consumeIntegerLiteral() throws -> Int {
    guard let token = peek(), token.kind == .number, let value = Int(token.text) else {
      throw SelectParseFailure.expected("integer")
    }
    _ = advance()
    return value
  }

  private mutating func consumeNumberLiteralText() throws -> String {
    guard let token = peek(), token.kind == .number else {
      throw SelectParseFailure.expected("number")
    }
    _ = advance()
    return token.text
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

  private mutating func collectBalancedParenthesisContent() throws -> [Token] {
    var depth = 1
    var collected: [Token] = []

    while let token = advance() {
      if token.kind == .symbol, token.text == "(" {
        depth += 1
      } else if token.kind == .symbol, token.text == ")" {
        depth -= 1
        if depth == 0 {
          return collected
        }
      }

      collected.append(token)
    }

    throw SelectParseFailure.expected(")")
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

private enum SelectParseFailure: Error {
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
            || options.dialectFeatures.contains(.sqlServer)
            || options.dialectFeatures.contains(.sybase))
      {
        let (identifier, nextIndex) = try consumeBracketIdentifier(from: index)
        tokens.append(Token(text: identifier, kind: .identifier))
        index = nextIndex
        continue
      }

      if character == "`",
        options.experimentalFeatures.contains(.quotedIdentifiers)
          && (options.dialectFeatures.contains(.mysql)
            || options.dialectFeatures.contains(.mariaDB)
            || options.dialectFeatures.contains(.bigQuery)
            || options.dialectFeatures.contains(.snowflake)
            || options.dialectFeatures.contains(.sqlite))
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
        if ["<>", "!=", ">=", "<=", "||", "::", "|>"].contains(pair) {
          tokens.append(Token(text: pair, kind: .symbol))
          index = sql.index(after: nextIndex)
          continue
        }
      }

      if [",", "*", "(", ")", "=", "+", "-", "/", ".", "<", ">", ":"].contains(character) {
        tokens.append(Token(text: String(character), kind: .symbol))
        index = nextIndex
        continue
      }

      throw SelectParseFailure.unexpectedToken(String(character))
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
      throw SelectParseFailure.expected("oracle q quote opener")
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
          throw SelectParseFailure.expected("oracle q closing quote")
        }
        return (value, sql.index(after: quoteEnd))
      }
      value.append(sql[current])
      current = sql.index(after: current)
    }
    throw SelectParseFailure.expected("oracle q closing quote")
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

    throw SelectParseFailure.expected("closing quote")
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

    throw SelectParseFailure.expected("closing identifier quote")
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

    throw SelectParseFailure.expected("closing bracket identifier")
  }
}
