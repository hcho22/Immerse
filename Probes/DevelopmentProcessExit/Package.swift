// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DevelopmentProcessExit", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../Packages/FilmRuntime"), .package(path: "../../Packages/RenderFixtures")],
    targets: [
        .target(name: "DevelopmentExitEvidence", dependencies: ["FilmRuntime", "RenderFixtures"]),
        .executableTarget(name: "DevelopmentExitWorker", dependencies: ["DevelopmentExitEvidence"]),
        .testTarget(name: "DevelopmentProcessExitTests", dependencies: ["DevelopmentExitEvidence"])
    ], swiftLanguageModes: [.v6]
)
