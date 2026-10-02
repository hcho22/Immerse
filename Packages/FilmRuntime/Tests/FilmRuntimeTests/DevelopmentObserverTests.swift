import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import RenderFixtures
import XCTest

private enum ObservationFailure: Error { case injected, timeout, invalidRelease }

private actor DevelopmentGate {
    private let target: DevelopmentStage?
    private let throwsImmediately: Bool
    private var armed = true
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var visits: [DevelopmentStage] = []
    private(set) var films: Set<UUID> = []
    private(set) var cancellations = 0
    var paused: Bool { continuation != nil }

    init(_ target: DevelopmentStage? = nil, throwsImmediately: Bool = false) {
        self.target = target; self.throwsImmediately = throwsImmediately
    }
    func observe(_ film: UUID, _ stage: DevelopmentStage) async throws {
        visits.append(stage); films.insert(film)
        guard armed, stage == target else { return }
        armed = false
        if throwsImmediately { throw ObservationFailure.injected }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation = $0 }
        } onCancel: {
            Task { await self.cancelled() }
        }
        // Deliberately returns normally even when cancelled: the production owner
        // must check cancellation after suspension before its next side effect.
    }
    private func cancelled() { cancellations += 1 }
    func release() throws {
        guard let continuation else { throw ObservationFailure.invalidRelease }
        self.continuation = nil; continuation.resume()
    }
    func clearVisits() { visits = [] }
}

@MainActor final class DevelopmentObserverTests: XCTestCase {
    func testEnabledPauseReleaseCompletesWithoutExtraRendering() async throws {
        for stage in stages(.disposable1990s) {
            let fixture = try await Fixture(camera: .disposable1990s, label: "release-\(stage)", declineOriginals: true)
            let gate = DevelopmentGate(stage)
            let owner = try processor(fixture, gate)
            let job = Task { try await owner.develop(filmID: fixture.film.id) }
            try await wait { await gate.paused }
            let held = try await fixture.snapshot("held-for-release")
            assertBoundary(held, at: stage)
            try await gate.release()
            try await job.value
            let completed = try await fixture.snapshot("released-completed")
            assertPreserved(held, completed)
            let visits = await gate.visits
            XCTAssertEqual(visits.filter { $0 == .afterRendering(sequence: 1) }.count, 1)
            XCTAssertEqual(visits.filter { $0 == .afterPersistence(sequence: 1) }.count, 1)
            try await fixture.assertFinished(sources: 0)
        }
    }

    func testDefaultAndEnabledCompletionAllCameras() async throws {
        for camera in CameraID.allCases {
            let fixture = try await Fixture(camera: camera, label: "default-and-enabled")
            try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
            let baseline = try await fixture.snapshot("default-completed")
            XCTAssertTrue(baseline.film.captures.allSatisfy { $0.revealState == .revealed })
            let gate = DevelopmentGate()
            try await processor(fixture, gate).develop(filmID: fixture.film.id)
            let observed = try await fixture.snapshot("observed-completed")
            XCTAssertEqual(observed.film, baseline.film)
            XCTAssertEqual(observed.run, baseline.run)
            XCTAssertEqual(observed.retainedHashes, baseline.retainedHashes)
            let visits = await gate.visits
            XCTAssertTrue(visits.contains(.beforeBegin))
            XCTAssertTrue(visits.contains(.afterAssignments))
            XCTAssertFalse(visits.contains(.afterRendering(sequence: 1)))
            XCTAssertFalse(visits.contains(.afterPersistence(sequence: 1)))
            XCTAssertTrue(visits.contains(.beforeRevealOrCleanup(.sourceCleanup)))
            let films = await gate.films
            XCTAssertEqual(films, [fixture.film.id])
            try await fixture.assertFinished(sources: 1)
        }
    }

    func testThrowAtEveryBoundaryPreservesRecoveryAndRetiresJob() async throws {
        for camera in [CameraID.disposable1990s, .instant1970s, .cinema16mm] {
            for stage in stages(camera) {
                let fixture = try await Fixture(camera: camera, label: "throw-\(stage)", declineOriginals: true)
                let gate = DevelopmentGate(stage, throwsImmediately: true)
                let owner = try processor(fixture, gate)
                do { try await owner.develop(filmID: fixture.film.id); XCTFail("Observer throw reported success") }
                catch ObservationFailure.injected { }
                let failed = try await fixture.snapshot("observer-threw")
                assertBoundary(failed, at: stage)
                XCTAssertTrue(failed.workFiles.isEmpty)
                await gate.clearVisits()
                // Same owner: a retained failed job would replay its error here.
                try await owner.develop(filmID: fixture.film.id)
                let resumed = try await fixture.snapshot("same-owner-retry")
                assertPreserved(failed, resumed)
                if failed.retainedHashes.keys.contains("\(fixture.kind.rawValue)-1") {
                    let visits = await gate.visits
                    XCTAssertFalse(visits.contains(.afterRendering(sequence: 1)))
                }
                try await fixture.assertFinished(sources: 0)
            }
        }
    }

