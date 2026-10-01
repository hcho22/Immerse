import Darwin
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderCore
import RenderFixtures

struct ExportScenarioManifest: Codable, Sendable {
    let id: UUID
    let camera: CameraID
    let count: Int
    let label: String
    var filmID: UUID?
    var prepared = false
}
struct ExportAssetEvidence: Codable, Sendable {
    let sequence: Int
    let kind: String
    let path: String
    let expectedHash: String
    let actualHash: String?
    let decodedFrames: Int?
    let duration: Double?
    let error: String?
}
struct ExportInventory: Codable, Sendable {
    let films: [Film]
    let assets: [ExportAssetEvidence]
    let dispositions: [Int: OriginalDisposition]
    let development: DevelopmentRun?
    let privateFiles: [String: String]
    let externalFiles: [String: String]
    var summary: String {
        "films=\(films.count);sources=\(assets.filter { $0.kind == "source" }.count);copies=\(externalFiles.count)"
    }
}

actor ExportScenario {
    nonisolated let directory: URL
    nonisolated let root: URL
    nonisolated let evidence: ScenarioEvidence
    private var manifest: ExportScenarioManifest
    private var processor: FilmProcessor
    private var exporting = false
    private var removing = false
    private var writer: ControlledExportWriter?

    init(id: UUID = UUID(), camera: CameraID = .disposable1990s, count: Int = 1, label: String) throws {
        directory = URL.documentsDirectory.appendingPathComponent("ExportScenarios/\(id)")
        root = directory.appendingPathComponent("App")
        evidence = try ScenarioEvidence(directory: directory.appendingPathComponent("Evidence"))
        let url = directory.appendingPathComponent("scenario.json")
        if FileManager.default.fileExists(atPath: url.path) {
            manifest = try JSONDecoder().decode(ExportScenarioManifest.self, from: Data(contentsOf: url))
            guard manifest.id == id, manifest.camera == camera, manifest.count == count, manifest.label == label else {
                throw ExportHarnessError.invalidControl
            }
        } else {
            guard (1...2).contains(count) else { throw ExportHarnessError.invalidControl }
            manifest = .init(id: id, camera: camera, count: count, label: label)
            try ScenarioEvidence.persist(manifest, to: url)
        }
        processor = try FilmProcessor(root: root)
        evidence.record("session-open", ["run": id.uuidString, "camera": camera.rawValue, "label": label,
            "bundle": Bundle.main.bundleIdentifier ?? "unknown", "backend": "injected-private-writer",
            "runtime": ProcessInfo.processInfo.operatingSystemVersionString,
            "simulator": ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "physical-not-authorized"])
    }

    func prepare(develop: Bool = true) async throws {
        guard manifest.filmID == nil, !exporting else { throw ExportHarnessError.alreadyPrepared }
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 160; settings.photoHeight = 120
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        let fixtures = directory.appendingPathComponent("Fixtures")
        let generated = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let repository = try FilmRepository(rootURL: root)
        let camera = CameraCatalog.package(for: manifest.camera)
        let film = try repository.createFilm(camera: camera, title: "Private synthetic export",
            movieOrientation: camera.medium == .movie ? .portrait : nil, access: .subscription)
        manifest.filmID = film.id
        try persistManifest()
        for sequence in 1...manifest.count {
            let date = Date(timeIntervalSince1970: 1_790_880_000 + Double(sequence))
            if camera.medium == .photo {
                try repository.savePhotoCapture(filmID: film.id,
                    sourceData: Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg")), savedAt: date)
            } else {
                try repository.saveMovieClip(filmID: film.id,
                    sourceData: Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov")),
                    durationSeconds: generated.movie.durationSeconds, orientation: .landscape, savedAt: date)
            }
        }
        if camera.revealRule != .instantPerExposure { try repository.completeEarly(filmID: film.id) }
        if develop { try await processor.develop(filmID: film.id) }
        manifest.prepared = true; try persistManifest()
        evidence.record("native-fixture-created", ["film": film.id.uuidString, "developed": String(develop)])
        _ = try await inventory("prepared")
    }

    func makeWriter(_ plan: ExportWriterPlan = .init()) throws -> ControlledExportWriter {
        try ControlledExportWriter(plan: plan, directory: directory.appendingPathComponent("ExternalCopies"),
            workRoot: root.appendingPathComponent("Work"), evidence: evidence)
    }
    func export(writer: ControlledExportWriter, originals: Bool = true, sequences: [Int] = [1],
                authorization: PhotoLibraryAuthorizationStatus = .authorized) async throws {
        guard !exporting, !removing, let id = manifest.filmID else { throw ExportHarnessError.busy }
        exporting = true; self.writer = writer
        defer { exporting = false }
        evidence.record("export-requested", ["originals": String(originals), "sequences": String(describing: sequences)])
        do {
            try await processor.export(filmID: id, sequences: sequences, originals: originals,
                coordinator: PhotoExportCoordinator(authorizer: InjectedAuthorization(status: authorization, evidence: evidence), writer: writer))
            evidence.record("export-returned")
        } catch { evidence.record("export-error", ["error": String(describing: error)]); throw error }
    }
    func suspend() async {
        evidence.record("suspend-requested")
        await processor.suspendProcessing()
        evidence.record("suspend-returned")
    }
    func removeFilm(discardSequence: Int? = nil) async throws {
        guard !removing, let id = manifest.filmID else { throw ExportHarnessError.busy }
        removing = true; defer { removing = false }
        evidence.record("removal-requested", ["operation": discardSequence.map { "discard-\($0)" } ?? "delete"])
        if let sequence = discardSequence { try await processor.discard(filmID: id, sequence: sequence) }
        else { try await processor.deleteFilm(filmID: id) }
        evidence.record("removal-returned")
    }
    func recover() throws {
        guard !exporting, !removing else { throw ExportHarnessError.busy }
        try FilmRepository(rootURL: root).recover()
        processor = try FilmProcessor(root: root)
        evidence.record("recovery-returned", ["automaticallyExported": "false"])
    }
    func editFirstPhoto() async throws -> String {
        guard let id = manifest.filmID else { throw ExportHarnessError.missingPreparation }
        let bytes = try await processor.saveRecipe(filmID: id, sequence: 1, recipe: .init(printExposureStops: 0.5))
        return ScenarioEvidence.hash(bytes)
    }
    func assetURL(sequence: Int = 1, kind: StoredAsset.Kind) throws -> URL {
        guard let id = manifest.filmID, let asset = try FilmRepository(rootURL: root).mediaAsset(filmID: id, sequenceNumber: sequence, kind: kind) else {
            throw ExportHarnessError.missingPreparation
        }
        return asset.url
    }
    func corruptMaster(decodable: Bool) throws -> Data {
        let url = try assetURL(kind: .master)
        let preserved = try Data(contentsOf: url)
        let replacement = decodable ? try Data(contentsOf: directory.appendingPathComponent("Fixtures/synthetic-developed-photo.jpg"))
            : Data("invalid known synthetic master".utf8)
        guard replacement != preserved else { throw ExportHarnessError.invalidControl }
        try preserved.write(to: evidence.directory.appendingPathComponent("master-before-corruption.jpg"), options: .withoutOverwriting)
        try replacement.write(to: url, options: .atomic)
        evidence.record("injected-master-corruption", ["decodable": String(decodable)])
        return preserved
    }
    func restoreSyntheticMaster(_ bytes: Data) throws {
        try bytes.write(to: assetURL(kind: .master), options: .atomic)
        evidence.record("synthetic-master-restored", ["sha256": ScenarioEvidence.hash(bytes)])
    }
    func phase() async -> String { await writer?.phase ?? "idle" }
    func terminateAtWriterBoundary() async throws {
        guard exporting, await phase().hasPrefix("paused-") else { throw ExportHarnessError.invalidControl }
        evidence.record("ordinary-process-exit", ["status": "79", "powerLoss": "false"])
        _exit(79)
    }

    func inventory(_ label: String) async throws -> ExportInventory {
        if exporting || removing {
            guard await phase().hasPrefix("paused-") else { throw ExportHarnessError.busy }
        }
        let repository = try FilmRepository(rootURL: root)
        let films = try repository.allFilms()
        var assets: [ExportAssetEvidence] = []
        var dispositions: [Int: OriginalDisposition] = [:]
        var development: DevelopmentRun?
        if let film = films.first {
            development = try repository.developmentRun(filmID: film.id)
            for sequence in 0...manifest.count {
                if let choice = try repository.originalDisposition(filmID: film.id, sequenceNumber: sequence) { dispositions[sequence] = choice }
                for kind in [StoredAsset.Kind.source, .master, .clip, .movie] {
                    guard let asset = try repository.mediaAsset(filmID: film.id, sequenceNumber: sequence, kind: kind) else { continue }
                    var verified: VerifiedMedia?
                    var failure: String?
                    do {
                        verified = film.camera.medium == .photo ? try VerifiedMedia.photo(at: asset.url)
                            : try await VerifiedMedia.movie(at: asset.url, allowsAudio: kind == .movie)
                    } catch { failure = String(describing: error) }
                    let bytes = try? Data(contentsOf: asset.url)
                    assets.append(.init(sequence: sequence, kind: kind.rawValue, path: asset.record.relativePath,
                        expectedHash: asset.record.sha256, actualHash: bytes.map(ScenarioEvidence.hash),
                        decodedFrames: verified?.decodedFrameCount, duration: verified?.durationSeconds, error: failure))
                }
            }
        }
        let value = ExportInventory(films: films, assets: assets, dispositions: dispositions, development: development,
            privateFiles: try fileHashes(root), externalFiles: try fileHashes(directory.appendingPathComponent("ExternalCopies")))
        let filename = "inventory-\(UUID()).json"
        try ScenarioEvidence.persist(value, to: evidence.directory.appendingPathComponent(filename))
        evidence.record("inventory", ["label": label, "file": filename, "summary": value.summary])
        return value
    }
    private func fileHashes(_ root: URL) throws -> [String: String] {
        var files: [String: String] = [:]
        if let iterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let url as URL in iterator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                files[String(url.path.dropFirst(root.path.count + 1))] = ScenarioEvidence.hash(try Data(contentsOf: url))
            }
        }
        return files
    }
    private func persistManifest() throws {
        try ScenarioEvidence.persist(manifest, to: directory.appendingPathComponent("scenario.json"))
    }
}
