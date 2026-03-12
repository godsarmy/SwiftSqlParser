public protocol StatementVisitor {
  mutating func visit(rawStatement: RawStatement)
  mutating func visit(unsupportedStatement: UnsupportedStatement)
  mutating func visit(plainSelect: PlainSelect)
  mutating func visit(valuesSelect: ValuesSelect)
  mutating func visit(withSelect: WithSelect)
  mutating func visit(setOperationSelect: SetOperationSelect)
  mutating func visit(explainStatement: ExplainStatement)
  mutating func visit(showStatement: ShowStatement)
  mutating func visit(setStatement: SetStatement)
  mutating func visit(resetStatement: ResetStatement)
  mutating func visit(useStatement: UseStatement)
  mutating func visit(mergeStatement: MergeStatement)
  mutating func visit(replaceStatement: ReplaceStatement)
  mutating func visit(insertStatement: InsertStatement)
  mutating func visit(upsertStatement: UpsertStatement)
  mutating func visit(updateStatement: UpdateStatement)
  mutating func visit(deleteStatement: DeleteStatement)
  mutating func visit(createTableStatement: CreateTableStatement)
  mutating func visit(createIndexStatement: CreateIndexStatement)
  mutating func visit(createViewStatement: CreateViewStatement)
  mutating func visit(createPolicyStatement: CreatePolicyStatement)
  mutating func visit(alterTableStatement: AlterTableStatement)
  mutating func visit(dropTableStatement: DropTableStatement)
  mutating func visit(truncateTableStatement: TruncateTableStatement)
}

extension StatementVisitor {
  public mutating func visit(rawStatement: RawStatement) {}
  public mutating func visit(unsupportedStatement: UnsupportedStatement) {}
  public mutating func visit(plainSelect: PlainSelect) {}
  public mutating func visit(valuesSelect: ValuesSelect) {}
  public mutating func visit(withSelect: WithSelect) {}
  public mutating func visit(setOperationSelect: SetOperationSelect) {}
  public mutating func visit(explainStatement: ExplainStatement) {}
  public mutating func visit(showStatement: ShowStatement) {}
  public mutating func visit(setStatement: SetStatement) {}
  public mutating func visit(resetStatement: ResetStatement) {}
  public mutating func visit(useStatement: UseStatement) {}
  public mutating func visit(mergeStatement: MergeStatement) {}
  public mutating func visit(replaceStatement: ReplaceStatement) {}
  public mutating func visit(insertStatement: InsertStatement) {}
  public mutating func visit(upsertStatement: UpsertStatement) {}
  public mutating func visit(updateStatement: UpdateStatement) {}
  public mutating func visit(deleteStatement: DeleteStatement) {}
  public mutating func visit(createTableStatement: CreateTableStatement) {}
  public mutating func visit(createIndexStatement: CreateIndexStatement) {}
  public mutating func visit(createViewStatement: CreateViewStatement) {}
  public mutating func visit(createPolicyStatement: CreatePolicyStatement) {}
  public mutating func visit(alterTableStatement: AlterTableStatement) {}
  public mutating func visit(dropTableStatement: DropTableStatement) {}
  public mutating func visit(truncateTableStatement: TruncateTableStatement) {}
}

public protocol ExpressionVisitor {
  mutating func visit(rawExpression: RawExpression)
  mutating func visit(identifierExpression: IdentifierExpression)
  mutating func visit(stringLiteralExpression: StringLiteralExpression)
  mutating func visit(nullLiteralExpression: NullLiteralExpression)
  mutating func visit(numberLiteralExpression: NumberLiteralExpression)
  mutating func visit(unaryExpression: UnaryExpression)
  mutating func visit(binaryExpression: BinaryExpression)
  mutating func visit(isNullExpression: IsNullExpression)
  mutating func visit(inListExpression: InListExpression)
  mutating func visit(soqlIncludesExcludesExpression: SoqlIncludesExcludesExpression)
  mutating func visit(betweenExpression: BetweenExpression)
  mutating func visit(existsExpression: ExistsExpression)
  mutating func visit(functionExpression: FunctionExpression)
  mutating func visit(caseExpression: CaseExpression)
  mutating func visit(castExpression: CastExpression)
  mutating func visit(placeholderExpression: PlaceholderExpression)
  mutating func visit(subqueryExpression: SubqueryExpression)
}

