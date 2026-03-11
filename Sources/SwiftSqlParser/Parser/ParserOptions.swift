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
  case duckDB
  case redshift
  case db2
  case h2
  case hsqldb
  case derby
  case sqlite
}

public enum ExperimentalFeature: String, Sendable, Hashable {
  case postgresIlike
  case quotedIdentifiers
  case postgresDistinctOn
  case sqlServerTop
  case oracleAlternativeQuoting
  case mergeStatements
  case replaceStatements
  case pivotSyntax
}

public struct ParserOptions: Sendable, Equatable {
  public var identifierQuoting: IdentifierQuotingBehavior
  public var escapeBehavior: EscapeBehavior
  public var scriptSeparators: [String]
  public var recoverParseErrors: Bool
  public var recoverUnsupportedStatements: Bool
  public var dialectFeatures: Set<DialectFeature>
  public var experimentalFeatures: Set<ExperimentalFeature>

  public init(
    identifierQuoting: IdentifierQuotingBehavior = .ansiDoubleQuotes,
    escapeBehavior: EscapeBehavior = .backslash,
    scriptSeparators: [String] = [";", "GO", "/", "\n\n\n"],
    recoverParseErrors: Bool = false,
    recoverUnsupportedStatements: Bool = false,
    dialectFeatures: Set<DialectFeature> = [],
    experimentalFeatures: Set<ExperimentalFeature> = []
  ) {
    self.identifierQuoting = identifierQuoting
    self.escapeBehavior = escapeBehavior
    self.scriptSeparators = scriptSeparators
    self.recoverParseErrors = recoverParseErrors
    self.recoverUnsupportedStatements = recoverUnsupportedStatements
    self.dialectFeatures = dialectFeatures
    self.experimentalFeatures = experimentalFeatures
  }
}
