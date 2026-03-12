public struct TableNameFinder {
  public init() {}

  public func find(in statement: any Statement) -> [String] {
    var collector = Collector()
    collector.visit(statement: statement)
    return Array(collector.names).sorted()
  }

  public func find(in expression: any Expression) -> [String] {
    var collector = Collector()
    collector.visit(expression: expression)
    return Array(collector.names).sorted()
  }
}

private struct Collector {
  var names: Set<String> = []
  var cteNames: Set<String> = []
  var aliases: Set<String> = []

  mutating func visit(statement: any Statement) {
    switch statement {
    case let raw as RawStatement:
      _ = raw
    case let unsupported as UnsupportedStatement:
      _ = unsupported
    case let explain as ExplainStatement:
      visit(statement: explain.statement)
    case let select as PlainSelect:
      visit(select: select)
    case let values as ValuesSelect:
      _ = values
    case let withSelect as WithSelect:
      let previousCtes = cteNames
      let previousAliases = aliases
      for expression in withSelect.expressions {
        cteNames.insert(expression.name)
        visit(statement: expression.statement)
      }
      visit(statement: withSelect.body)
      cteNames = previousCtes
      aliases = previousAliases
    case let setOperation as SetOperationSelect:
      visit(statement: setOperation.left)
      visit(statement: setOperation.right)
    case let merge as MergeStatement:
      names.insert(merge.targetTable)
      visit(statement: merge.source)
      visit(expression: merge.onCondition)
    case let replace as ReplaceStatement:
      names.insert(replace.table)
      visit(insertSource: replace.source)
    case let insert as InsertStatement:
      names.insert(insert.table)
      visit(insertSource: insert.source)
      visit(returning: insert.returningClause)
    case let upsert as UpsertStatement:
      names.insert(upsert.table)
      visit(insertSource: upsert.source)
      visit(returning: upsert.returningClause)
    case let update as UpdateStatement:
      names.insert(update.table)
      update.assignments.forEach { visit(expression: $0.value) }
      if let from = update.from {
        visit(fromItem: from)
      }
      update.fromJoins.forEach { visit(join: $0) }
      if let whereExpression = update.whereExpression {
        visit(expression: whereExpression)
      }
      visit(returning: update.returningClause)
    case let delete as DeleteStatement:
      names.insert(delete.table)
      delete.usingItems.forEach { visit(fromItem: $0) }
      if let whereExpression = delete.whereExpression {
        visit(expression: whereExpression)
      }
      visit(returning: delete.returningClause)
    case let create as CreateTableStatement:
      names.insert(create.table)
      create.columns.forEach { column in
        if let defaultExpression = column.defaultExpression {
          visit(expression: defaultExpression)
        }
        column.constraints.forEach { visit(columnConstraint: $0) }
      }
      create.constraints.forEach { visit(tableConstraint: $0) }
    case let createIndex as CreateIndexStatement:
      names.insert(createIndex.table)
    case let createView as CreateViewStatement:
      names.insert(createView.name)
      visit(statement: createView.select)
    case let createPolicy as CreatePolicyStatement:
      names.insert(createPolicy.table)
      if let usingExpression = createPolicy.usingExpression {
        visit(expression: usingExpression)
      }
      if let withCheckExpression = createPolicy.withCheckExpression {
        visit(expression: withCheckExpression)
      }
    case let alter as AlterTableStatement:
      names.insert(alter.table)
      visit(alterOperation: alter.operation)
    case let drop as DropTableStatement:
      names.insert(drop.table)
    case let truncate as TruncateTableStatement:
      names.insert(truncate.table)
    case let show as ShowStatement:
      _ = show
    case let set as SetStatement:
      visit(expression: set.value)
    case let reset as ResetStatement:
      _ = reset
    case let use as UseStatement:
      _ = use
    default:
      break
    }
  }

  mutating func visit(select: PlainSelect) {
    visit(fromItem: select.from)
    select.joins.forEach { visit(join: $0) }
    select.selectItems.forEach { visit(selectItem: $0) }
    if let whereExpression = select.whereExpression { visit(expression: whereExpression) }
    select.groupByExpressions.forEach { visit(expression: $0) }
    if let havingExpression = select.havingExpression { visit(expression: havingExpression) }
    if let qualifyExpression = select.qualifyExpression { visit(expression: qualifyExpression) }
    select.orderBy.forEach { visit(expression: $0.expression) }
  }

  mutating func visit(join: Join) {
    visit(fromItem: join.fromItem)
    if let onExpression = join.onExpression {
      visit(expression: onExpression)
    }
  }

