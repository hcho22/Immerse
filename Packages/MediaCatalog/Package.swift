// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MediaCatalog", platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "MediaCatalog", targets: ["MediaCatalog"])],
    dependencies: [.package(path: "../FilmDomain")],
    targets: [
        .target(name: "MediaCatalog", dependencies: ["FilmDomain"]),
        .testTarget(name: "MediaCatalogTests", dependencies: ["MediaCatalog"])
    ], swiftLanguageModes: [.v6]
)
