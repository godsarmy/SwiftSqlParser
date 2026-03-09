import Foundation
import SwiftSqlParser

@main
struct SwiftSqlParserCLIMain {
  static func main() {
    let configuration: CLIConfiguration
    do {
      configuration = try CLIConfiguration(arguments: Array(CommandLine.arguments.dropFirst()))
    } catch let error as CLIError {
      printError(error.message)
      Foundation.exit(error.exitCode)
    } catch {
      printError("Unexpected CLI error: \(error)")
      Foundation.exit(1)
    }

    let input = readStandardInput().trimmingCharacters(in: .whitespacesAndNewlines)
    guard input.isEmpty == false else {
      printError("No SQL received on stdin. Pipe a statement or script into SwiftSqlParserCLI.")
      Foundation.exit(1)
    }

    if configuration.scriptMode {
      runScript(input: input, configuration: configuration)
    } else {
      runStatement(input: input, configuration: configuration)
    }
  }

  private static func runStatement(input: String, configuration: CLIConfiguration) {
    let result = SqlParser().parseStatementResult(input)
    if let diagnostic = result.diagnostic {
      printDiagnostic(diagnostic)
      Foundation.exit(1)
    }

    guard let statement = result.statement else {
      printError("Parser returned no statement and no diagnostic.")
      Foundation.exit(1)
    }

    emit(value: statement, configuration: configuration)
  }

  private static func runScript(input: String, configuration: CLIConfiguration) {
    let result = parseScript(input)
    if let diagnostic = result.diagnostics.first {
      printDiagnostic(diagnostic)
      Foundation.exit(1)
    }

    emit(value: result, configuration: configuration)
  }

  private static func emit(value: Any, configuration: CLIConfiguration) {
    if configuration.jsonOutput {
      do {
        let object = JSONTreeEncoder.encode(value)
        let data = try JSONSerialization.data(
          withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
          throw CLIError.runtime("Unable to encode JSON output as UTF-8.")
        }
        print(text)
      } catch let error as CLIError {
        printError(error.message)
        Foundation.exit(error.exitCode)
      } catch {
        printError("Failed to render JSON output: \(error)")
        Foundation.exit(1)
      }
      return
    }

    print(HumanReadableTreeFormatter.format(value))
  }

  private static func readStandardInput() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
  }

  private static func printDiagnostic(_ diagnostic: SqlDiagnostic) {
    var lines = ["Parse error: \(diagnostic.message)"]
    lines.append("code: \(diagnostic.code.rawValue)")
    lines.append("normalized: \(diagnostic.normalizedMessage)")
    lines.append(
      "location: line \(diagnostic.location.line), column \(diagnostic.location.column), offset \(diagnostic.location.offset)"
    )
    if let token = diagnostic.token {
      lines.append("token: \(token)")
    }
    FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
  }

  private static func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }
}

private struct CLIConfiguration {
  let scriptMode: Bool
  let jsonOutput: Bool

  init(arguments: [String]) throws {
    var scriptMode = false
    var jsonOutput = false

    for argument in arguments {
      switch argument {
      case "--script":
        scriptMode = true
      case "--json":
        jsonOutput = true
      case "--help", "-h":
        throw CLIError.usage(Self.usage)
      default:
        throw CLIError.usage("Unknown argument: \(argument)\n\n\(Self.usage)")
      }
    }

    self.scriptMode = scriptMode
    self.jsonOutput = jsonOutput
  }

  private static let usage = """
    Usage: swift run SwiftSqlParserCLI [--script] [--json]

    Reads SQL from stdin.

      --script   Parse stdin as a script and dump the script parse result
      --json     Emit the parsed structure as pretty-printed JSON
      --help     Show this message
    """
}

private enum CLIError: Error {
  case usage(String)
  case runtime(String)

  var message: String {
    switch self {
    case .usage(let message), .runtime(let message):
      return message
    }
  }

  var exitCode: Int32 {
    switch self {
    case .usage:
      return 64
    case .runtime:
      return 1
    }
  }
}

private enum HumanReadableTreeFormatter {
  static func format(_ value: Any) -> String {
    var lines: [String] = []
    append(value, label: nil, indent: 0, into: &lines)
    return lines.joined(separator: "\n")
  }

