public protocol Statement: Sendable {}
public protocol Expression: Sendable {}
public protocol SelectItem: Sendable {}
public protocol FromItem: Sendable {}

public struct UnsupportedStatement: Statement, Sendable, Equatable {
  public let sql: String
  public let diagnostic: SqlDiagnostic

  public init(sql: String, diagnostic: SqlDiagnostic) {
    self.sql = sql
    self.diagnostic = diagnostic
  }
}

public struct RawExpression: Expression, Sendable, Equatable {
  public let sql: String

  public init(sql: String) {
    self.sql = sql
  }
}

public struct ReturningClause: Sendable, Equatable {
  public let items: [any SelectItem]

  public init(items: [any SelectItem]) {
    self.items = items
  }

  public static func == (lhs: ReturningClause, rhs: ReturningClause) -> Bool {
    lhs.items.count == rhs.items.count
  }
}

public struct OrderByElement: Sendable, Equatable {
  public enum Direction: String, Sendable {
    case ascending
    case descending
  }

  public let expression: any Expression
  public let direction: Direction?

  public init(expression: any Expression, direction: Direction? = nil) {
    self.expression = expression
    self.direction = direction
  }

  public static func == (lhs: OrderByElement, rhs: OrderByElement) -> Bool {
    lhs.direction == rhs.direction
  }
}

public struct PlainSelect: Statement, Sendable, Equatable {
  public enum SelectQualifier: Sendable, Equatable {
    case asStruct
    case asValue
  }

  public var distinctOnExpressions: [any Expression]
  public var top: Int?
  public var isDistinct: Bool
  public var selectQualifier: SelectQualifier?
  public var selectItems: [any SelectItem]
  public var from: any FromItem
  public var joins: [Join]
  public var whereExpression: (any Expression)?
  public var groupByExpressions: [any Expression]
  public var havingExpression: (any Expression)?
  public var qualifyExpression: (any Expression)?
  public var orderBy: [OrderByElement]
  public var limit: Int?
  public var offset: Int?

  public init(
    distinctOnExpressions: [any Expression] = [],
    top: Int? = nil,
    isDistinct: Bool = false,
    selectQualifier: SelectQualifier? = nil,
    selectItems: [any SelectItem],
    from: any FromItem,
    joins: [Join] = [],
    whereExpression: (any Expression)? = nil,
    groupByExpressions: [any Expression] = [],
    havingExpression: (any Expression)? = nil,
    qualifyExpression: (any Expression)? = nil,
    orderBy: [OrderByElement] = [],
    limit: Int? = nil,
    offset: Int? = nil
  ) {
    self.distinctOnExpressions = distinctOnExpressions
    self.top = top
    self.isDistinct = isDistinct
    self.selectQualifier = selectQualifier
    self.selectItems = selectItems
    self.from = from
    self.joins = joins
    self.whereExpression = whereExpression
    self.groupByExpressions = groupByExpressions
    self.havingExpression = havingExpression
    self.qualifyExpression = qualifyExpression
    self.orderBy = orderBy
    self.limit = limit
    self.offset = offset
  }

  public static func == (lhs: PlainSelect, rhs: PlainSelect) -> Bool {
    lhs.distinctOnExpressions.count == rhs.distinctOnExpressions.count
      && lhs.top == rhs.top
      && lhs.isDistinct == rhs.isDistinct
      && lhs.selectQualifier == rhs.selectQualifier
      && lhs.selectItems.count == rhs.selectItems.count
      && lhs.joins == rhs.joins
      && lhs.whereExpression == nil && rhs.whereExpression == nil
      && lhs.groupByExpressions.count == rhs.groupByExpressions.count
      && lhs.havingExpression == nil && rhs.havingExpression == nil
      && lhs.qualifyExpression == nil && rhs.qualifyExpression == nil
      && lhs.orderBy == rhs.orderBy
      && lhs.limit == rhs.limit
      && lhs.offset == rhs.offset
  }
}

public struct MergeClause: Sendable, Equatable {
  public let isMatched: Bool
  public let predicate: String?
  public let action: String

  public init(isMatched: Bool, predicate: String? = nil, action: String) {
    self.isMatched = isMatched
    self.predicate = predicate
    self.action = action
  }
}

public struct MergeStatement: Statement, Sendable, Equatable {
  public let targetTable: String
  public let targetAlias: String?
  public let source: any Statement
  public let sourceAlias: String?
  public let onCondition: any Expression
  public let clauses: [MergeClause]

