// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacSpaceGuard",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MacSpaceGuardCore", targets: ["MacSpaceGuardCore"]),
        .executable(name: "MacSpaceGuard", targets: ["MacSpaceGuard"]),
        .executable(name: "MacSpaceGuardSelfTest", targets: ["MacSpaceGuardSelfTest"])
    ],
    targets: [
        .target(name: "MacSpaceGuardCore"),
        .executableTarget(
            name: "MacSpaceGuard",
            dependencies: ["MacSpaceGuardCore"]
        ),
        .executableTarget(
            name: "MacSpaceGuardSelfTest",
            dependencies: ["MacSpaceGuardCore"]
        ),
        .testTarget(
            name: "MacSpaceGuardCoreTests",
            dependencies: ["MacSpaceGuardCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
