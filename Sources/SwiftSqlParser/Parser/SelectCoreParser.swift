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
            statement = SetOperationSelect(left: statement, operation: operation, isAll: isAll, right: rhs)
        }

        return statement
    }

    private mutating func parsePrimarySelectStatement() throws -> any Statement {
        if match(symbol: "(") {
            let nestedTokens = try collectBalancedParenthesisContent()
            var nested = SelectCoreParser(tokens: nestedTokens, options: options)
            return try nested.parseStatement()
        }

        return try parsePlainSelect()
    }

    private mutating func parsePlainSelect() throws -> PlainSelect {
        try consumeKeyword("SELECT")
        let selectItems = try parseSelectItems()
        try consumeKeyword("FROM")
        let from = try parseFromItem()
        let joins = try parseJoins()
        let whereExpression = try parseWhereClauseIfPresent()

        return PlainSelect(
            selectItems: selectItems,
            from: from,
            joins: joins,
            whereExpression: whereExpression
        )
    }

    private mutating func parseSelectItems() throws -> [any SelectItem] {
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

        if items.isEmpty {
            throw SelectParseFailure.expected("select item")
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

        let keywordBoundary = [
            "FROM", "WHERE", "INNER", "LEFT", "RIGHT", "FULL", "CROSS", "JOIN", "ON",
            "UNION", "INTERSECT", "EXCEPT", "ALL"
        ]
        if keywordBoundary.contains(next.uppercased) {
            return nil
        }

        _ = advance()
        return next.text
    }

    private mutating func parseFromItem() throws -> any FromItem {
        if match(symbol: "(") {
            let nestedTokens = try collectBalancedParenthesisContent()
            var nested = SelectCoreParser(tokens: nestedTokens, options: options)
            let nestedStatement = try nested.parseStatement()
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

    private mutating func parseWhereClauseIfPresent() throws -> (any Expression)? {
        guard matchKeyword("WHERE") else {
            return nil
        }

        return try parseExpression()
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
            } else if options.dialectFeatures.contains(.postgres), matchKeyword("ILIKE") {
                let rhs = try parseAdditiveExpression()
                expression = BinaryExpression(left: expression, operator: .ilike, right: rhs)
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
            if checkKeyword("SELECT") || checkKeyword("WITH") {
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

        let identifier = try consumeIdentifier()
        if match(symbol: "(") {
            var args: [any Expression] = []
            if match(symbol: ")") == false {
                while true {
                    let argument = try parseExpression()
                    args.append(argument)
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

            if character == "\"" {
                let (identifier, nextIndex) = try consumeQuotedIdentifier(from: index, quote: "\"")
                tokens.append(Token(text: identifier, kind: .identifier))
                index = nextIndex
                continue
            }

            if character == "[", options.identifierQuoting == .squareBrackets || options.dialectFeatures.contains(.sqlServer) {
                let (identifier, nextIndex) = try consumeBracketIdentifier(from: index)
                tokens.append(Token(text: identifier, kind: .identifier))
                index = nextIndex
                continue
            }

            if character == "`", options.dialectFeatures.contains(.mysql) || options.dialectFeatures.contains(.bigQuery) || options.dialectFeatures.contains(.snowflake) {
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

    private func consumeQuotedIdentifier(from start: String.Index, quote: Character) throws -> (String, String.Index) {
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