  public init(
    targetTable: String,
    targetAlias: String? = nil,
    source: any Statement,
    sourceAlias: String? = nil,
    onCondition: any Expression,
    clauses: [MergeClause]
  ) {
    self.targetTable = targetTable
    self.targetAlias = targetAlias
    self.source = source
    self.sourceAlias = sourceAlias
    self.onCondition = onCondition
    self.clauses = clauses
  }

  public static func == (lhs: MergeStatement, rhs: MergeStatement) -> Bool {
    lhs.targetTable == rhs.targetTable
      && lhs.targetAlias == rhs.targetAlias
      && lhs.sourceAlias == rhs.sourceAlias
      && lhs.clauses == rhs.clauses
      && String(describing: type(of: lhs.source)) == String(describing: type(of: rhs.source))
  }
}

public struct ReplaceStatement: Statement, Sendable, Equatable {
  public let table: String
  public let columns: [String]
  public let source: InsertStatement.Source

  public init(table: String, columns: [String], source: InsertStatement.Source) {
    self.table = table
    self.columns = columns
    self.source = source
  }
}

public struct ValuesSelect: Statement, Sendable, Equatable {
  public let rows: [[any Expression]]

  public init(rows: [[any Expression]]) {
    self.rows = rows
  }

  public static func == (lhs: ValuesSelect, rhs: ValuesSelect) -> Bool {
    lhs.rows.count == rhs.rows.count
  }
}

public struct ExplainStatement: Statement, Sendable, Equatable {
  public let statement: any Statement

  public init(statement: any Statement) {
    self.statement = statement
  }

  public static func == (lhs: ExplainStatement, rhs: ExplainStatement) -> Bool {
    String(describing: type(of: lhs.statement)) == String(describing: type(of: rhs.statement))
  }
}

public struct ShowStatement: Statement, Sendable, Equatable {
  public let subject: String

  public init(subject: String) {
    self.subject = subject
  }
}

public struct SetStatement: Statement, Sendable, Equatable {
  public let name: String
  public let value: any Expression

  public init(name: String, value: any Expression) {
    self.name = name
    self.value = value
  }

  public static func == (lhs: SetStatement, rhs: SetStatement) -> Bool {
    lhs.name == rhs.name
  }
}

public struct ResetStatement: Statement, Sendable, Equatable {
  public let name: String

  public init(name: String) {
    self.name = name
  }
}

public struct UseStatement: Statement, Sendable, Equatable {
  public let target: String

  public init(target: String) {
    self.target = target
  }
}

public struct CommonTableExpression: Sendable, Equatable {
  public let name: String
  public let statement: any Statement

  public init(name: String, statement: any Statement) {
    self.name = name
    self.statement = statement
  }

  public static func == (lhs: CommonTableExpression, rhs: CommonTableExpression) -> Bool {
    lhs.name == rhs.name
      && String(describing: type(of: lhs.statement)) == String(describing: type(of: rhs.statement))
  }
}

public struct WithSelect: Statement, Sendable, Equatable {
  public let expressions: [CommonTableExpression]
  public let body: any Statement

  public init(expressions: [CommonTableExpression], body: any Statement) {
    self.expressions = expressions
    self.body = body
  }

  public static func == (lhs: WithSelect, rhs: WithSelect) -> Bool {
    lhs.expressions == rhs.expressions
      && String(describing: type(of: lhs.body)) == String(describing: type(of: rhs.body))
  }
}

public struct SetOperationSelect: Statement, Sendable, Equatable {
  public enum Operation: String, Sendable {
    case union
    case intersect
    case except
  }

  public let left: any Statement
  public let operation: Operation
  public let isAll: Bool
  public let modifier: String?
  public let right: any Statement

  public init(
    left: any Statement,
    operation: Operation,
    isAll: Bool = false,
    modifier: String? = nil,
    right: any Statement
  ) {
    self.left = left
    self.operation = operation
    self.isAll = isAll || modifier?.uppercased() == "ALL"
    self.modifier = modifier ?? (isAll ? "ALL" : nil)
    self.right = right
  }

  public static func == (lhs: SetOperationSelect, rhs: SetOperationSelect) -> Bool {
    lhs.operation == rhs.operation
      && lhs.isAll == rhs.isAll
      && lhs.modifier == rhs.modifier
      && String(describing: type(of: lhs.left)) == String(describing: type(of: rhs.left))
      && String(describing: type(of: lhs.right)) == String(describing: type(of: rhs.right))
  }
}

public struct PipeCallStatement: Statement, Sendable, Equatable {
  public let source: any Statement
  public let function: FunctionExpression
  public let alias: String?

