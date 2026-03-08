public protocol Statement: Sendable {}
public protocol Expression: Sendable {}
public protocol SelectItem: Sendable {}
public protocol FromItem: Sendable {}

public struct PlainSelect: Statement, Sendable, Equatable {
    public var selectItems: [any SelectItem]
    public var from: any FromItem
    public var joins: [Join]
    public var whereExpression: (any Expression)?

    public init(
        selectItems: [any SelectItem],
        from: any FromItem,
        joins: [Join] = [],
        whereExpression: (any Expression)? = nil
    ) {
        self.selectItems = selectItems
        self.from = from
        self.joins = joins
        self.whereExpression = whereExpression
    }

    public static func == (lhs: PlainSelect, rhs: PlainSelect) -> Bool {
        lhs.selectItems.count == rhs.selectItems.count
            && lhs.joins == rhs.joins
            && lhs.whereExpression == nil && rhs.whereExpression == nil
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
    public let right: any Statement

    public init(left: any Statement, operation: Operation, isAll: Bool = false, right: any Statement) {
        self.left = left
        self.operation = operation
        self.isAll = isAll
        self.right = right
    }

    public static func == (lhs: SetOperationSelect, rhs: SetOperationSelect) -> Bool {
        lhs.operation == rhs.operation
            && lhs.isAll == rhs.isAll
            && String(describing: type(of: lhs.left)) == String(describing: type(of: rhs.left))
            && String(describing: type(of: lhs.right)) == String(describing: type(of: rhs.right))
    }
}

public struct InsertStatement: Statement, Sendable, Equatable {
    public let table: String
    public let columns: [String]
    public let values: [[any Expression]]

    public init(table: String, columns: [String], values: [[any Expression]]) {
        self.table = table
        self.columns = columns
        self.values = values
    }

    public static func == (lhs: InsertStatement, rhs: InsertStatement) -> Bool {
        lhs.table == rhs.table
            && lhs.columns == rhs.columns
            && lhs.values.count == rhs.values.count
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
    public let whereExpression: (any Expression)?

    public init(table: String, assignments: [UpdateAssignment], whereExpression: (any Expression)? = nil) {
        self.table = table
        self.assignments = assignments
        self.whereExpression = whereExpression
    }

    public static func == (lhs: UpdateStatement, rhs: UpdateStatement) -> Bool {
        lhs.table == rhs.table
            && lhs.assignments == rhs.assignments
            && lhs.whereExpression == nil && rhs.whereExpression == nil
    }
}

public struct DeleteStatement: Statement, Sendable, Equatable {
    public let table: String
    public let whereExpression: (any Expression)?

    public init(table: String, whereExpression: (any Expression)? = nil) {
        self.table = table
        self.whereExpression = whereExpression
    }

    public static func == (lhs: DeleteStatement, rhs: DeleteStatement) -> Bool {
        lhs.table == rhs.table
            && lhs.whereExpression == nil && rhs.whereExpression == nil
    }
}

public struct Join: Sendable, Equatable {
    public enum JoinType: String, Sendable {
        case inner
        case left
        case right
        case full
        case cross
    }

    public let type: JoinType
    public let fromItem: any FromItem
    public let onExpression: (any Expression)?

    public init(type: JoinType, fromItem: any FromItem, onExpression: (any Expression)? = nil) {
        self.type = type
        self.fromItem = fromItem
        self.onExpression = onExpression
    }

    public static func == (lhs: Join, rhs: Join) -> Bool {
        lhs.type == rhs.type
            && lhs.onExpression == nil && rhs.onExpression == nil
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

public struct FunctionExpression: Expression, Sendable, Equatable {
    public let name: String
    public let arguments: [any Expression]

    public init(name: String, arguments: [any Expression]) {
        self.name = name
        self.arguments = arguments
    }

    public static func == (lhs: FunctionExpression, rhs: FunctionExpression) -> Bool {
        lhs.name == rhs.name
            && lhs.arguments.count == rhs.arguments.count
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
    public init() {}
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

public struct TableFromItem: FromItem, Sendable, Equatable {
    public let name: String
    public let alias: String?

    public init(name: String, alias: String? = nil) {
        self.name = name
        self.alias = alias
    }
}

public struct SubqueryFromItem: FromItem, Sendable, Equatable {
    public let statement: any Statement
    public let alias: String?

    public init(statement: any Statement, alias: String? = nil) {
        self.statement = statement
        self.alias = alias
    }

    public static func == (lhs: SubqueryFromItem, rhs: SubqueryFromItem) -> Bool {
        lhs.alias == rhs.alias
            && String(describing: type(of: lhs.statement)) == String(describing: type(of: rhs.statement))
    }
}
