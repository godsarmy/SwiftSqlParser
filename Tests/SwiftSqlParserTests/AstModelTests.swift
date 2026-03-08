import Testing
@testable import SwiftSqlParser

@Test
func plainSelectAstHoldsCoreParts() {
    let select = PlainSelect(
        isDistinct: true,
        selectItems: [AllColumnsSelectItem()],
        from: TableFromItem(name: "users"),
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "id"),
            operator: .equals,
            right: NumberLiteralExpression(value: 42)
        ),
        groupByExpressions: [IdentifierExpression(name: "id")],
        orderBy: [OrderByElement(expression: IdentifierExpression(name: "id"), direction: .ascending)],
        limit: 5,
        offset: 10
    )

    #expect(select.isDistinct)
    #expect(select.selectItems.count == 1)
    #expect(select.joins.isEmpty)
    #expect(select.groupByExpressions.count == 1)
    #expect(select.orderBy.count == 1)
    #expect(select.limit == 5)
    #expect(select.offset == 10)
}