  public init(source: any Statement, function: FunctionExpression, alias: String? = nil) {
    self.source = source
    self.function = function
    self.alias = alias
  }

  public static func == (lhs: PipeCallStatement, rhs: PipeCallStatement) -> Bool {
    lhs.alias == rhs.alias
      && lhs.function == rhs.function
      && String(describing: type(of: lhs.source)) == String(describing: type(of: rhs.source))
  }
}

public struct InsertStatement: Statement, Sendable, Equatable {
  public enum Source: Sendable, Equatable {
    case values([[any Expression]])
    case select(any Statement)
    case defaultValues
  }

  public let table: String
  public let columns: [String]
  public let source: Source
  public let onConflict: InsertOnConflictClause?
  public let onDuplicateKeyAssignments: [UpdateAssignment]
  public let returningClause: ReturningClause?

  public init(
    table: String,
    columns: [String],
    source: Source,
    onConflict: InsertOnConflictClause? = nil,
    onDuplicateKeyAssignments: [UpdateAssignment] = [],
    returningClause: ReturningClause? = nil
  ) {
    self.table = table
    self.columns = columns
    self.source = source
    self.onConflict = onConflict
    self.onDuplicateKeyAssignments = onDuplicateKeyAssignments
    self.returningClause = returningClause
  }

  public init(table: String, columns: [String], values: [[any Expression]]) {
    self.init(table: table, columns: columns, source: .values(values))
  }

  public static func == (lhs: InsertStatement, rhs: InsertStatement) -> Bool {
    lhs.table == rhs.table
      && lhs.columns == rhs.columns
      && lhs.source == rhs.source
      && lhs.onConflict == rhs.onConflict
      && lhs.onDuplicateKeyAssignments == rhs.onDuplicateKeyAssignments
      && lhs.returningClause == rhs.returningClause
  }
}

public struct UpsertStatement: Statement, Sendable, Equatable {
  public let table: String
  public let columns: [String]
  public let source: InsertStatement.Source
  public let onConflict: InsertOnConflictClause?
  public let onDuplicateKeyAssignments: [UpdateAssignment]
  public let returningClause: ReturningClause?

  public init(
    table: String,
    columns: [String],
    source: InsertStatement.Source,
    onConflict: InsertOnConflictClause? = nil,
    onDuplicateKeyAssignments: [UpdateAssignment] = [],
    returningClause: ReturningClause? = nil
  ) {
    self.table = table
    self.columns = columns
    self.source = source
    self.onConflict = onConflict
    self.onDuplicateKeyAssignments = onDuplicateKeyAssignments
    self.returningClause = returningClause
  }

  public static func == (lhs: UpsertStatement, rhs: UpsertStatement) -> Bool {
    lhs.table == rhs.table
      && lhs.columns == rhs.columns
      && lhs.source == rhs.source
      && lhs.onConflict == rhs.onConflict
      && lhs.onDuplicateKeyAssignments == rhs.onDuplicateKeyAssignments
      && lhs.returningClause == rhs.returningClause
  }
}

extension InsertStatement.Source {
  public static func == (lhs: InsertStatement.Source, rhs: InsertStatement.Source) -> Bool {
    switch (lhs, rhs) {
    case (.values(let lhsRows), .values(let rhsRows)):
      return lhsRows.count == rhsRows.count
    case (.select(let lhsStatement), .select(let rhsStatement)):
      return String(describing: type(of: lhsStatement))
        == String(describing: type(of: rhsStatement))
    case (.defaultValues, .defaultValues):
      return true
    default:
      return false
    }
  }
}

public struct InsertOnConflictClause: Sendable, Equatable {
  public enum Action: Sendable, Equatable {
    case doNothing
    case doUpdate(assignments: [UpdateAssignment], whereExpression: (any Expression)?)
  }

  public let targetColumns: [String]
  public let action: Action

  public init(targetColumns: [String], action: Action) {
    self.targetColumns = targetColumns
    self.action = action
  }
}

extension InsertOnConflictClause.Action {
  public static func == (lhs: InsertOnConflictClause.Action, rhs: InsertOnConflictClause.Action)
    -> Bool
  {
    switch (lhs, rhs) {
    case (.doNothing, .doNothing):
      return true
    case (.doUpdate(let lhsAssignments, let lhsWhere), .doUpdate(let rhsAssignments, let rhsWhere)):
      return lhsAssignments == rhsAssignments && (lhsWhere == nil) == (rhsWhere == nil)
    default:
      return false
    }
  }
}

public struct UpdateAssignment: Sendable, Equatable {
  public let column: String
  public let value: any Expression

