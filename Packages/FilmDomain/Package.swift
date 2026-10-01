// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FilmDomain",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "FilmDomain",
            targets: ["FilmDomain"]
        )
    ],
    targets: [
        .target(name: "FilmDomain"),
        .testTarget(
            name: "FilmDomainTests",
            dependencies: ["FilmDomain"]
        )
    ],
    swiftLanguageModes: [.v6]
)
