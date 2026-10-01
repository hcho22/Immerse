// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RenderCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "RenderCore",
            targets: ["RenderCore"]
        )
    ],
    dependencies: [
        .package(path: "../FilmDomain")
    ],
    targets: [
        .target(
            name: "RenderCore",
            dependencies: ["FilmDomain"]
        ),
        .testTarget(
            name: "RenderCoreTests",
            dependencies: ["RenderCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