    func testCancellationAfterPauseCannotPerformNextSideEffectAndCanReenterWithoutObserver() async throws {
        let cases = stages(.disposable1990s).map { (CameraID.disposable1990s, $0) }
            + [(.cinema16mm, .afterRendering(sequence: 1)), (.cinema16mm, .afterPersistence(sequence: 1)),
               (.instant1970s, .beforeRevealOrCleanup(.instantReveal(sequence: 1))),
               (.instant1970s, .beforeRevealOrCleanup(.sourceCleanup))]
        for (camera, stage) in cases {
            let fixture = try await Fixture(camera: camera, label: "cancel-\(stage)", declineOriginals: true)
            let gate = DevelopmentGate(stage)
            let owner = try processor(fixture, gate)
            let job = Task { try await owner.develop(filmID: fixture.film.id) }
            try await wait { await gate.paused }
            let held = try await fixture.snapshot("held")
            assertBoundary(held, at: stage)
            var suspensionReturned = false
            let suspension = Task { await owner.suspendProcessing(); suspensionReturned = true }
            try await wait { await gate.cancellations == 1 }
            XCTAssertFalse(suspensionReturned)
            try await gate.release()
            do { try await job.value; XCTFail("Cancelled observer continuation reported success") }
            catch is CancellationError { }
            await suspension.value
            let cancelled = try await fixture.snapshot("cancelled")
            XCTAssertEqual(cancelled.film, held.film)
            XCTAssertEqual(cancelled.run, held.run)
            XCTAssertEqual(cancelled.assets, held.assets)
            XCTAssertTrue(cancelled.workFiles.isEmpty)
            try fixture.repository.recover()
            try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
            let reopened = try await fixture.snapshot("observer-absent-reentry")
            assertPreserved(cancelled, reopened)
            try await fixture.assertFinished(sources: 0)
        }
    }

    func testDeleteWaitsAtEveryPhotoBoundaryAndPreventsRecreation() async throws {
        let cases = stages(.disposable1990s).map { (CameraID.disposable1990s, $0) }
            + [(.cinema16mm, .afterPersistence(sequence: 1)),
               (.instant1970s, .beforeRevealOrCleanup(.instantReveal(sequence: 1)))]
        for (camera, stage) in cases {
            let fixture = try await Fixture(camera: camera, label: "delete-\(stage)")
            let gate = DevelopmentGate(stage)
            let owner = try processor(fixture, gate)
            let job = Task { try await owner.develop(filmID: fixture.film.id) }
            try await wait { await gate.paused }
            _ = try await fixture.snapshot("before-delete")
            var deletionReturned = false
            let deletion = Task { try await owner.deleteFilm(filmID: fixture.film.id); deletionReturned = true }
            try await wait { await gate.cancellations == 1 }
            XCTAssertFalse(deletionReturned)
            XCTAssertEqual(try fixture.repository.allFilms().count, 1)
            try await gate.release()
            do { try await job.value; XCTFail("Cancelled Development returned success") }
            catch is CancellationError { }
            try await deletion.value
            try fixture.repository.recover()
            XCTAssertTrue(try fixture.repository.allFilms().isEmpty)
            for prefix in ["Media", "Staging", "Work"] {
                XCTAssertTrue(try fixture.files(under: prefix).isEmpty)
            }
            do { try await owner.develop(filmID: fixture.film.id); XCTFail("Deleted Film developed") }
            catch PersistenceError.filmNotFound { }
            try fixture.record("deleted", ["privateFilms": 0, "privateMediaFiles": 0])
        }
    }

