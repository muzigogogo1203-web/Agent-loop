// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FixtureBuildProof",
    products: [.executable(name: "Driver", targets: ["Driver"])],
    targets: [
        .executableTarget(name: "NativeFixture"),
        .executableTarget(name: "Driver", dependencies: ["NativeFixture"]),
    ]
)