  public init(column: String, value: any Expression) {
    self.column = column
    self.value = value
  }

  public static func == (lhs: UpdateAssignment, rhs: UpdateAssignment) -> Bool {
    lhs.column == rhs.column
  }
}

public struct UpdateStatement: Statement, Sendable, Equatable {
  public let table: String
  public let assignments: [UpdateAssignment]
  public let from: (any FromItem)?
  public let fromJoins: [Join]
  public let whereExpression: (any Expression)?
  public let returningClause: ReturningClause?

  public init(
    table: String,
    assignments: [UpdateAssignment],
    from: (any FromItem)? = nil,
    fromJoins: [Join] = [],
    whereExpression: (any Expression)? = nil,
    returningClause: ReturningClause? = nil
  ) {
    self.table = table
    self.assignments = assignments
    self.from = from
    self.fromJoins = fromJoins
    self.whereExpression = whereExpression
    self.returningClause = returningClause
  }

  public static func == (lhs: UpdateStatement, rhs: UpdateStatement) -> Bool {
    lhs.table == rhs.table
      && lhs.assignments == rhs.assignments
      && lhs.fromJoins == rhs.fromJoins
      && (lhs.from == nil) == (rhs.from == nil)
      && lhs.whereExpression == nil && rhs.whereExpression == nil
      && lhs.returningClause == rhs.returningClause
  }
}

public struct DeleteStatement: Statement, Sendable, Equatable {
  public let table: String
  public let usingItems: [any FromItem]
  public let whereExpression: (any Expression)?
  public let returningClause: ReturningClause?

  public init(
    table: String,
    usingItems: [any FromItem] = [],
    whereExpression: (any Expression)? = nil,
    returningClause: ReturningClause? = nil
  ) {
    self.table = table
    self.usingItems = usingItems
    self.whereExpression = whereExpression
    self.returningClause = returningClause
  }

  public static func == (lhs: DeleteStatement, rhs: DeleteStatement) -> Bool {
    lhs.table == rhs.table
      && lhs.usingItems.count == rhs.usingItems.count
      && lhs.whereExpression == nil && rhs.whereExpression == nil
      && lhs.returningClause == rhs.returningClause
  }
}

public struct TableColumnDefinition: Sendable, Equatable {
  public let name: String
  public let typeName: String
  public let defaultExpression: (any Expression)?
  public let constraints: [ColumnConstraint]

  public init(
    name: String,
    typeName: String,
    defaultExpression: (any Expression)? = nil,
    constraints: [ColumnConstraint] = []
  ) {
    self.name = name
    self.typeName = typeName
    self.defaultExpression = defaultExpression
    self.constraints = constraints
  }

  public static func == (lhs: TableColumnDefinition, rhs: TableColumnDefinition) -> Bool {
    lhs.name == rhs.name
      && lhs.typeName == rhs.typeName
      && (lhs.defaultExpression == nil) == (rhs.defaultExpression == nil)
      && lhs.constraints == rhs.constraints
  }
}

public enum ColumnConstraint: Sendable, Equatable {
  case notNull
  case primaryKey
  case unique
  case references(table: String, columns: [String])
  case check(any Expression)

  public static func == (lhs: ColumnConstraint, rhs: ColumnConstraint) -> Bool {
    switch (lhs, rhs) {
    case (.notNull, .notNull), (.primaryKey, .primaryKey), (.unique, .unique):
      return true
    case (.references(let lhsTable, let lhsColumns), .references(let rhsTable, let rhsColumns)):
      return lhsTable == rhsTable && lhsColumns == rhsColumns
    case (.check(let lhsExpression), .check(let rhsExpression)):
      return String(describing: type(of: lhsExpression))
        == String(describing: type(of: rhsExpression))
    default:
      return false
    }
  }
}

public struct TableConstraintDefinition: Sendable, Equatable {
  public let name: String?
  public let kind: TableConstraintKind

  public init(name: String? = nil, kind: TableConstraintKind) {
    self.name = name
    self.kind = kind
  }
}

public enum TableConstraintKind: Sendable, Equatable {
  case primaryKey(columns: [String])
  case foreignKey(columns: [String], referencesTable: String, referencesColumns: [String])
  case check(any Expression)

