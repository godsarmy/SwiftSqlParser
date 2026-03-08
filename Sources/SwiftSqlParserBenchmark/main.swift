import Foundation
import SwiftSqlParser

private struct BenchmarkResult {
    let name: String
    let milliseconds: Double
}

@main
struct SwiftSqlParserBenchmarkMain {
    static func main() {
        let corpus = makeCorpus(statementCount: 12_000)
        let options = ParserOptions(
            dialectFeatures: [.postgres, .mysql, .sqlServer],
            experimentalFeatures: [.postgresIlike, .quotedIdentifiers]
        )

        let results: [BenchmarkResult] = [
            measure(name: "parseStatement loop") {
                for statement in corpus.statements {
                    _ = try parseStatement(statement, options: options)
                }
            },
            measure(name: "parseStatements batch") {
                _ = try parseStatements(corpus.script, options: options)
            },
            measure(name: "parseScript diagnostics") {
                _ = parseScript(corpus.script, options: options)
            }
        ]

        for result in results {
            print("\(result.name): \(String(format: "%.2f", result.milliseconds)) ms")
        }
    }

    private static func measure(name: String, _ block: () throws -> Void) -> BenchmarkResult {
        let start = DispatchTime.now().uptimeNanoseconds
        do {
            try block()
        } catch {
            print("\(name) failed: \(error)")
            return BenchmarkResult(name: name, milliseconds: -1)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        let elapsedMs = Double(end - start) / 1_000_000.0
        return BenchmarkResult(name: name, milliseconds: elapsedMs)
    }

    private static func makeCorpus(statementCount: Int) -> (statements: [String], script: String) {
        let templates = [
            "SELECT id, name FROM users WHERE active = 1",
            "SELECT [u].[id] FROM [dbo].[users] [u]",
            "SELECT id FROM users WHERE name ILIKE 'a%'",
            "INSERT INTO users (id, name) VALUES (1, 'Alice')",
            "UPDATE users SET active = 1, name = 'Alice' WHERE id = 1",
            "DELETE FROM users WHERE id = 2",
            "CREATE TABLE users (id INT, name TEXT)",
            "ALTER TABLE users ADD COLUMN email TEXT",
            "DROP TABLE users_archive",
            "TRUNCATE TABLE logs",
            "WITH x AS (SELECT id FROM users) SELECT id FROM x",
            "SELECT id FROM users UNION ALL SELECT id FROM roles"
        ]

        var statements: [String] = []
        statements.reserveCapacity(statementCount)

        for idx in 0..<statementCount {
            statements.append(templates[idx % templates.count])
        }

        let script = statements.joined(separator: ";")
        return (statements: statements, script: script)
    }
}
