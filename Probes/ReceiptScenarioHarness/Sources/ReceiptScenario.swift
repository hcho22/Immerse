import Darwin
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderFixtures
import Security

actor ReceiptPhaseGate {
    private let target: String
    private let evidence: ScenarioEvidence
    private var continuation: CheckedContinuation<Void, Never>?
    private var enabled = true
    private(set) var phase = "idle"
    init(target: String, evidence: ScenarioEvidence) { self.target = target; self.evidence = evidence }
    func checkpoint(_ point: TrialCommitCheckpoint) async {
        let name = String(describing: point)
        evidence.record("production-checkpoint", ["phase": name])
        if enabled && name == target {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                phase = "paused-\(name)"
                evidence.record("paused", ["phase": name])
            }
        }
    }
    func release() throws {
        guard let continuation else { throw HarnessError.notPaused }
        self.continuation = nil; phase = "released"; enabled = false
        evidence.record("boundary-released")
        continuation.resume()
    }
    func disable() { enabled = false }
}

struct ScenarioInventory: Codable, Sendable {
    let configuration: ScenarioConfiguration
    let manifest: ScenarioManifest
    let films: [Film]
    let sqlReceipt: CaptureCommitReceipt?
    let outboxFilmIDs: [UUID]
    let pending: Bool
    let underlyingStatus: Int32
    let underlyingRecord: DeviceTrialRecord?
    let logicalRead: String
    let sourceMatches: Bool?
    let decodedFrames: Int?
    let stagingExists: Bool
    let files: [String: String]
    var summary: String {
        "films=\(films.count);saved=\(films.first?.savedCaptureCount ?? 0);pending=\(pending);consumed=\(underlyingRecord?.isConsumed ?? false);hash=\(sourceMatches.map(String.init) ?? "none")"
    }
}

