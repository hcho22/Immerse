import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderFixtures
import Synchronization
import XCTest

final class TrialIntegrationTests: XCTestCase {
    func testRestoredPendingPhotoAndMovieReplayOnceWithoutConsumingDestinationTrial() async throws {
        for camera in [CameraCatalog.disposable1990s, CameraCatalog.super8HomeMovie] {
            let root = makeRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let sourceRoot = root.appendingPathComponent("Source")
            let sourceStore = MemoryDeviceStore()
            let prepared = try await prepareRestorableCapture(root: sourceRoot, camera: camera, store: sourceStore)
            // Only the injected source-device receipt differs. Restorable files
            // remain identical, as in the receipt-authority study's two histories.
            for sourceReceiptCommitted in [false, true] {
                if sourceReceiptCommitted { try sourceStore.consume(filmID: prepared.film.id, savedAt: prepared.date) }
                let destinationRoot = root.appendingPathComponent("Destination-\(sourceReceiptCommitted)")
                try FileManager.default.copyItem(at: sourceRoot, to: destinationRoot)
                let destination = MemoryDeviceStore()
                let coordinator = try TrialCoordinator(root: destinationRoot, store: destination)
                let own = try await coordinator.start(camera: CameraCatalog.instant1970s, title: "Destination's own Trial")
                let repository = try FilmRepository(rootURL: destinationRoot)
                let staging = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: prepared.film.id))
                let events = try await staging.recoveryEvents()
                XCTAssertEqual(events.count, 1)
                let event = try XCTUnwrap(events.first)
                let receiver = try await coordinator.receiver(filmID: prepared.film.id)
                try await receiver.commit(event)
                try await receiver.commit(event)
                try staging.removeCommittedFile(for: event)
                let restored = try repository.film(id: prepared.film.id)
                XCTAssertEqual(restored.savedCaptureCount, 1)
                XCTAssertEqual(restored.captures.first?.savedAt, prepared.date)
                XCTAssertEqual(restored.captures.first?.sequenceNumber, 1)
                XCTAssertEqual(restored.captures.first?.revealState, .sealed)
                if camera.medium == .photo { XCTAssertEqual(restored.remainingExposures, 26) }
                else {
                    XCTAssertEqual(restored.consumedMovieSeconds, prepared.duration, accuracy: 0.000001)
                    XCTAssertEqual(restored.movieOrientation, .portrait)
                    XCTAssertEqual(restored.captures.first?.kind, .movieClip(seconds: prepared.duration, orientation: .landscape))
                }
                XCTAssertTrue(try staging.pendingRecords().isEmpty)
                XCTAssertFalse(try XCTUnwrap(destination.read()).isConsumed)
                let state = try await coordinator.state()
                XCTAssertEqual(state, .emptyFilmInProgress(filmID: own.id))
                let source = try XCTUnwrap(repository.mediaAsset(filmID: prepared.film.id, sequenceNumber: 1, kind: .source))
                if camera.medium == .photo { _ = try VerifiedMedia.photo(at: source.url) }
                else { _ = try await VerifiedMedia.movie(at: source.url) }
                try repository.deleteFilm(filmID: prepared.film.id)
                XCTAssertFalse(FileManager.default.fileExists(atPath: source.url.path))
                XCTAssertFalse(FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("Staging/\(prepared.film.id)").path))
            }
        }
    }

    private func prepareRestorableCapture(root: URL, camera: CameraPackage, store: MemoryDeviceStore) async throws
        -> (film: Film, date: Date, duration: Double) {
        let fixtures = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let repository = try FilmRepository(rootURL: root)
        let device = try store.ensureDeviceRecord()
        let film = try repository.createFilm(camera: camera, title: "Restored pending operation",
            movieOrientation: camera.medium == .movie ? .portrait : nil, access: .trial(originDevice: device.deviceID))
        let date = Date(timeIntervalSince1970: 1_790_870_000)
        let id = UUID()
        let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: camera.medium == .photo ? .photo : .movie,
            createdAt: date, orientation: camera.medium == .movie ? .landscape : nil,
            remainingSeconds: camera.medium == .movie ? film.remainingMovieSeconds : nil))
        if camera.medium == .photo {
            _ = try files.savePhoto(Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg")), id: id)
        } else {
            try FileManager.default.copyItem(at: fixtures.appendingPathComponent("synthetic-developed-movie.mov"), to: files.movieDestination(id: id))
        }
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        return (film, date, manifest.movie.durationSeconds)
    }

    // These are counterexamples, not acceptance passes. The device store survives
    // perfectly; removing only our private app directory models loss of the outbox.
    func testDocumentedUninstallGapReopensTrialAfterCommittedFirstCapture() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let firstID = try await commitBeforeKeychainFailure(root: root, store: store)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        try FileManager.default.removeItem(at: root)
        store.failConsumption = false

        let reinstalled = try TrialCoordinator(root: root, store: store)
        let observed = try await reinstalled.state()
        XCTAssertEqual(observed, .unused, "Known TRI-04 violation: committed save must keep eligibility consumed")
        let second = try await reinstalled.start(camera: CameraCatalog.disposable1990s, title: "Counterexample replacement")
        XCTAssertNotEqual(second.id, firstID)
    }

    func testUninstallAfterPrecommitFailureCorrectlyKeepsTrialUnused() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        try await failBeforeCaptureCommit(root: root, store: store)
        try FileManager.default.removeItem(at: root)
        let reinstalled = try TrialCoordinator(root: root, store: store)
        let observed = try await reinstalled.state()
        XCTAssertEqual(observed, .unused)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
    }

    private func commitBeforeKeychainFailure(root: URL, store: MemoryDeviceStore) async throws -> UUID {
        let fixtures = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        let source = fixtures.appendingPathComponent("synthetic-developed-photo.jpg")
        _ = try VerifiedMedia.photo(at: source)
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Counterexample first Film")
        let receiver = try await coordinator.receiver(filmID: film.id)
        store.failConsumption = true
        do { try await receiver.commit(.photoSaved(source)); XCTFail("Expected injected Keychain failure") }
        catch { XCTAssertEqual((error as? CocoaError)?.code, .fileWriteNoPermission) }
        let reopened = try FilmRepository(rootURL: root)
        XCTAssertEqual(try reopened.film(id: film.id).savedCaptureCount, 1)
        XCTAssertEqual(try reopened.pendingTrialConsumptions().count, 1)
        let retained = try XCTUnwrap(reopened.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertEqual(try VerifiedMedia.photo(at: retained.url).sha256, retained.record.sha256)
        return film.id
    }

    private func failBeforeCaptureCommit(root: URL, store: MemoryDeviceStore) async throws {
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Failed synthetic save")
        let repository = try FilmRepository(rootURL: root)
        XCTAssertThrowsError(try repository.savePhotoCapture(filmID: film.id, sourceData: Data("incomplete".utf8),
            failureInjection: .afterDurableMoveBeforeDebit))
        try repository.recover()
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
        XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
        try await coordinator.reconcile()
    }

    func testCrashWindowRetryConsumesOnlyOnceAndPrecommitFailureDoesNotConsume() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        let repository = try FilmRepository(rootURL: root)
        XCTAssertThrowsError(try repository.savePhotoCapture(filmID: film.id, sourceData: Data("incomplete".utf8),
            failureInjection: .afterDurableMoveBeforeDebit))
        try repository.recover()
        try await coordinator.reconcile()
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
        let source = root.appendingPathComponent("retry.photo")
        try Data("native validated bytes".utf8).write(to: source)
        let receiver = try await coordinator.receiver(filmID: film.id)
        store.failConsumption = true
        do { try await receiver.commit(.photoSaved(source)); XCTFail("Expected Keychain failure") }
        catch { }
        store.failConsumption = false
        let relaunched = try TrialCoordinator(root: root, store: store)
        let retry = try await relaunched.receiver(filmID: film.id)
        try await retry.commit(.photoSaved(source))
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
        XCTAssertEqual(try repository.film(id: film.id).remainingExposures, 26)
        XCTAssertEqual(try store.read()?.consumedFilmID, film.id)
        XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
    }

    func testFirstSaveOutboxSurvivesKeychainFailureAndFilmDeletionWithoutGrantingAnotherTrial() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        let state = try await coordinator.state()
        XCTAssertEqual(state, .emptyFilmInProgress(filmID: film.id))
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        let source = root.appendingPathComponent("native-capture.photo")
        try Data("already-native-validated".utf8).write(to: source)
        let receiver = try await coordinator.receiver(filmID: film.id)
        store.failConsumption = true
        do { try await receiver.commit(.photoSaved(source)); XCTFail("Keychain failure must retain pending save acknowledgement") }
        catch { }
        let repository = try FilmRepository(rootURL: root)
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
        XCTAssertEqual(try repository.pendingTrialConsumptions().count, 1)
        do { _ = try await coordinator.start(camera: CameraCatalog.instant1970s, title: "No second Trial"); XCTFail("Must fail closed") }
        catch { }
        try repository.deleteFilm(filmID: film.id)
        XCTAssertEqual(try repository.pendingTrialConsumptions().count, 1)
        store.failConsumption = false
        let reopened = try TrialCoordinator(root: root, store: store)
        try await reopened.reconcile()
        XCTAssertTrue(try XCTUnwrap(store.read()).isConsumed)
        XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
        do { _ = try await reopened.start(camera: CameraCatalog.instant1970s, title: "Still consumed"); XCTFail("Used Trial cannot reset") }
        catch EntitlementDenial.currentDeviceTrialConsumed { }
    }

    func testFailedUnsavedCaptureAndZeroSaveDeletionAllowReplacement() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        let receiver = try await coordinator.receiver(filmID: film.id)
        try await receiver.commit(.saveFailed("no saved bytes"))
        let repository = try FilmRepository(rootURL: root)
        XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
        try repository.deleteFilm(filmID: film.id)
        let next = try await coordinator.start(camera: CameraCatalog.cinema16mm, title: "Replacement", orientation: .landscape)
        XCTAssertNotEqual(next.id, film.id)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
    }

    func testRestoredEmptyAndCapturedTrialFilmsCoexistWithDestinationEntitlement() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let captured = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Restored captured", access: .trial(originDevice: UUID()))
        try repository.savePhotoCapture(filmID: captured.id, sourceData: Data("saved before restore".utf8))
        let empty = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Restored empty", access: .trial(originDevice: UUID()))
        let destination = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: destination)
        let own = try await coordinator.start(camera: CameraCatalog.mediumFormat6x6, title: "Destination Trial")
        for film in [captured, empty] {
            let receiver = try await coordinator.receiver(filmID: film.id)
            let source = root.appendingPathComponent("\(film.id).photo")
            try Data("new native capture".utf8).write(to: source)
            try await receiver.commit(.photoSaved(source))
        }
        XCTAssertFalse(try XCTUnwrap(destination.read()).isConsumed)
        XCTAssertEqual(try repository.film(id: captured.id).savedCaptureCount, 2)
        XCTAssertEqual(try repository.film(id: empty.id).savedCaptureCount, 1)
        let ownSource = root.appendingPathComponent("own.photo")
        try Data("own native capture".utf8).write(to: ownSource)
        let ownReceiver = try await coordinator.receiver(filmID: own.id)
        try await ownReceiver.commit(.photoSaved(ownSource))
        XCTAssertEqual(try destination.read()?.consumedFilmID, own.id)
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TrialIntegrationTests-\(UUID())")
    }
}

private final class MemoryDeviceStore: DeviceTrialStoring, Sendable {
    private struct State { var record: DeviceTrialRecord?; var fails = false }
    private let state = Mutex(State())
    var failConsumption: Bool {
        get { state.withLock { $0.fails } }
        set { state.withLock { $0.fails = newValue } }
    }
    func read() throws -> DeviceTrialRecord? { state.withLock { $0.record } }
    func ensureDeviceRecord() throws -> DeviceTrialRecord {
        state.withLock { state in
            if let record = state.record { return record }
            let record = DeviceTrialRecord(); state.record = record; return record
        }
    }
    func consume(filmID: UUID, savedAt: Date) throws {
        try state.withLock { state in
            if state.fails { throw CocoaError(.fileWriteNoPermission) }
            let current = state.record ?? DeviceTrialRecord()
            if !current.isConsumed {
                state.record = DeviceTrialRecord(deviceID: current.deviceID, consumedFilmID: filmID, consumedAt: savedAt)
            }
        }
    }
}
