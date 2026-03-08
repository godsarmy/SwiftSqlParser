public enum GrammarBackend: Sendable {
    case antlr4
}

public enum GrammarPhase: String, CaseIterable, Sendable {
    case selectCore = "select-core"
    case withAndSubqueries = "with-and-subqueries"
    case dml = "dml"
    case ddl = "ddl"
    case dialectExtensions = "dialect-extensions"
}

public struct GrammarStrategy: Sendable, Equatable {
    public let backend: GrammarBackend
    public let phases: [GrammarPhase]

    public init(
        backend: GrammarBackend = .antlr4,
        phases: [GrammarPhase] = [.selectCore, .withAndSubqueries, .dml, .ddl, .dialectExtensions]
    ) {
        self.backend = backend
        self.phases = phases
    }
}
