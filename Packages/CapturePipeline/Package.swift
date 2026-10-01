// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CapturePipeline",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "CapturePipeline",
            targets: ["CapturePipeline"]
        )
    ],
    dependencies: [
        .package(path: "../FilmDomain"),
        .package(path: "../FilmPersistence"),
        .package(path: "../NativeAdapters")
    ],
    targets: [
        .target(
            name: "CapturePipeline",
            dependencies: [
                "FilmDomain",
                "FilmPersistence",
                "NativeAdapters"
            ]
        ),
        .testTarget(
            name: "CapturePipelineTests",
            dependencies: ["CapturePipeline"]
        )
    ],
    swiftLanguageModes: [.v6]
)