  public static func == (lhs: TableConstraintKind, rhs: TableConstraintKind) -> Bool {
    switch (lhs, rhs) {
    case (.primaryKey(let lhsColumns), .primaryKey(let rhsColumns)):
      return lhsColumns == rhsColumns
    case (
      .foreignKey(let lhsColumns, let lhsTable, let lhsRefColumns),
      .foreignKey(let rhsColumns, let rhsTable, let rhsRefColumns)
    ):
      return lhsColumns == rhsColumns && lhsTable == rhsTable && lhsRefColumns == rhsRefColumns
    case (.check(let lhsExpression), .check(let rhsExpression)):
      return String(describing: type(of: lhsExpression))
        == String(describing: type(of: rhsExpression))
    default:
      return false
    }
  }
}

public struct CreateTableStatement: Statement, Sendable, Equatable {
  public let table: String
  public let columns: [TableColumnDefinition]
  public let constraints: [TableConstraintDefinition]

  public init(
    table: String, columns: [TableColumnDefinition], constraints: [TableConstraintDefinition] = []
  ) {
    self.table = table
    self.columns = columns
    self.constraints = constraints
  }
}

public struct CreateIndexStatement: Statement, Sendable, Equatable {
  public let name: String
  public let table: String
  public let columns: [String]
  public let isUnique: Bool

  public init(name: String, table: String, columns: [String], isUnique: Bool = false) {
    self.name = name
    self.table = table
    self.columns = columns
    self.isUnique = isUnique
  }
}

public struct CreateViewStatement: Statement, Sendable, Equatable {
  public let name: String
  public let select: any Statement

  public init(name: String, select: any Statement) {
    self.name = name
    self.select = select
  }

  public static func == (lhs: CreateViewStatement, rhs: CreateViewStatement) -> Bool {
    lhs.name == rhs.name
      && String(describing: type(of: lhs.select)) == String(describing: type(of: rhs.select))
  }
}

public enum PolicyScope: String, Sendable, Equatable {
  case permissive
  case restrictive
}

public enum PolicyCommand: String, Sendable, Equatable {
  case all
  case select
  case insert
  case update
  case delete
}

public struct CreatePolicyStatement: Statement, Sendable, Equatable {
  public let name: String
  public let table: String
  public let scope: PolicyScope?
  public let command: PolicyCommand?
  public let roles: [String]
  public let usingExpression: (any Expression)?
  public let withCheckExpression: (any Expression)?

  public init(
    name: String,
    table: String,
    scope: PolicyScope? = nil,
    command: PolicyCommand? = nil,
    roles: [String] = [],
    usingExpression: (any Expression)? = nil,
    withCheckExpression: (any Expression)? = nil
  ) {
    self.name = name
    self.table = table
    self.scope = scope
    self.command = command
    self.roles = roles
    self.usingExpression = usingExpression
    self.withCheckExpression = withCheckExpression
  }

  public static func == (lhs: CreatePolicyStatement, rhs: CreatePolicyStatement) -> Bool {
    lhs.name == rhs.name
      && lhs.table == rhs.table
      && lhs.scope == rhs.scope
      && lhs.command == rhs.command
      && lhs.roles == rhs.roles
      && ((lhs.usingExpression == nil && rhs.usingExpression == nil)
        || (lhs.usingExpression != nil && rhs.usingExpression != nil))
      && ((lhs.withCheckExpression == nil && rhs.withCheckExpression == nil)
        || (lhs.withCheckExpression != nil && rhs.withCheckExpression != nil))
  }
}

public enum RowLevelSecurityMode: String, Sendable, Equatable {
  case enable
  case disable
  case force
  case noForce
}

public enum AlterTableOperation: Sendable, Equatable {
  case addColumn(TableColumnDefinition)
  case dropColumn(String)
  case renameColumn(oldName: String, newName: String)
  case renameTable(String)
  case addConstraint(TableConstraintDefinition)
  case dropConstraint(String)
  case rowLevelSecurity(RowLevelSecurityMode)
}

public struct AlterTableStatement: Statement, Sendable, Equatable {
  public let table: String
  public let operation: AlterTableOperation

  public init(table: String, operation: AlterTableOperation) {
    self.table = table
    self.operation = operation
  }
}

public struct DropTableStatement: Statement, Sendable, Equatable {
  public let table: String

  public init(table: String) {
    self.table = table
  }
}

public struct TruncateTableStatement: Statement, Sendable, Equatable {
  public let table: String

  public init(table: String) {
    self.table = table
  }
}

public struct Join: Sendable, Equatable {
  public enum JoinType: String, Sendable {
    case inner
    case left
    case right
    case full
    case cross
    case crossApply
    case outerApply
  }

  public let type: JoinType
  public let isNatural: Bool
  public let fromItem: any FromItem
  public let onExpression: (any Expression)?
  public let usingColumns: [String]

