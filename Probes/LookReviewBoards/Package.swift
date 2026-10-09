// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LookReviewBoards", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../Packages/RenderCore"), .package(path: "../../Packages/FilmPersistence")],
    targets: [.executableTarget(name: "LookReviewBoards", dependencies: ["RenderCore", "FilmPersistence"])],
    swiftLanguageModes: [.v6]
)
