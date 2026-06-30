// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexQuotaWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexQuotaCore", targets: ["CodexQuotaCore"]),
        .executable(name: "CodexQuotaWidget", targets: ["CodexQuotaWidget"]),
        .executable(name: "CodexQuotaCoreTests", targets: ["CodexQuotaCoreTests"])
    ],
    targets: [
        .target(name: "CodexQuotaCore"),
        .executableTarget(name: "CodexQuotaWidget", dependencies: ["CodexQuotaCore"]),
        .executableTarget(
            name: "CodexQuotaCoreTests",
            dependencies: ["CodexQuotaCore"],
            path: "Tests/CodexQuotaCoreTests"
        )
    ]
)
