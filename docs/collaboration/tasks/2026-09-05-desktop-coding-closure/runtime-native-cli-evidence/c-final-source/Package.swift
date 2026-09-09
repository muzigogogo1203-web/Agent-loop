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
        .executable(name: "AgentLoopBoardBridge", targets: ["AgentLoopBoardBridge"]),
        .executable(name: "RunTests", targets: ["RunTests"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
    ],
    targets: [
        .target(
            name: "AgentLoopCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "GRDBSQLite", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "AgentLoopApplication",
            dependencies: ["AgentLoopCore"]
        ),
        // Shared test body library — @Test functions live here once, used by both
        // the SwiftPM test target and the RunTests executable.
        .target(
            name: "AgentLoopTestSuite",
            dependencies: ["AgentLoopCore", "AgentLoopApplication"],
            swiftSettings: cltSwiftSettings,
            linkerSettings: cltLinkerSettings
        ),
        .executableTarget(
            name: "AgentLoopApp",
            dependencies: ["AgentLoopCore", "AgentLoopApplication"],
            resources: [.copy("Resources/RanchArt")]
        ),
        .executableTarget(
            name: "AgentLoopBoardBridge",
            dependencies: ["AgentLoopCore"]
        ),
        // Dependency-free native process-mechanics fixture. Only test runners
        // depend on this executable; no product target links or launches it.
        .executableTarget(
            name: "CliMechanicsFixtureRunner",
            dependencies: [],
            path: "Sources/CliMechanicsFixtureRunner"
        ),
        .testTarget(
            name: "AgentLoopCoreTests",
            dependencies: [
                "AgentLoopCore",
                "AgentLoopTestSuite",
                "CliMechanicsFixtureRunner",
            ],
            swiftSettings: cltSwiftSettings,
            linkerSettings: cltLinkerSettings
        ),
        // Standalone test runner — bypasses swiftpm-testing-helper for CI/subshell use
        .executableTarget(
            name: "RunTests",
            dependencies: [
                "AgentLoopCore",
                "AgentLoopTestSuite",
                "CliMechanicsFixtureRunner",
            ],
            path: "Sources/RunTests",
            swiftSettings: cltSwiftSettings,
            linkerSettings: cltLinkerSettings
        ),
        // Test-only executable used by the P1 migration matrix. It always calls
        // the real AppDatabase migrator; no product target depends on it.
        .executableTarget(
            name: "P1MigrationMatrixRunner",
            dependencies: [
                "AgentLoopCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/P1MigrationMatrixRunner"
        ),
    ]
)