  private static func append(_ value: Any, label: String?, indent: Int, into lines: inout [String])
  {
    let prefix = String(repeating: "  ", count: indent)
    let namePrefix = label.map { "\($0): " } ?? ""

    if let scalar = scalarDescription(for: value) {
      lines.append("\(prefix)\(namePrefix)\(scalar)")
      return
    }

    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
      if let child = mirror.children.first {
        append(child.value, label: label, indent: indent, into: &lines)
      } else {
        lines.append("\(prefix)\(namePrefix)nil")
      }
      return
    }

    let typeName = String(describing: Swift.type(of: value))

    switch mirror.displayStyle {
    case .collection, .set:
      lines.append("\(prefix)\(namePrefix)\(typeName) [")
      for (index, child) in mirror.children.enumerated() {
        append(child.value, label: "[\(index)]", indent: indent + 1, into: &lines)
      }
      lines.append("\(prefix)]")
    case .dictionary:
      lines.append("\(prefix)\(namePrefix)\(typeName) {")
      for child in mirror.children {
        let pair = Array(Mirror(reflecting: child.value).children)
        if pair.count == 2 {
          let keyText = scalarDescription(for: pair[0].value) ?? String(describing: pair[0].value)
          append(pair[1].value, label: keyText, indent: indent + 1, into: &lines)
        }
      }
      lines.append("\(prefix)}")
    case .enum:
      lines.append("\(prefix)\(namePrefix)\(String(describing: value))")
    default:
      lines.append("\(prefix)\(namePrefix)\(typeName)")
      for child in mirror.children {
        append(child.value, label: child.label, indent: indent + 1, into: &lines)
      }
    }
  }

  private static func scalarDescription(for value: Any) -> String? {
    switch value {
    case let string as String:
      return "\"\(string)\""
    case let int as Int:
      return String(int)
    case let int8 as Int8:
      return String(int8)
    case let int16 as Int16:
      return String(int16)
    case let int32 as Int32:
      return String(int32)
    case let int64 as Int64:
      return String(int64)
    case let uint as UInt:
      return String(uint)
    case let uint8 as UInt8:
      return String(uint8)
    case let uint16 as UInt16:
      return String(uint16)
    case let uint32 as UInt32:
      return String(uint32)
    case let uint64 as UInt64:
      return String(uint64)
    case let double as Double:
      return String(double)
    case let float as Float:
      return String(float)
    case let bool as Bool:
      return String(bool)
    default:
      return nil
    }
  }
}

private enum JSONTreeEncoder {
  static func encode(_ value: Any) -> Any {
    if let scalar = scalarValue(for: value) {
      return scalar
    }

    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
      if let child = mirror.children.first {
        return encode(child.value)
      }
      return NSNull()
    }

    switch mirror.displayStyle {
    case .collection, .set:
      return mirror.children.map { encode($0.value) }
    case .dictionary:
      var object: [String: Any] = [:]
      for child in mirror.children {
        let pair = Array(Mirror(reflecting: child.value).children)
        if pair.count == 2 {
          let key =
            scalarValue(for: pair[0].value).map(String.init(describing:))
            ?? String(describing: pair[0].value)
          object[key] = encode(pair[1].value)
        }
      }
      return object
    case .enum:
      return String(describing: value)
    default:
      var fields: [String: Any] = [:]
      for child in mirror.children {
        fields[child.label ?? "value"] = encode(child.value)
      }
      return [
        "type": String(describing: Swift.type(of: value)),
        "fields": fields,
      ]
    }
  }

  private static func scalarValue(for value: Any) -> Any? {
    switch value {
    case let string as String:
      return string
    case let int as Int:
      return int
    case let int8 as Int8:
      return Int(int8)
    case let int16 as Int16:
      return Int(int16)
    case let int32 as Int32:
      return Int(int32)
    case let int64 as Int64:
      return int64
    case let uint as UInt:
      return uint
    case let uint8 as UInt8:
      return UInt(uint8)
    case let uint16 as UInt16:
      return UInt(uint16)
    case let uint32 as UInt32:
      return UInt(uint32)
    case let uint64 as UInt64:
      return uint64
    case let double as Double:
      return double
    case let float as Float:
      return Double(float)
    case let bool as Bool:
      return bool
    default:
      return nil
    }
  }
}