    func testInstantDiscardCancelsPendingRevealWithoutRefundOrReroll() async throws {
        let fixture = try await Fixture(camera: .instant1970s, label: "instant-discard")
        try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
        try fixture.repository.savePhotoCapture(filmID: fixture.film.id, sourceData: fixture.photo)
        let gate = DevelopmentGate(.beforeRevealOrCleanup(.instantReveal(sequence: 2)))
        let owner = try processor(fixture, gate)
        let job = Task { try await owner.develop(filmID: fixture.film.id) }
        try await wait { await gate.paused }
        let held = try await fixture.snapshot("instant-second-held")
        XCTAssertEqual(held.film.captures.map(\.revealState), [.revealed, .sealed])
        let removal = Task { try await owner.discard(filmID: fixture.film.id, sequence: 1) }
        try await wait { await gate.cancellations == 1 }
        try await gate.release()
        do { try await job.value; XCTFail("Pending print revealed during Discard") }
        catch is CancellationError { }
        try await removal.value
        try fixture.repository.recover()
        let removed = try await fixture.snapshot("instant-discarded")
        XCTAssertEqual(removed.film.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertEqual(removed.film.captures.last?.revealState, .sealed)
        XCTAssertFalse(removed.assets.keys.contains { $0.hasSuffix("-1") })
        try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
        let resumed = try await fixture.snapshot("instant-second-revealed")
        XCTAssertEqual(resumed.film.remainingExposures, 8)
        XCTAssertEqual(resumed.film.captures.last?.revealState, .revealed)
        XCTAssertEqual(resumed.assets["master-2"], held.assets["master-2"])
        XCTAssertEqual(resumed.run?.assignments, held.run?.assignments)
    }

    func testMovieReassemblyThrowRetiresStaleMovieAndReleasesRemovalGuard() async throws {
        let fixture = try await Fixture(camera: .cinema16mm, label: "movie-reassembly", count: 2)
        try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
        let initial = try await fixture.snapshot("movie-before-discard")
        let old = try fixture.repository.revealedAsset(filmID: fixture.film.id, sequenceNumber: 0, kind: .movie)
        let gate = DevelopmentGate(.afterAssignments, throwsImmediately: true)
        let owner = try processor(fixture, gate)
        do { try await owner.discard(filmID: fixture.film.id, sequence: 1); XCTFail("Reassembly observer throw reported success") }
        catch ObservationFailure.injected { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.url.path))
        try fixture.repository.recover()
        let failed = try await fixture.snapshot("movie-reassembly-failed")
        XCTAssertEqual(failed.film.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertNil(failed.assets["movie-0"])
        XCTAssertEqual(failed.assets["clip-2"], initial.assets["clip-2"])
        try await owner.develop(filmID: fixture.film.id)
        let resumed = try await fixture.snapshot("movie-reassembled")
        XCTAssertEqual(resumed.assets["clip-2"], initial.assets["clip-2"])
        XCTAssertEqual(resumed.run?.assignments, initial.run?.assignments)
        XCTAssertEqual(resumed.film.consumedMovieSeconds, initial.film.consumedMovieSeconds)
        let movie = try fixture.repository.revealedAsset(filmID: fixture.film.id, sequenceNumber: 0, kind: .movie)
        let verification = try await VerifiedMedia.movie(at: movie.url)
        XCTAssertEqual(try XCTUnwrap(verification.durationSeconds), fixture.duration, accuracy: 0.01)
    }

    private func stages(_ camera: CameraID) -> [DevelopmentStage] {
        [.beforeBegin, .afterAssignments, .afterRendering(sequence: 1), .afterPersistence(sequence: 1),
         .beforeRevealOrCleanup(camera == .instant1970s ? .instantReveal(sequence: 1) : .filmReveal),
         .beforeRevealOrCleanup(.sourceCleanup)]
    }
    private func processor(_ fixture: Fixture, _ gate: DevelopmentGate) throws -> FilmProcessor {
        try FilmProcessor(root: fixture.root, developmentObserver: { try await gate.observe($0, $1) })
    }
    private func wait(_ predicate: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(20)
        while !(await predicate()) {
            guard Date() < deadline else { throw ObservationFailure.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    private func assertBoundary(_ state: State, at stage: DevelopmentStage, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(state.assets["source-1"], file: file, line: line)
        if stage == .beforeBegin { XCTAssertNil(state.run, file: file, line: line) }
        else { XCTAssertNotNil(state.run?.assignments[1], file: file, line: line) }
        let hasPersisted = [.afterPersistence(sequence: 1), .beforeRevealOrCleanup(.filmReveal),
                            .beforeRevealOrCleanup(.instantReveal(sequence: 1)), .beforeRevealOrCleanup(.sourceCleanup)].contains(stage)
        XCTAssertEqual(state.retainedHashes.count, hasPersisted ? 1 : 0, file: file, line: line)
        XCTAssertEqual(state.film.captures.first?.revealState,
                       stage == .beforeRevealOrCleanup(.sourceCleanup) ? .revealed : .sealed, file: file, line: line)
    }
    private func assertPreserved(_ earlier: State, _ later: State, file: StaticString = #filePath, line: UInt = #line) {
        if let run = earlier.run {
            XCTAssertEqual(later.run?.filmID, run.filmID, file: file, line: line)
            XCTAssertEqual(later.run?.treatmentVersion, run.treatmentVersion, file: file, line: line)
            XCTAssertEqual(later.run?.printProcess, run.printProcess, file: file, line: line)
            XCTAssertEqual(later.run?.assignments, run.assignments, file: file, line: line)
        }
        for (key, hash) in earlier.retainedHashes { XCTAssertEqual(later.retainedHashes[key], hash, file: file, line: line) }
        XCTAssertEqual(later.film.captures.map(\.id), earlier.film.captures.map(\.id), file: file, line: line)
        XCTAssertEqual(later.film.consumedMovieSeconds, earlier.film.consumedMovieSeconds, file: file, line: line)
        XCTAssertEqual(later.film.movieOrientation, earlier.film.movieOrientation, file: file, line: line)
    }

    private struct State: Codable {
        let film: Film
        let run: DevelopmentRun?
        let assets: [String: String]
        let workFiles: [String]
        var retainedHashes: [String: String] { assets.filter { $0.key.hasPrefix("master-") || $0.key.hasPrefix("clip-") } }
    }

    @MainActor private struct Fixture {
        let directory: URL
        let root: URL
        let repository: FilmRepository
        let film: Film
        let photo: Data
        let duration: Double
        var kind: StoredAsset.Kind { film.camera.medium == .photo ? .master : .clip }

        init(camera: CameraID, label: String, count: Int = 1, declineOriginals: Bool = false) async throws {
            #if os(iOS)
            let parent = URL.documentsDirectory
            #else
            let parent = FileManager.default.temporaryDirectory
            #endif
            directory = parent.appendingPathComponent("DevelopmentScenarios/\(UUID())")
            root = directory.appendingPathComponent("App")
            var settings = RenderFixtureSettings.defaultExperimental
            settings.photoWidth = 160; settings.photoHeight = 120
            settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
            let fixtures = directory.appendingPathComponent("Fixtures")
            let generated = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
            duration = generated.movie.durationSeconds
            photo = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
            repository = try FilmRepository(rootURL: root)
            let package = CameraCatalog.package(for: camera)
            film = try repository.createFilm(camera: package, title: "Synthetic Development boundary",
                movieOrientation: package.medium == .movie ? .portrait : nil, access: .subscription)
            for sequence in 1...count {
                let date = Date(timeIntervalSince1970: 1_790_880_000 + Double(sequence))
                if package.medium == .photo { try repository.savePhotoCapture(filmID: film.id, sourceData: photo, savedAt: date) }
                else {
                    try repository.saveMovieClip(filmID: film.id,
                        sourceData: Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov")),
                        durationSeconds: duration, orientation: .landscape, savedAt: date)
                }
            }
            if package.revealRule != .instantPerExposure { try repository.completeEarly(filmID: film.id) }
            if declineOriginals {
                for sequence in 1...count { try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: sequence, export: false) }
            }
            try record("scenario", ["label": label, "camera": camera.rawValue, "film": film.id.uuidString,
                "createdUTC": ISO8601DateFormatter().string(from: Date()), "backend": "native-synthetic-no-external-services"])
            print("DEVELOPMENT_SCENARIO \(directory.path)")
        }
        func snapshot(_ label: String) async throws -> State {
            let current = try repository.film(id: film.id)
            var hashes: [String: String] = [:]
            for sequence in 0...current.captures.count {
                for kind in [StoredAsset.Kind.source, .master, .clip, .movie] {
                    guard let asset = try repository.mediaAsset(filmID: film.id, sequenceNumber: sequence, kind: kind) else { continue }
                    let verified = film.camera.medium == .photo ? try VerifiedMedia.photo(at: asset.url)
                        : try await VerifiedMedia.movie(at: asset.url)
                    XCTAssertEqual(verified.sha256, asset.record.sha256)
                    XCTAssertGreaterThan(verified.decodedFrameCount, 0)
                    hashes["\(kind.rawValue)-\(sequence)"] = verified.sha256
                }
            }
            let state = State(film: current, run: try repository.developmentRun(filmID: film.id), assets: hashes,
                              workFiles: try files(under: "Work"))
            try record(label, state)
            return state
        }
        func assertFinished(sources: Int) async throws {
            let state = try await snapshot("finished")
            XCTAssertTrue(state.film.captures.filter { !$0.isDiscarded }.allSatisfy { $0.revealState == .revealed })
            XCTAssertEqual(state.assets.keys.filter { $0.hasPrefix("source-") }.count, sources)
            XCTAssertTrue(state.workFiles.isEmpty)
        }
        func files(under prefix: String) throws -> [String] {
            guard let items = FileManager.default.enumerator(at: root.appendingPathComponent(prefix), includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
            return try items.compactMap { value in
                guard let url = value as? URL, try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { return nil }
                return String(url.path.dropFirst(root.path.count + 1))
            }.sorted()
        }
        func record<T: Encodable>(_ label: String, _ value: T) throws {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: directory.appendingPathComponent("\(label).json"), options: .withoutOverwriting)
        }
    }
}
