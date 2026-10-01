// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FilmRuntime", platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "FilmRuntime", targets: ["FilmRuntime"])],
    dependencies: [
        .package(path: "../FilmDomain"), .package(path: "../FilmPersistence"),
        .package(path: "../RenderCore"), .package(path: "../NativeAdapters"),
        .package(path: "../EntitlementCore"), .package(path: "../CapturePipeline"),
        .package(path: "../RenderFixtures")
    ],
    targets: [
        .target(name: "FilmRuntime", dependencies: ["FilmDomain", "FilmPersistence", "RenderCore", "NativeAdapters", "EntitlementCore", "CapturePipeline"]),
        .testTarget(name: "FilmRuntimeTests", dependencies: ["FilmRuntime", "RenderFixtures"])
    ], swiftLanguageModes: [.v6]
)
