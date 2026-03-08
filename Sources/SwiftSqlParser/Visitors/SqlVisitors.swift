public protocol StatementVisitor {
    mutating func visit(rawStatement: RawStatement)
    mutating func visit(plainSelect: PlainSelect)
    mutating func visit(withSelect: WithSelect)
    mutating func visit(setOperationSelect: SetOperationSelect)
    mutating func visit(insertStatement: InsertStatement)
    mutating func visit(updateStatement: UpdateStatement)
    mutating func visit(deleteStatement: DeleteStatement)
    mutating func visit(createTableStatement: CreateTableStatement)
    mutating func visit(alterTableStatement: AlterTableStatement)
    mutating func visit(dropTableStatement: DropTableStatement)
    mutating func visit(truncateTableStatement: TruncateTableStatement)
}

public extension StatementVisitor {
    mutating func visit(rawStatement: RawStatement) {}
    mutating func visit(plainSelect: PlainSelect) {}
    mutating func visit(withSelect: WithSelect) {}
    mutating func visit(setOperationSelect: SetOperationSelect) {}
    mutating func visit(insertStatement: InsertStatement) {}
    mutating func visit(updateStatement: UpdateStatement) {}
    mutating func visit(deleteStatement: DeleteStatement) {}
    mutating func visit(createTableStatement: CreateTableStatement) {}
    mutating func visit(alterTableStatement: AlterTableStatement) {}
    mutating func visit(dropTableStatement: DropTableStatement) {}
    mutating func visit(truncateTableStatement: TruncateTableStatement) {}
}

public protocol ExpressionVisitor {
    mutating func visit(identifierExpression: IdentifierExpression)
    mutating func visit(stringLiteralExpression: StringLiteralExpression)
    mutating func visit(numberLiteralExpression: NumberLiteralExpression)
    mutating func visit(unaryExpression: UnaryExpression)
    mutating func visit(binaryExpression: BinaryExpression)
    mutating func visit(functionExpression: FunctionExpression)
    mutating func visit(subqueryExpression: SubqueryExpression)
}

public extension ExpressionVisitor {
    mutating func visit(identifierExpression: IdentifierExpression) {}
    mutating func visit(stringLiteralExpression: StringLiteralExpression) {}
    mutating func visit(numberLiteralExpression: NumberLiteralExpression) {}
    mutating func visit(unaryExpression: UnaryExpression) {}
    mutating func visit(binaryExpression: BinaryExpression) {}
    mutating func visit(functionExpression: FunctionExpression) {}
    mutating func visit(subqueryExpression: SubqueryExpression) {}
}

public protocol FromItemVisitor {
    mutating func visit(tableFromItem: TableFromItem)
    mutating func visit(subqueryFromItem: SubqueryFromItem)
}

public extension FromItemVisitor {
    mutating func visit(tableFromItem: TableFromItem) {}
    mutating func visit(subqueryFromItem: SubqueryFromItem) {}
}

public protocol SelectItemVisitor {
    mutating func visit(allColumnsSelectItem: AllColumnsSelectItem)
    mutating func visit(expressionSelectItem: ExpressionSelectItem)
}

public extension SelectItemVisitor {
    mutating func visit(allColumnsSelectItem: AllColumnsSelectItem) {}
    mutating func visit(expressionSelectItem: ExpressionSelectItem) {}
}

public enum AstVisit {
    public static func statement<V: StatementVisitor>(_ statement: any Statement, visitor: inout V) {
        if let raw = statement as? RawStatement {
            visitor.visit(rawStatement: raw)
            return
        }

        if let select = statement as? PlainSelect {
            visitor.visit(plainSelect: select)
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

        if let insert = statement as? InsertStatement {
            visitor.visit(insertStatement: insert)
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

    public static func expression<V: ExpressionVisitor>(_ expression: any Expression, visitor: inout V) {
        if let identifier = expression as? IdentifierExpression {
            visitor.visit(identifierExpression: identifier)
            return
        }

        if let stringLiteral = expression as? StringLiteralExpression {
            visitor.visit(stringLiteralExpression: stringLiteral)
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

        if let function = expression as? FunctionExpression {
            visitor.visit(functionExpression: function)
            return
        }

        if let subquery = expression as? SubqueryExpression {
            visitor.visit(subqueryExpression: subquery)
        }
    }

    public static func fromItem<V: FromItemVisitor>(_ fromItem: any FromItem, visitor: inout V) {
        if let table = fromItem as? TableFromItem {
            visitor.visit(tableFromItem: table)
            return
        }

        if let subquery = fromItem as? SubqueryFromItem {
            visitor.visit(subqueryFromItem: subquery)
        }
    }

    public static func selectItem<V: SelectItemVisitor>(_ selectItem: any SelectItem, visitor: inout V) {
        if let allColumns = selectItem as? AllColumnsSelectItem {
            visitor.visit(allColumnsSelectItem: allColumns)
            return
        }

        if let expression = selectItem as? ExpressionSelectItem {
            visitor.visit(expressionSelectItem: expression)
        }
    }
}