  mutating func visit(fromItem: any FromItem) {
    switch fromItem {
    case let tableSample as TableSampleFromItem:
      visit(fromItem: tableSample.source)
    case let table as TableFromItem:
      if let alias = table.alias {
        aliases.insert(alias)
      }
      if cteNames.contains(table.name) == false {
        names.insert(table.name)
      }
    case let subquery as SubqueryFromItem:
      if let alias = subquery.alias {
        aliases.insert(alias)
      }
      visit(statement: subquery.statement)
    case let pivot as PivotFromItem:
      visit(fromItem: pivot.source)
      visit(expression: pivot.aggregateFunction)
      pivot.values.forEach { visit(expression: $0.expression) }
    case let unpivot as UnpivotFromItem:
      visit(fromItem: unpivot.source)
    default:
      break
    }
  }

  mutating func visit(selectItem: any SelectItem) {
    if let expressionItem = selectItem as? ExpressionSelectItem {
      visit(expression: expressionItem.expression)
    }
  }

  mutating func visit(returning clause: ReturningClause?) {
    guard let clause else { return }
    clause.items.forEach { visit(selectItem: $0) }
  }

  mutating func visit(insertSource: InsertStatement.Source) {
    switch insertSource {
    case .values(let rows):
      rows.flatMap { $0 }.forEach { visit(expression: $0) }
    case .select(let statement):
      visit(statement: statement)
    case .defaultValues:
      break
    }
  }

  mutating func visit(alterOperation: AlterTableOperation) {
    switch alterOperation {
    case .addColumn(let column):
      if let defaultExpression = column.defaultExpression {
        visit(expression: defaultExpression)
      }
      column.constraints.forEach { visit(columnConstraint: $0) }
    case .addConstraint(let constraint):
      visit(tableConstraint: constraint)
    case .dropColumn, .renameColumn, .renameTable, .dropConstraint, .rowLevelSecurity(_):
      break
    }
  }

  mutating func visit(columnConstraint: ColumnConstraint) {
    switch columnConstraint {
    case .references(let table, _):
      names.insert(table)
    case .check(let expression):
      visit(expression: expression)
    case .notNull, .primaryKey, .unique:
      break
    }
  }

  mutating func visit(tableConstraint: TableConstraintDefinition) {
    switch tableConstraint.kind {
    case .foreignKey(_, let referencesTable, _):
      names.insert(referencesTable)
    case .check(let expression):
      visit(expression: expression)
    case .primaryKey:
      break
    }
  }

  mutating func visit(expression: any Expression) {
    switch expression {
    case let identifier as IdentifierExpression:
      if let qualifier = identifier.name.split(separator: ".").first, identifier.name.contains(".")
      {
        let qualifierName = String(qualifier)
        if aliases.contains(qualifierName) == false, cteNames.contains(qualifierName) == false {
          names.insert(qualifierName)
        }
      }
    case let raw as RawExpression:
      _ = raw
    case let unary as UnaryExpression:
      visit(expression: unary.expression)
    case let binary as BinaryExpression:
      visit(expression: binary.left)
      visit(expression: binary.right)
    case let isNull as IsNullExpression:
      visit(expression: isNull.expression)
    case let inList as InListExpression:
      visit(expression: inList.expression)
      inList.values.forEach { visit(expression: $0) }
    case let includesExcludes as SoqlIncludesExcludesExpression:
      visit(expression: includesExcludes.expression)
      includesExcludes.values.forEach { visit(expression: $0) }
    case let between as BetweenExpression:
      visit(expression: between.expression)
      visit(expression: between.lowerBound)
      visit(expression: between.upperBound)
    case let exists as ExistsExpression:
      visit(statement: exists.statement)
    case let function as FunctionExpression:
      function.arguments.forEach { visit(expression: $0) }
      function.overClause?.partitionBy.forEach { visit(expression: $0) }
      function.overClause?.orderBy.forEach { visit(expression: $0.expression) }
    case let caseExpression as CaseExpression:
      if let baseExpression = caseExpression.baseExpression {
        visit(expression: baseExpression)
      }
      caseExpression.whenClauses.forEach {
        visit(expression: $0.condition)
        visit(expression: $0.result)
      }
      if let elseExpression = caseExpression.elseExpression {
        visit(expression: elseExpression)
      }
    case let cast as CastExpression:
      visit(expression: cast.expression)
    case let subquery as SubqueryExpression:
      visit(statement: subquery.statement)
    default:
      break
    }
  }
}
