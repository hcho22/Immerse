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
        .package(path: "../FilmDomain")
    ],
    targets: [
        .target(
            name: "FilmPersistence",
            dependencies: ["FilmDomain"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "FilmPersistenceTests",
            dependencies: ["FilmPersistence"]
        )
    ],
    swiftLanguageModes: [.v6]
)
