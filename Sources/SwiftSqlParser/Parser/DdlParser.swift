import Foundation

struct DdlParser {
    private let tokens: [Token]
    private let options: ParserOptions
    private var index: Int = 0

    init(sql: String, options: ParserOptions) throws {
        self.options = options
        self.tokens = try Tokenizer(sql: sql, options: options).tokenize()
    }

    mutating func parseStatement() throws -> any Statement {
        if matchKeyword("CREATE") {
            return try parseCreate()
        }

        if matchKeyword("ALTER") {
            return try parseAlter()
        }

        if matchKeyword("DROP") {
            return try parseDrop()
        }

        if matchKeyword("TRUNCATE") {
            return try parseTruncate()
        }

        throw DdlParseFailure.expected("DDL statement")
    }

    private mutating func parseCreate() throws -> CreateTableStatement {
        try consumeKeyword("TABLE")
        let table = try consumeIdentifier()
        try consumeSymbol("(")

        var columns: [TableColumnDefinition] = []
        while true {
            let columnName = try consumeIdentifier()
            let typeName = try consumeIdentifier()
            columns.append(TableColumnDefinition(name: columnName, typeName: typeName))

            if match(symbol: ",") {
                continue
            }

            break
        }

        try consumeSymbol(")")
        try ensureAtEnd()
        return CreateTableStatement(table: table, columns: columns)
    }

    private mutating func parseAlter() throws -> AlterTableStatement {
        try consumeKeyword("TABLE")
        let table = try consumeIdentifier()

        if matchKeyword("ADD") {
            _ = matchKeyword("COLUMN")
            let columnName = try consumeIdentifier()
            let typeName = try consumeIdentifier()
            try ensureAtEnd()
            return AlterTableStatement(
                table: table,
                operation: .addColumn(TableColumnDefinition(name: columnName, typeName: typeName))
            )
        }

        if matchKeyword("DROP") {
            _ = matchKeyword("COLUMN")
            let columnName = try consumeIdentifier()
            try ensureAtEnd()
            return AlterTableStatement(table: table, operation: .dropColumn(columnName))
        }

        throw DdlParseFailure.expected("ALTER TABLE operation")
    }

    private mutating func parseDrop() throws -> DropTableStatement {
        try consumeKeyword("TABLE")
        let table = try consumeIdentifier()
        try ensureAtEnd()
        return DropTableStatement(table: table)
    }

    private mutating func parseTruncate() throws -> TruncateTableStatement {
        _ = matchKeyword("TABLE")
        let table = try consumeIdentifier()
        try ensureAtEnd()
        return TruncateTableStatement(table: table)
    }

    private mutating func ensureAtEnd() throws {
        guard peek() == nil else {
            throw DdlParseFailure.unexpectedToken(peek()?.text ?? "")
        }
    }

    private mutating func consumeKeyword(_ keyword: String) throws {
        guard matchKeyword(keyword) else {
            throw DdlParseFailure.expected(keyword)
        }
    }

    private mutating func consumeSymbol(_ symbol: String) throws {
        guard match(symbol: symbol) else {
            throw DdlParseFailure.expected(symbol)
        }
    }

    private mutating func consumeIdentifier() throws -> String {
        guard let first = peek(), first.kind == .identifier else {
            throw DdlParseFailure.expected("identifier")
        }
        _ = advance()

        var identifier = first.text
        while match(symbol: ".") {
            guard let next = peek(), next.kind == .identifier else {
                throw DdlParseFailure.expected("identifier after '.'")
            }
            _ = advance()
            identifier += ".\(next.text)"
        }

        return identifier
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

private enum DdlParseFailure: Error {
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
                let (_, nextIndex) = try consumeString(from: index)
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
                let (_, nextIndex) = consumeNumber(from: index)
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
            if [",", "(", ")", "."].contains(character) {
                tokens.append(Token(text: String(character), kind: .symbol))
                index = nextIndex
                continue
            }

            throw DdlParseFailure.unexpectedToken(String(character))
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
        while current < sql.endIndex, sql[current].isNumber {
            current = sql.index(after: current)
        }
        return (String(sql[start..<current]), current)
    }

    private func consumeString(from start: String.Index) throws -> (String, String.Index) {
        var current = sql.index(after: start)
        while current < sql.endIndex {
            let character = sql[current]
            if character == "'" {
                let next = sql.index(after: current)
                if next < sql.endIndex, sql[next] == "'" {
                    current = sql.index(after: next)
                    continue
                }
                return ("", next)
            }
            current = sql.index(after: current)
        }

        throw DdlParseFailure.expected("closing quote")
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

        throw DdlParseFailure.expected("closing identifier quote")
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

        throw DdlParseFailure.expected("closing bracket identifier")
    }
}