extension ExpressionVisitor {
  public mutating func visit(rawExpression: RawExpression) {}
  public mutating func visit(identifierExpression: IdentifierExpression) {}
  public mutating func visit(stringLiteralExpression: StringLiteralExpression) {}
  public mutating func visit(nullLiteralExpression: NullLiteralExpression) {}
  public mutating func visit(numberLiteralExpression: NumberLiteralExpression) {}
  public mutating func visit(unaryExpression: UnaryExpression) {}
  public mutating func visit(binaryExpression: BinaryExpression) {}
  public mutating func visit(isNullExpression: IsNullExpression) {}
  public mutating func visit(inListExpression: InListExpression) {}
  public mutating func visit(soqlIncludesExcludesExpression: SoqlIncludesExcludesExpression) {}
  public mutating func visit(betweenExpression: BetweenExpression) {}
  public mutating func visit(existsExpression: ExistsExpression) {}
  public mutating func visit(functionExpression: FunctionExpression) {}
  public mutating func visit(caseExpression: CaseExpression) {}
  public mutating func visit(castExpression: CastExpression) {}
  public mutating func visit(placeholderExpression: PlaceholderExpression) {}
  public mutating func visit(subqueryExpression: SubqueryExpression) {}
}

public protocol FromItemVisitor {
  mutating func visit(tableSampleFromItem: TableSampleFromItem)
  mutating func visit(tableFromItem: TableFromItem)
  mutating func visit(subqueryFromItem: SubqueryFromItem)
  mutating func visit(pivotFromItem: PivotFromItem)
  mutating func visit(unpivotFromItem: UnpivotFromItem)
}

extension FromItemVisitor {
  public mutating func visit(tableSampleFromItem: TableSampleFromItem) {}
  public mutating func visit(tableFromItem: TableFromItem) {}
  public mutating func visit(subqueryFromItem: SubqueryFromItem) {}
  public mutating func visit(pivotFromItem: PivotFromItem) {}
  public mutating func visit(unpivotFromItem: UnpivotFromItem) {}
}

public protocol SelectItemVisitor {
  mutating func visit(allColumnsSelectItem: AllColumnsSelectItem)
  mutating func visit(expressionSelectItem: ExpressionSelectItem)
}

extension SelectItemVisitor {
  public mutating func visit(allColumnsSelectItem: AllColumnsSelectItem) {}
  public mutating func visit(expressionSelectItem: ExpressionSelectItem) {}
}

public enum AstVisit {
  public static func statement<V: StatementVisitor>(_ statement: any Statement, visitor: inout V) {
    if let raw = statement as? RawStatement {
      visitor.visit(rawStatement: raw)
      return
    }

    if let unsupported = statement as? UnsupportedStatement {
      visitor.visit(unsupportedStatement: unsupported)
      return
    }

    if let explain = statement as? ExplainStatement {
      visitor.visit(explainStatement: explain)
      return
    }

    if let show = statement as? ShowStatement {
      visitor.visit(showStatement: show)
      return
    }

    if let set = statement as? SetStatement {
      visitor.visit(setStatement: set)
      return
    }

    if let reset = statement as? ResetStatement {
      visitor.visit(resetStatement: reset)
      return
    }

    if let use = statement as? UseStatement {
      visitor.visit(useStatement: use)
      return
    }

    if let select = statement as? PlainSelect {
      visitor.visit(plainSelect: select)
      return
    }

    if let values = statement as? ValuesSelect {
      visitor.visit(valuesSelect: values)
      return
    }

    if let withSelect = statement as? WithSelect {
      visitor.visit(withSelect: withSelect)
      return
    }

    if let setOperation = statement as? SetOperationSelect {
      visitor.visit(setOperationSelect: setOperation)
      return
    }

    if let merge = statement as? MergeStatement {
      visitor.visit(mergeStatement: merge)
      return
    }

    if let replace = statement as? ReplaceStatement {
      visitor.visit(replaceStatement: replace)
      return
    }

    if let insert = statement as? InsertStatement {
      visitor.visit(insertStatement: insert)
      return
    }

    if let upsert = statement as? UpsertStatement {
      visitor.visit(upsertStatement: upsert)
      return
    }

    if let update = statement as? UpdateStatement {
      visitor.visit(updateStatement: update)
      return
    }

    if let delete = statement as? DeleteStatement {
      visitor.visit(deleteStatement: delete)
      return
    }

    if let create = statement as? CreateTableStatement {
      visitor.visit(createTableStatement: create)
      return
    }

    if let createIndex = statement as? CreateIndexStatement {
      visitor.visit(createIndexStatement: createIndex)
      return
    }

    if let createView = statement as? CreateViewStatement {
      visitor.visit(createViewStatement: createView)
      return
    }

    if let createPolicy = statement as? CreatePolicyStatement {
      visitor.visit(createPolicyStatement: createPolicy)
      return
    }

    if let alter = statement as? AlterTableStatement {
      visitor.visit(alterTableStatement: alter)
      return
    }

    if let drop = statement as? DropTableStatement {
      visitor.visit(dropTableStatement: drop)
      return
    }

    if let truncate = statement as? TruncateTableStatement {
      visitor.visit(truncateTableStatement: truncate)
    }
  }

