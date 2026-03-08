public enum IdentifierQuotingBehavior: Sendable, Equatable {
    case ansiDoubleQuotes
    case squareBrackets
}

public enum EscapeBehavior: Sendable, Equatable {
    case backslash
    case standardConformingStrings
}

public enum DialectFeature: String, Sendable, Hashable {
    case postgres
    case mysql
    case sqlServer
    case oracle
    case bigQuery
    case snowflake
}

public struct ParserOptions: Sendable, Equatable {
    public var identifierQuoting: IdentifierQuotingBehavior
    public var escapeBehavior: EscapeBehavior
    public var scriptSeparators: [String]
    public var dialectFeatures: Set<DialectFeature>

    public init(
        identifierQuoting: IdentifierQuotingBehavior = .ansiDoubleQuotes,
        escapeBehavior: EscapeBehavior = .backslash,
        scriptSeparators: [String] = [";"],
        dialectFeatures: Set<DialectFeature> = []
    ) {
        self.identifierQuoting = identifierQuoting
        self.escapeBehavior = escapeBehavior
        self.scriptSeparators = scriptSeparators
        self.dialectFeatures = dialectFeatures
    }
}
