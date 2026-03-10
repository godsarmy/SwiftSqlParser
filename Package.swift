// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "SwiftSqlParser",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
  ],
  products: [
    .library(
      name: "SwiftSqlParser",
      targets: ["SwiftSqlParser"]
    ),
    .executable(
      name: "SwiftSqlParserCLI",
      targets: ["SwiftSqlParserCLI"]
    ),
    .executable(
      name: "SwiftSqlParserBenchmark",
      targets: ["SwiftSqlParserBenchmark"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.6.0"),
  ],
  targets: [
    .target(
      name: "SwiftSqlParser"
    ),
    .executableTarget(
      name: "SwiftSqlParserCLI",
      dependencies: ["SwiftSqlParser"]
    ),
    .executableTarget(
      name: "SwiftSqlParserBenchmark",
      dependencies: ["SwiftSqlParser"]
    ),
    .testTarget(
      name: "SwiftSqlParserTests",
      dependencies: [
        "SwiftSqlParser",
        .product(name: "Testing", package: "swift-testing"),
      ],
      resources: [
        .process("Resources")
      ]
    ),
  ]
)