  public static func expression<V: ExpressionVisitor>(
    _ expression: any Expression, visitor: inout V
  ) {
    if let raw = expression as? RawExpression {
      visitor.visit(rawExpression: raw)
      return
    }

    if let identifier = expression as? IdentifierExpression {
      visitor.visit(identifierExpression: identifier)
      return
    }

    if let stringLiteral = expression as? StringLiteralExpression {
      visitor.visit(stringLiteralExpression: stringLiteral)
      return
    }

    if let nullLiteral = expression as? NullLiteralExpression {
      visitor.visit(nullLiteralExpression: nullLiteral)
      return
    }

    if let numberLiteral = expression as? NumberLiteralExpression {
      visitor.visit(numberLiteralExpression: numberLiteral)
      return
    }

    if let unary = expression as? UnaryExpression {
      visitor.visit(unaryExpression: unary)
      return
    }

    if let binary = expression as? BinaryExpression {
      visitor.visit(binaryExpression: binary)
      return
    }

    if let isNull = expression as? IsNullExpression {
      visitor.visit(isNullExpression: isNull)
      return
    }

    if let inList = expression as? InListExpression {
      visitor.visit(inListExpression: inList)
      return
    }

    if let includesExcludes = expression as? SoqlIncludesExcludesExpression {
      visitor.visit(soqlIncludesExcludesExpression: includesExcludes)
      return
    }

    if let between = expression as? BetweenExpression {
      visitor.visit(betweenExpression: between)
      return
    }

    if let exists = expression as? ExistsExpression {
      visitor.visit(existsExpression: exists)
      return
    }

    if let function = expression as? FunctionExpression {
      visitor.visit(functionExpression: function)
      return
    }

    if let caseExpression = expression as? CaseExpression {
      visitor.visit(caseExpression: caseExpression)
      return
    }

    if let cast = expression as? CastExpression {
      visitor.visit(castExpression: cast)
      return
    }

    if let placeholder = expression as? PlaceholderExpression {
      visitor.visit(placeholderExpression: placeholder)
      return
    }

    if let subquery = expression as? SubqueryExpression {
      visitor.visit(subqueryExpression: subquery)
    }
  }

  public static func fromItem<V: FromItemVisitor>(_ fromItem: any FromItem, visitor: inout V) {
    if let tableSample = fromItem as? TableSampleFromItem {
      visitor.visit(tableSampleFromItem: tableSample)
      return
    }

    if let table = fromItem as? TableFromItem {
      visitor.visit(tableFromItem: table)
      return
    }

    if let subquery = fromItem as? SubqueryFromItem {
      visitor.visit(subqueryFromItem: subquery)
      return
    }

    if let pivot = fromItem as? PivotFromItem {
      visitor.visit(pivotFromItem: pivot)
      return
    }

    if let unpivot = fromItem as? UnpivotFromItem {
      visitor.visit(unpivotFromItem: unpivot)
    }
  }

  public static func selectItem<V: SelectItemVisitor>(
    _ selectItem: any SelectItem, visitor: inout V
  ) {
    if let allColumns = selectItem as? AllColumnsSelectItem {
      visitor.visit(allColumnsSelectItem: allColumns)
      return
    }

    if let expression = selectItem as? ExpressionSelectItem {
      visitor.visit(expressionSelectItem: expression)
    }
  }
}
