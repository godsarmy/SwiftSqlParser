import Foundation

struct DmlParser {
    private let tokens: [Token]
    private var index: Int = 0

    init(sql: String) throws {
        self.tokens = try Tokenizer(sql: sql).tokenize()
    }

    mutating func parseStatement() throws -> any Statement {
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

    private mutating func parseInsert() throws -> InsertStatement {
        try consumeKeyword("INTO")
        let table = try consumeIdentifier()

        var columns: [String] = []
        if match(symbol: "(") {
            columns = try parseIdentifierListUntilRightParen()
        }

        try consumeKeyword("VALUES")
        var rows: [[any Expression]] = []

        repeat {
            try consumeSymbol("(")
            let values = try parseExpressionListUntilRightParen()
            rows.append(values)
        } while match(symbol: ",")

        try ensureAtEnd()
        return InsertStatement(table: table, columns: columns, values: rows)
    }

    private mutating func parseUpdate() throws -> UpdateStatement {
        let table = try consumeIdentifier()
        try consumeKeyword("SET")

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

        let whereExpression: (any Expression)?
        if matchKeyword("WHERE") {
            whereExpression = try parseExpression()
        } else {
            whereExpression = nil
        }

        try ensureAtEnd()
        return UpdateStatement(table: table, assignments: assignments, whereExpression: whereExpression)
    }

    private mutating func parseDelete() throws -> DeleteStatement {
        try consumeKeyword("FROM")
        let table = try consumeIdentifier()

        let whereExpression: (any Expression)?
        if matchKeyword("WHERE") {
            whereExpression = try parseExpression()
        } else {
            whereExpression = nil
        }

        try ensureAtEnd()
        return DeleteStatement(table: table, whereExpression: whereExpression)
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
        var expression = try parseEqualityExpression()
        while matchKeyword("AND") {
            let rhs = try parseEqualityExpression()
            expression = BinaryExpression(left: expression, operator: .and, right: rhs)
        }
        return expression
    }

    private mutating func parseEqualityExpression() throws -> any Expression {
        var expression = try parseAdditiveExpression()

        while true {
            if match(symbol: "=") {
                let rhs = try parseAdditiveExpression()
                expression = BinaryExpression(left: expression, operator: .equals, right: rhs)
            } else if match(symbol: "<>") || match(symbol: "!=") {
                let rhs = try parseAdditiveExpression()
                expression = BinaryExpression(left: expression, operator: .notEquals, right: rhs)
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

        return try parsePrimaryExpression()
    }

    private mutating func parsePrimaryExpression() throws -> any Expression {
        if match(symbol: "(") {
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
        case symbol
    }

    let text: String
    let kind: Kind

    var uppercased: String { text.uppercased() }
}

private struct Tokenizer {
    private let sql: String

    init(sql: String) {
        self.sql = sql
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
                if ["<>", "!=", ">=", "<=", "||"].contains(pair) {
                    tokens.append(Token(text: pair, kind: .symbol))
                    index = sql.index(after: nextIndex)
                    continue
                }
            }

            if [",", "*", "(", ")", "=", "+", "-", "/", "."].contains(character) {
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
}
