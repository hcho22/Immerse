// swift-tools-version: 6.2

import PackageDescription

// The iPhone's side of Immerse's server (v2 PRD section 9): the configuration that turns it on, Convex's HTTP API
// behind a small interface, Accounts, push tokens, the picture upload path and the age 13-or-over rule. It has no
// dependency: personal Films never import it, and nothing in it runs unless the server is configured.
let package = Package(
    name: "ImmerseServer",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "ImmerseServer",
            targets: ["ImmerseServer"]
        )
    ],
    targets: [
        .target(
            name: "ImmerseServer"
        ),
        .testTarget(
            name: "ImmerseServerTests",
            dependencies: ["ImmerseServer"]
        )
    ],
    swiftLanguageModes: [.v6]
)
