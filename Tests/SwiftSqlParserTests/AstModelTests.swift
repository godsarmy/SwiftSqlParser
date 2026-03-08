import Testing
@testable import SwiftSqlParser

@Test
func plainSelectAstHoldsCoreParts() {
    let select = PlainSelect(
        selectItems: [AllColumnsSelectItem()],
        from: TableFromItem(name: "users"),
        whereExpression: BinaryExpression(
            left: IdentifierExpression(name: "id"),
            operator: .equals,
            right: NumberLiteralExpression(value: 42)
        )
    )

    #expect(select.selectItems.count == 1)
    #expect(select.joins.isEmpty)
}
