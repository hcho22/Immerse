// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TrialReceiptStudy", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../Packages/FilmPersistence"), .package(path: "../../Packages/RenderFixtures")],
    targets: [
        .target(name: "TrialReceiptStudy", dependencies: ["FilmPersistence"]),
        .executableTarget(name: "ReceiptCrashWorker", dependencies: ["TrialReceiptStudy"]),
        .testTarget(name: "TrialReceiptStudyTests", dependencies: ["TrialReceiptStudy", "RenderFixtures"])
    ], swiftLanguageModes: [.v6]
)
