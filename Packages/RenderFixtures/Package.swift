// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RenderFixtures",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "RenderFixtures",
            targets: ["RenderFixtures"]
        ),
        .executable(
            name: "RenderFixtureTool",
            targets: ["RenderFixtureTool"]
        )
    ],
    targets: [
        .target(
            name: "RenderFixtures"
        ),
        .executableTarget(
            name: "RenderFixtureTool",
            dependencies: ["RenderFixtures"]
        ),
        .testTarget(
            name: "RenderFixturesTests",
            dependencies: ["RenderFixtures"]
        )
    ],
    swiftLanguageModes: [.v6]
)
