// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FilmPersistence",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "FilmPersistence",
            targets: ["FilmPersistence"]
        )
    ],
    dependencies: [
        .package(path: "../FilmDomain"),
        .package(path: "../RenderCore"),
        .package(path: "../MediaCatalog"),
        .package(path: "../RenderFixtures")
    ],
    targets: [
        .target(
            name: "FilmPersistence",
            dependencies: ["FilmDomain", "RenderCore", "MediaCatalog"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "FilmPersistenceTests",
            dependencies: ["FilmPersistence", "RenderFixtures"]
        )
    ],
    swiftLanguageModes: [.v6]
)
