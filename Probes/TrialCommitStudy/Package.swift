// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TrialReceiptStudy", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../Packages/FilmPersistence"), .package(path: "../../Packages/RenderFixtures"),
        .package(path: "../../Packages/FilmRuntime")],
    targets: [
        .target(name: "TrialReceiptStudy", dependencies: ["FilmPersistence"]),
        .executableTarget(name: "ReceiptCrashWorker", dependencies: ["TrialReceiptStudy"]),
        .target(name: "ProductionReceiptHarness", dependencies: ["FilmRuntime"]),
        .executableTarget(name: "ProductionReceiptCrashWorker", dependencies: ["ProductionReceiptHarness"]),
        .testTarget(name: "TrialReceiptStudyTests", dependencies: ["TrialReceiptStudy", "RenderFixtures", "ProductionReceiptHarness"])
    ], swiftLanguageModes: [.v6]
)
