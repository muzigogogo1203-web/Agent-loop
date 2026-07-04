// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentLoop",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentLoopCore", targets: ["AgentLoopCore"]),
        .executable(name: "AgentLoopApp", targets: ["AgentLoopApp"]),
        .executable(name: "RunTests", targets: ["RunTests"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
    ],
    targets: [
        .target(
            name: "AgentLoopCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "AgentLoopApp",
            dependencies: ["AgentLoopCore"]
        ),
        .testTarget(
            name: "AgentLoopCoreTests",
            dependencies: ["AgentLoopCore"],
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-disable-cross-import-overlays",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ]
        ),
        // Standalone test runner — bypasses swiftpm-testing-helper for CI/subshell use
        .executableTarget(
            name: "RunTests",
            dependencies: ["AgentLoopCore"],
            path: "Sources/RunTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-disable-cross-import-overlays",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ]
        ),
    ]
)