  public init(
    type: JoinType,
    isNatural: Bool = false,
    fromItem: any FromItem,
    onExpression: (any Expression)? = nil,
    usingColumns: [String] = []
  ) {
    self.type = type
    self.isNatural = isNatural
    self.fromItem = fromItem
    self.onExpression = onExpression
    self.usingColumns = usingColumns
  }

  public static func == (lhs: Join, rhs: Join) -> Bool {
    lhs.type == rhs.type
      && lhs.isNatural == rhs.isNatural
      && lhs.onExpression == nil && rhs.onExpression == nil
      && lhs.usingColumns == rhs.usingColumns
  }
}

public struct PivotValue: Sendable, Equatable {
  public let expression: any Expression
  public let alias: String?

  public init(expression: any Expression, alias: String? = nil) {
    self.expression = expression
    self.alias = alias
  }

  public static func == (lhs: PivotValue, rhs: PivotValue) -> Bool {
    lhs.alias == rhs.alias
  }
}

public struct PivotFromItem: FromItem, Sendable, Equatable {
  public let source: any FromItem
  public let aggregateFunction: FunctionExpression
  public let pivotColumn: String
  public let values: [PivotValue]
  public let alias: String?

  public init(
    source: any FromItem, aggregateFunction: FunctionExpression, pivotColumn: String,
    values: [PivotValue], alias: String? = nil
  ) {
    self.source = source
    self.aggregateFunction = aggregateFunction
    self.pivotColumn = pivotColumn
    self.values = values
    self.alias = alias
  }

  public static func == (lhs: PivotFromItem, rhs: PivotFromItem) -> Bool {
    lhs.pivotColumn == rhs.pivotColumn
      && lhs.values == rhs.values
      && lhs.alias == rhs.alias
  }
}

public struct UnpivotFromItem: FromItem, Sendable, Equatable {
  public let source: any FromItem
  public let valueColumn: String
  public let nameColumn: String
  public let columns: [String]
  public let alias: String?

  public init(
    source: any FromItem, valueColumn: String, nameColumn: String, columns: [String],
    alias: String? = nil
  ) {
    self.source = source
    self.valueColumn = valueColumn
    self.nameColumn = nameColumn
    self.columns = columns
    self.alias = alias
  }

  public static func == (lhs: UnpivotFromItem, rhs: UnpivotFromItem) -> Bool {
    lhs.valueColumn == rhs.valueColumn
      && lhs.nameColumn == rhs.nameColumn
      && lhs.columns == rhs.columns
      && lhs.alias == rhs.alias
  }
}

public struct IdentifierExpression: Expression, Sendable, Equatable {
  public let name: String

  public init(name: String) {
    self.name = name
  }
}

public struct StringLiteralExpression: Expression, Sendable, Equatable {
  public let value: String

  public init(value: String) {
    self.value = value
  }
}

public struct NullLiteralExpression: Expression, Sendable, Equatable {
  public init() {}
}

public struct NumberLiteralExpression: Expression, Sendable, Equatable {
  public let value: Double

  public init(value: Double) {
    self.value = value
  }
}

public struct UnaryExpression: Expression, Sendable, Equatable {
  public enum UnaryOperator: String, Sendable {
    case plus
    case minus
    case not
  }

  public let `operator`: UnaryOperator
  public let expression: any Expression

  public init(operator: UnaryOperator, expression: any Expression) {
    self.operator = `operator`
    self.expression = expression
  }

  public static func == (lhs: UnaryExpression, rhs: UnaryExpression) -> Bool {
    lhs.operator == rhs.operator
  }
}

public struct BinaryExpression: Expression, Sendable, Equatable {
  public enum BinaryOperator: String, Sendable {
    case equals
    case notEquals
    case lessThan
    case lessThanOrEquals
    case greaterThan
    case greaterThanOrEquals
    case like
    case ilike
    case and
    case or
    case plus
    case minus
    case multiply
    case divide
  }

  public let left: any Expression
  public let `operator`: BinaryOperator
  public let right: any Expression

  public init(left: any Expression, operator: BinaryOperator, right: any Expression) {
    self.left = left
    self.operator = `operator`
    self.right = right
  }

  public static func == (lhs: BinaryExpression, rhs: BinaryExpression) -> Bool {
    lhs.operator == rhs.operator
  }
}

public struct IsNullExpression: Expression, Sendable, Equatable {
  public let expression: any Expression
  public let isNegated: Bool

  public init(expression: any Expression, isNegated: Bool = false) {
    self.expression = expression
    self.isNegated = isNegated
  }

