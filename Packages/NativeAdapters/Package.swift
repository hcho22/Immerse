// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NativeAdapters",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "NativeAdapters",
            targets: ["NativeAdapters"]
        )
    ],
    dependencies: [
        .package(path: "../FilmDomain"),
        .package(path: "../RenderFixtures")
    ],
    targets: [
        .target(
            name: "NativeAdapters",
            dependencies: ["FilmDomain"]
        ),
        .testTarget(
            name: "NativeAdaptersTests",
            dependencies: ["NativeAdapters", "RenderFixtures"]
        )
    ],
    swiftLanguageModes: [.v6]
)
