// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "EntitlementCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "EntitlementCore",
            targets: ["EntitlementCore"]
        )
    ],
    targets: [
        .target(
            name: "EntitlementCore"
        ),
        .testTarget(
            name: "EntitlementCoreTests",
            dependencies: ["EntitlementCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