  public static func == (lhs: IsNullExpression, rhs: IsNullExpression) -> Bool {
    lhs.isNegated == rhs.isNegated
  }
}

public struct InListExpression: Expression, Sendable, Equatable {
  public let expression: any Expression
  public let values: [any Expression]
  public let isNegated: Bool

  public init(expression: any Expression, values: [any Expression], isNegated: Bool = false) {
    self.expression = expression
    self.values = values
    self.isNegated = isNegated
  }

  public static func == (lhs: InListExpression, rhs: InListExpression) -> Bool {
    lhs.values.count == rhs.values.count && lhs.isNegated == rhs.isNegated
  }
}

public struct SoqlIncludesExcludesExpression: Expression, Sendable, Equatable {
  public enum Operator: String, Sendable, Equatable {
    case includes
    case excludes
  }

  public let expression: any Expression
  public let values: [any Expression]
  public let `operator`: Operator

  public init(expression: any Expression, values: [any Expression], operator: Operator) {
    self.expression = expression
    self.values = values
    self.operator = `operator`
  }

  public static func == (lhs: SoqlIncludesExcludesExpression, rhs: SoqlIncludesExcludesExpression)
    -> Bool
  {
    lhs.operator == rhs.operator && lhs.values.count == rhs.values.count
  }
}

public struct BetweenExpression: Expression, Sendable, Equatable {
  public let expression: any Expression
  public let lowerBound: any Expression
  public let upperBound: any Expression
  public let isNegated: Bool

  public init(
    expression: any Expression, lowerBound: any Expression, upperBound: any Expression,
    isNegated: Bool = false
  ) {
    self.expression = expression
    self.lowerBound = lowerBound
    self.upperBound = upperBound
    self.isNegated = isNegated
  }

  public static func == (lhs: BetweenExpression, rhs: BetweenExpression) -> Bool {
    lhs.isNegated == rhs.isNegated
  }
}

public struct ExistsExpression: Expression, Sendable, Equatable {
  public let statement: any Statement

  public init(statement: any Statement) {
    self.statement = statement
  }

  public static func == (lhs: ExistsExpression, rhs: ExistsExpression) -> Bool {
    String(describing: type(of: lhs.statement)) == String(describing: type(of: rhs.statement))
  }
}

public struct CaseWhenClause: Sendable, Equatable {
  public let condition: any Expression
  public let result: any Expression

  public init(condition: any Expression, result: any Expression) {
    self.condition = condition
    self.result = result
  }

  public static func == (lhs: CaseWhenClause, rhs: CaseWhenClause) -> Bool {
    String(describing: type(of: lhs.condition)) == String(describing: type(of: rhs.condition))
      && String(describing: type(of: lhs.result)) == String(describing: type(of: rhs.result))
  }
}

public struct CaseExpression: Expression, Sendable, Equatable {
  public let baseExpression: (any Expression)?
  public let whenClauses: [CaseWhenClause]
  public let elseExpression: (any Expression)?

  public init(
    baseExpression: (any Expression)? = nil, whenClauses: [CaseWhenClause],
    elseExpression: (any Expression)? = nil
  ) {
    self.baseExpression = baseExpression
    self.whenClauses = whenClauses
    self.elseExpression = elseExpression
  }

  public static func == (lhs: CaseExpression, rhs: CaseExpression) -> Bool {
    (lhs.baseExpression == nil) == (rhs.baseExpression == nil)
      && lhs.whenClauses == rhs.whenClauses
      && (lhs.elseExpression == nil) == (rhs.elseExpression == nil)
  }
}

public struct CastExpression: Expression, Sendable, Equatable {
  public enum Style: Sendable, Equatable {
    case standard
    case postgres
  }

  public let expression: any Expression
  public let typeName: String
  public let style: Style
  public let format: String?

  public init(
    expression: any Expression,
    typeName: String,
    style: Style = .standard,
    format: String? = nil
  ) {
    self.expression = expression
    self.typeName = typeName
    self.style = style
    self.format = format
  }

  public static func == (lhs: CastExpression, rhs: CastExpression) -> Bool {
    lhs.typeName == rhs.typeName && lhs.style == rhs.style && lhs.format == rhs.format
  }
}

public struct PlaceholderExpression: Expression, Sendable, Equatable {
  public let token: String

  public init(token: String) {
    self.token = token
  }
}

public struct WindowSpecification: Sendable, Equatable {
  public let namedWindow: String?
  public let partitionBy: [any Expression]
  public let orderBy: [OrderByElement]

