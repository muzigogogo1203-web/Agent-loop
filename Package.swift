// swift-tools-version: 6.0
import PackageDescription
import Foundation

let cltFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let useCLTWorkaround = FileManager.default.fileExists(atPath: cltFrameworks)

// Shared CLT-only swift/linker settings for targets that need swift-testing.
// Appended only when the CLT layout is detected; Xcode installs Testing differently.
let cltSwiftSettings: [SwiftSetting] = useCLTWorkaround ? [
    .unsafeFlags([
        "-F", cltFrameworks,
        "-disable-cross-import-overlays",
    ])
] : []

let cltLinkerSettings: [LinkerSetting] = useCLTWorkaround ? [
    .unsafeFlags([
        "-F", cltFrameworks,
        "-framework", "Testing",
        "-Xlinker", "-rpath",
        "-Xlinker", cltFrameworks,
    ])
] : []

let package = Package(
    name: "AgentLoop",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentLoopCore", targets: ["AgentLoopCore"]),
        .library(name: "AgentLoopTestSuite", targets: ["AgentLoopTestSuite"]),
        .executable(name: "AgentLoopApp", targets: ["AgentLoopApp"]),
        .executable(name: "RunTests", targets: ["RunTests"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "AgentLoopCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        // Shared test body library — @Test functions live here once, used by both
        // the SwiftPM test target and the RunTests executable.
        .target(
            name: "AgentLoopTestSuite",
            dependencies: ["AgentLoopCore"],
            swiftSettings: cltSwiftSettings,
            linkerSettings: cltLinkerSettings
        ),
        .executableTarget(
            name: "AgentLoopApp",
            dependencies: [
                "AgentLoopCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "AgentLoopCoreTests",
            dependencies: ["AgentLoopCore", "AgentLoopTestSuite"],
            swiftSettings: cltSwiftSettings,
            linkerSettings: cltLinkerSettings
        ),
        // Standalone test runner — bypasses swiftpm-testing-helper for CI/subshell use
        .executableTarget(
            name: "RunTests",
            dependencies: ["AgentLoopCore", "AgentLoopTestSuite"],
            path: "Sources/RunTests",
            swiftSettings: cltSwiftSettings,
            linkerSettings: cltLinkerSettings
        ),
    ]
)
