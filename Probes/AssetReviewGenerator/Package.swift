// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AssetReviewGenerator", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../Packages/RenderCore"), .package(path: "../../Packages/RenderFixtures"),
        .package(path: "../../Packages/FilmPersistence")],
    targets: [.executableTarget(name: "AssetReviewGenerator", dependencies: ["RenderCore", "RenderFixtures", "FilmPersistence"])],
    swiftLanguageModes: [.v6]
)