actor ReceiptScenario {
    nonisolated let configuration: ScenarioConfiguration
    nonisolated let evidence: ScenarioEvidence
    let gate: ReceiptPhaseGate
    private let calls: RecordedReceiptCalls
    private let store: KeychainDeviceTrialStore
    private let root: URL
    private var manifest: ScenarioManifest
    private var owner: TrialCoordinator
    private var receiver: TrialCaptureReceiver?
    private var saving = false
    private var deleting = false

    init(configuration: ScenarioConfiguration) throws {
        guard ["none", "prepared", "receiptResolved", "projected"].contains(configuration.pauseAt) else {
            throw HarnessError.invalidConfiguration
        }
        guard configuration.fault != .invalidMedia || configuration.camera.medium == .photo,
              configuration.fault != .corruptPending || configuration.pauseAt == "prepared" else {
            throw HarnessError.invalidConfiguration
        }
        self.configuration = configuration
        root = configuration.directory.appendingPathComponent("App")
        evidence = try ScenarioEvidence(directory: configuration.directory.appendingPathComponent("Evidence"))
        let manifestURL = configuration.directory.appendingPathComponent("scenario.json")
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            manifest = try JSONDecoder().decode(ScenarioManifest.self, from: Data(contentsOf: manifestURL))
            guard manifest.configuration == configuration else { throw HarnessError.evidenceMismatch }
        } else {
            manifest = ScenarioManifest(configuration: configuration, captureUUID: UUID(),
                savedAt: Date(timeIntervalSince1970: 1_790_870_000))
            try ScenarioEvidence.persist(manifest, to: manifestURL)
        }
        calls = try RecordedReceiptCalls(configuration: configuration, evidence: evidence)
        store = KeychainDeviceTrialStore(service: configuration.service, calls: calls)
        gate = ReceiptPhaseGate(target: configuration.pauseAt, evidence: evidence)
        let gate = self.gate
        owner = try TrialCoordinator(root: root, store: store, projectionFailure: configuration.fault.projection,
            checkpoint: { await gate.checkpoint($0) })
        evidence.record("session-open", ["namespace": configuration.service, "account": "device-trial",
            "backend": configuration.backend.rawValue, "scenario": configuration.name,
            "runtime": ProcessInfo.processInfo.operatingSystemVersionString,
            "bundle": Bundle.main.bundleIdentifier ?? "unknown",
            "simulator": ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "physical-not-authorized-by-build",
            "fault": configuration.fault.rawValue, "pauseAt": configuration.pauseAt])
    }

    func prepare() async throws {
        guard !manifest.prepared, manifest.filmID == nil, !saving else { throw HarnessError.alreadyPrepared }
        let initial = calls.observeUnderlying()
        guard initial.status == errSecItemNotFound else {
            if initial.status != errSecSuccess { _ = try store.read() }
            throw HarnessError.namespaceAlreadyExists
        }
        if [.legacyPending, .legacyDeleted].contains(configuration.fault) {
            // A NEW namespace gets a versionless legacy fixture; never rewrite an existing item.
            var value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(DeviceTrialRecord())) as! [String: Any]
            value.removeValue(forKey: "schemaVersion")
            let status = calls.add(service: configuration.service, data: try JSONSerialization.data(withJSONObject: value, options: .sortedKeys))
            guard status == errSecSuccess else { _ = try store.read(); throw HarnessError.evidenceMismatch }
        }
        saving = true; defer { saving = false }
        let camera = configuration.camera
        let film = try await owner.start(camera: camera, title: "Synthetic receipt scenario", orientation: camera.medium == .movie ? .portrait : nil)
        manifest.filmID = film.id
        try persistManifest()
        let repository = try FilmRepository(rootURL: root)
        let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
        try files.prepare(PendingCaptureRecord(id: manifest.captureUUID, mediaKind: camera.medium == .photo ? .photo : .movie,
            createdAt: manifest.savedAt, orientation: camera.medium == .movie ? .landscape : nil,
            remainingSeconds: film.remainingMovieSeconds))
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 160; settings.photoHeight = 120
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        let fixtures = configuration.directory.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let source: URL
        if configuration.fault == .invalidMedia {
            source = try repository.captureStagingDirectory(filmID: film.id).appendingPathComponent("\(manifest.captureUUID).photo")
            try Data("invalid synthetic photo".utf8).write(to: source, options: .withoutOverwriting)
        } else if camera.medium == .photo {
            source = try files.savePhoto(Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg")), id: manifest.captureUUID)
        } else {
            source = files.movieDestination(id: manifest.captureUUID)
            try FileManager.default.copyItem(at: fixtures.appendingPathComponent("synthetic-developed-movie.mov"), to: source)
            let nativeEvent = try await files.movieSavedEvent(id: manifest.captureUUID, orientation: .landscape, remainingSeconds: film.remainingMovieSeconds!)
            guard case let .movieClipSaved(_, duration, _) = nativeEvent else { throw HarnessError.evidenceMismatch }
            manifest.duration = duration
        }
        manifest.sourcePath = source.path.replacingOccurrences(of: root.path + "/", with: "")
        manifest.sourceHash = ScenarioEvidence.hash(try Data(contentsOf: source))
        manifest.prepared = true
        try persistManifest()
        receiver = try await owner.receiver(filmID: film.id)
        if [.legacyPending, .legacyDeleted].contains(configuration.fault) {
            if camera.medium == .photo {
                try repository.savePhotoCapture(filmID: film.id, sourceData: Data(contentsOf: source), captureID: source.lastPathComponent, savedAt: manifest.savedAt)
            } else {
                try repository.saveMovieClip(filmID: film.id, sourceData: Data(contentsOf: source), durationSeconds: manifest.duration!,
                    orientation: .landscape, captureID: source.lastPathComponent, savedAt: manifest.savedAt)
            }
            try files.removeCommittedFile(for: event())
            if configuration.fault == .legacyDeleted { try await owner.deleteFilm(filmID: film.id) }
            evidence.record("legacy-fixture-created", ["deleted": String(configuration.fault == .legacyDeleted)])
        }
        evidence.record("prepared-input", ["filmID": film.id.uuidString, "captureID": source.lastPathComponent, "sha256": manifest.sourceHash!])
    }

    func commit() async throws {
        guard !saving, !deleting, let id = manifest.filmID else { throw HarnessError.busy }
        saving = true; defer { saving = false }
        if receiver == nil { receiver = try await owner.receiver(filmID: id) }
        let files = try CapturedMediaFiles(directory: FilmRepository(rootURL: root).captureStagingDirectory(filmID: id))
        evidence.record("commit-requested")
        do {
            try await receiver!.commit(event())
            try files.removeCommittedFile(for: event())
            evidence.record("commit-returned")
        } catch { evidence.record("commit-error", ["error": String(describing: error)]); throw error }
    }

    func recover() async throws {
        guard !saving, !deleting else { throw HarnessError.busy }
        saving = true; defer { saving = false }
        await gate.disable()
        try FilmRepository(rootURL: root).recover()
        owner = try TrialCoordinator(root: root, store: store)
        receiver = nil
        evidence.record("recovery-started", ["projectionInjection": "disabled", "receiptInjection": "preserved until explicit resolve"])
        do { try await owner.recoverSavedCaptures(); evidence.record("recovery-returned") }
        catch { evidence.record("recovery-error", ["error": String(describing: error)]); throw error }
    }

    func resolveInjectedFault() throws { try calls.resolveInjectedFault() }
    func release() async throws { try await gate.release() }
    func phase() async -> String { await gate.phase }
    func terminateAtBoundary() async throws {
        guard await gate.phase.hasPrefix("paused-") else { throw HarnessError.notPaused }
        evidence.record("ordinary-process-exit-requested", ["status": "77", "powerLoss": "false"])
        _exit(77)
    }

    func corruptPending() async throws {
        guard configuration.fault == .corruptPending, await gate.phase == "paused-prepared",
              let id = manifest.filmID, let source = manifest.sourcePath else { throw HarnessError.notPaused }
        let url = root.appendingPathComponent("Staging/\(id)/Commit/\(URL(fileURLWithPath: source).lastPathComponent)")
        try Data("corrupted isolated pending media".utf8).write(to: url, options: .atomic)
        evidence.record("injected-pending-corruption", ["relativePath": "Staging/\(id)/Commit/\(url.lastPathComponent)"])
    }

    func deleteFilm() async throws {
        guard !deleting, let id = manifest.filmID else { throw HarnessError.missingPreparation }
        deleting = true; defer { deleting = false }
        evidence.record("delete-requested", ["queueEntryObserved": "false"])
        try await owner.deleteFilm(filmID: id)
        evidence.record("delete-returned")
    }

    func staleCallback() async throws {
        guard !saving, !deleting, let receiver else { throw HarnessError.missingPreparation }
        do { try await receiver.commit(event()); evidence.record("callback-returned") }
        catch { evidence.record("callback-error", ["error": String(describing: error)]); throw error }
    }

    func attemptSecondLoad() async throws {
        evidence.record("second-load-requested")
        do {
            let film = try await owner.start(camera: configuration.camera, title: "Unexpected second load",
                orientation: configuration.camera.medium == .movie ? .portrait : nil)
            evidence.record("second-load-created", ["filmID": film.id.uuidString])
        } catch { evidence.record("second-load-error", ["error": String(describing: error)]); throw error }
    }

    func inventory() async throws -> ScenarioInventory {
        if saving || deleting {
            guard await gate.phase.hasPrefix("paused-") else { throw HarnessError.busy }
        }
        let repository = try FilmRepository(rootURL: root)
        let films = try repository.allFilms()
        let raw = calls.observeUnderlying()
        let actual = raw.data.flatMap { try? JSONDecoder().decode(DeviceTrialRecord.self, from: $0) }
        let logical: String
        do { logical = try store.read().map { $0.isConsumed ? "consumed" : "unused" } ?? "absent" }
        catch { logical = String(describing: error) }
        var receipt: CaptureCommitReceipt?
        var pending = false
        var matches: Bool?
        var frames: Int?
        if let id = manifest.filmID, films.contains(where: { $0.id == id }) {
            pending = try repository.hasPendingCapture(filmID: id)
            if let source = manifest.sourcePath { receipt = try repository.captureReceipt(filmID: id, captureID: URL(fileURLWithPath: source).lastPathComponent) }
            if let asset = try repository.mediaAsset(filmID: id, sequenceNumber: 1, kind: .source) {
                let verified = configuration.camera.medium == .photo ? try VerifiedMedia.photo(at: asset.url) : try await VerifiedMedia.movie(at: asset.url)
                matches = verified.sha256 == asset.record.sha256 && verified.sha256 == manifest.sourceHash
                frames = verified.decodedFrameCount
            }
        }
        let files = try fileInventory()
        let staging = manifest.filmID.map { FileManager.default.fileExists(atPath: root.appendingPathComponent("Staging/\($0)").path) } ?? false
        let result = ScenarioInventory(configuration: configuration, manifest: manifest, films: films, sqlReceipt: receipt,
            outboxFilmIDs: try repository.pendingTrialConsumptions().map(\.filmID), pending: pending,
            underlyingStatus: raw.status, underlyingRecord: actual, logicalRead: logical, sourceMatches: matches,
            decodedFrames: frames, stagingExists: staging, files: files)
        let filename = "inventory-\(UUID().uuidString).json"
        try ScenarioEvidence.persist(result, to: evidence.directory.appendingPathComponent(filename))
        evidence.record("inventory", ["file": filename, "summary": result.summary])
        return result
    }

    private func persistManifest() throws { try ScenarioEvidence.persist(manifest, to: configuration.directory.appendingPathComponent("scenario.json")) }
    private func fileInventory() throws -> [String: String] {
        var result: [String: String] = [:]
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[String(url.path.dropFirst(root.path.count + 1))] = ScenarioEvidence.hash(try Data(contentsOf: url))
            }
        }
        return result
    }
    private func event() throws -> CaptureSaveEvent {
        guard manifest.prepared, let path = manifest.sourcePath else { throw HarnessError.missingPreparation }
        let source = root.appendingPathComponent(path)
        if configuration.camera.medium == .photo { return .photoSaved(source) }
        guard let duration = manifest.duration else { throw HarnessError.missingPreparation }
        return .movieClipSaved(url: source, durationSeconds: duration, orientation: .landscape)
    }
}
