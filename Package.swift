// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwiftSqlParser",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SwiftSqlParser",
            targets: ["SwiftSqlParser"]
        )
    ],
    targets: [
        .target(
            name: "SwiftSqlParser"
        ),
        .testTarget(
            name: "SwiftSqlParserTests",
            dependencies: ["SwiftSqlParser"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