  public init(
    namedWindow: String? = nil, partitionBy: [any Expression] = [], orderBy: [OrderByElement] = []
  ) {
    self.namedWindow = namedWindow
    self.partitionBy = partitionBy
    self.orderBy = orderBy
  }

  public static func == (lhs: WindowSpecification, rhs: WindowSpecification) -> Bool {
    lhs.namedWindow == rhs.namedWindow
      && lhs.partitionBy.count == rhs.partitionBy.count
      && lhs.orderBy == rhs.orderBy
  }
}

public struct FunctionExpression: Expression, Sendable, Equatable {
  public let name: String
  public let arguments: [any Expression]
  public let overClause: WindowSpecification?

  public init(name: String, arguments: [any Expression], overClause: WindowSpecification? = nil) {
    self.name = name
    self.arguments = arguments
    self.overClause = overClause
  }

  public static func == (lhs: FunctionExpression, rhs: FunctionExpression) -> Bool {
    lhs.name == rhs.name
      && lhs.arguments.count == rhs.arguments.count
      && lhs.overClause == rhs.overClause
  }
}

public struct SubqueryExpression: Expression, Sendable, Equatable {
  public let statement: any Statement

  public init(statement: any Statement) {
    self.statement = statement
  }

  public static func == (lhs: SubqueryExpression, rhs: SubqueryExpression) -> Bool {
    let lhsStatementType = String(describing: type(of: lhs.statement))
    let rhsStatementType = String(describing: type(of: rhs.statement))
    return lhsStatementType == rhsStatementType
  }
}

public struct AllColumnsSelectItem: SelectItem, Sendable, Equatable {
  public struct Replacement: Sendable, Equatable {
    public let expression: any Expression
    public let alias: String

    public init(expression: any Expression, alias: String) {
      self.expression = expression
      self.alias = alias
    }

    public static func == (lhs: Replacement, rhs: Replacement) -> Bool {
      lhs.alias == rhs.alias
        && String(describing: type(of: lhs.expression))
          == String(describing: type(of: rhs.expression))
    }
  }

  public let exceptColumns: [String]
  public let replacements: [Replacement]

  public init(exceptColumns: [String] = [], replacements: [Replacement] = []) {
    self.exceptColumns = exceptColumns
    self.replacements = replacements
  }
}

public struct ExpressionSelectItem: SelectItem, Sendable, Equatable {
  public let expression: any Expression
  public let alias: String?

  public init(expression: any Expression, alias: String? = nil) {
    self.expression = expression
    self.alias = alias
  }

  public static func == (lhs: ExpressionSelectItem, rhs: ExpressionSelectItem) -> Bool {
    lhs.alias == rhs.alias
  }
}

public struct TableSampleFromItem: FromItem, Sendable, Equatable {
  public let source: any FromItem
  public let method: String
  public let size: String
  public let unit: String

  public init(source: any FromItem, method: String, size: String, unit: String) {
    self.source = source
    self.method = method
    self.size = size
    self.unit = unit
  }

  public static func == (lhs: TableSampleFromItem, rhs: TableSampleFromItem) -> Bool {
    lhs.method == rhs.method
      && lhs.size == rhs.size
      && lhs.unit == rhs.unit
      && String(describing: type(of: lhs.source)) == String(describing: type(of: rhs.source))
  }
}

public struct TableFromItem: FromItem, Sendable, Equatable {
  public let name: String
  public let timeTravelClause: String?
  public let alias: String?
  public let timeTravelClauseAfterAlias: String?
  public let isLateral: Bool

  public init(
    name: String,
    timeTravelClause: String? = nil,
    alias: String? = nil,
    timeTravelClauseAfterAlias: String? = nil,
    isLateral: Bool = false
  ) {
    self.name = name
    self.timeTravelClause = timeTravelClause
    self.alias = alias
    self.timeTravelClauseAfterAlias = timeTravelClauseAfterAlias
    self.isLateral = isLateral
  }
}

public struct SubqueryFromItem: FromItem, Sendable, Equatable {
  public let statement: any Statement
  public let alias: String?
  public let isLateral: Bool

  public init(statement: any Statement, alias: String? = nil, isLateral: Bool = false) {
    self.statement = statement
    self.alias = alias
    self.isLateral = isLateral
  }

  public static func == (lhs: SubqueryFromItem, rhs: SubqueryFromItem) -> Bool {
    lhs.alias == rhs.alias
      && lhs.isLateral == rhs.isLateral
      && String(describing: type(of: lhs.statement)) == String(describing: type(of: rhs.statement))
  }
}
