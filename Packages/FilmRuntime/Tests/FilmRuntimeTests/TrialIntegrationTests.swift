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
                    XCTAssertEqual(restored.consumedMovieFrames, MovieFrames.count(seconds: prepared.duration))
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
            movieOrientation: camera.medium == .movie ? .portrait : nil, filmStock: camera.defaultFilmStock, access: .trial(originDevice: device.deviceID))
        let date = Date(timeIntervalSince1970: 1_790_870_000)
        let id = UUID()
        let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: camera.medium == .photo ? .photo : .movie,
            createdAt: date, orientation: camera.medium == .movie ? .landscape : nil,
            remainingFrames: camera.medium == .movie ? film.remainingMovieFrames : nil))
        if camera.medium == .photo {
            _ = try files.savePhoto(Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg")), id: id)
        } else {
            try FileManager.default.copyItem(at: fixtures.appendingPathComponent("synthetic-developed-movie.mov"), to: files.movieDestination(id: id))
        }
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        return (film, date, manifest.movie.durationSeconds)
    }

    // The former D3 counterexample and its passing failure-observation log remain
    // in the d233bb7 evidence checkpoint. These assertions exercise the correction.
    func testUnresolvedReceiptDoesNotCommitCapacityBeforeAppStorageLoss() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let firstID = try await prepareBeforeKeychainFailure(root: root, store: store)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        try FileManager.default.removeItem(at: root)
        store.failConsumption = false

        let reinstalled = try TrialCoordinator(root: root, store: store)
        let observed = try await reinstalled.state()
        XCTAssertEqual(observed, .unused, "No capture or receipt committed before storage loss")
        let second = try await reinstalled.start(camera: CameraCatalog.disposable1990s, title: "Replacement")
        XCTAssertNotEqual(second.id, firstID)
    }

    func testReceiptBeforeProjectionSurvivesAppStorageLossWithoutReopeningTrial() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let source = try await photo(root)
        let coordinator = try TrialCoordinator(root: root, store: store, projectionFailure: .afterDurableMoveBeforeDebit)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Receipt committed")
        let receiver = try await coordinator.receiver(filmID: film.id)
        do { try await receiver.commit(.photoSaved(source)); XCTFail("Expected projection fault") }
        catch { XCTAssertEqual(error as? PersistenceError, .simulatedFailure(.afterDurableMoveBeforeDebit)) }
        let repository = try FilmRepository(rootURL: root)
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
        XCTAssertEqual(try XCTUnwrap(store.read()).consumedCaptureID, source.lastPathComponent)
        try FileManager.default.removeItem(at: root)
        let reinstalled = try TrialCoordinator(root: root, store: store)
        guard case .consumed = try await reinstalled.state() else { return XCTFail("Receipt must survive app storage loss") }
        do { _ = try await reinstalled.start(camera: CameraCatalog.instant1970s, title: "Cannot reset"); XCTFail("Second Trial") }
        catch EntitlementDenial.currentDeviceTrialConsumed { }
    }

    func testPendingSaveThatCannotBeInspectedBlocksReconcileUntilReadable() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let filmID = try await prepareBeforeKeychainFailure(root: root, store: store)
        store.failConsumption = false
        // The verified pending save still exists; its Film staging directory denies search.
        let staging = root.appendingPathComponent("Staging/\(filmID)")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: staging.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staging.path) }

        let relaunched = try TrialCoordinator(root: root, store: store)
        do { try await relaunched.reconcile(filmID: filmID); XCTFail("An uninspectable pending save is not an empty journal") }
        catch { XCTAssertEqual((error as? CocoaError)?.code, .fileReadNoPermission) }
        let repository = try FilmRepository(rootURL: root)
        XCTAssertEqual(try repository.film(id: filmID).savedCaptureCount, 0)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staging.path)
        try await relaunched.reconcile(filmID: filmID)
        XCTAssertEqual(try repository.film(id: filmID).savedCaptureCount, 1)
        XCTAssertEqual(try store.read()?.consumedFilmID, filmID)
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

    private func prepareBeforeKeychainFailure(root: URL, store: MemoryDeviceStore) async throws -> UUID {
        let source = try await photo(root)
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Pending first Film")
        let receiver = try await coordinator.receiver(filmID: film.id)
        store.failConsumption = true
        do { try await receiver.commit(.photoSaved(source)); XCTFail("Expected injected Keychain failure") }
        catch { XCTAssertEqual((error as? CocoaError)?.code, .fileWriteNoPermission) }
        let reopened = try FilmRepository(rootURL: root)
        XCTAssertEqual(try reopened.film(id: film.id).savedCaptureCount, 0)
        XCTAssertEqual(try reopened.film(id: film.id).remainingExposures, 27)
        XCTAssertTrue(try reopened.pendingTrialConsumptions().isEmpty)
        XCTAssertNil(try reopened.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        let pending = root.appendingPathComponent("Staging/\(film.id)/Commit/\(source.lastPathComponent)")
        XCTAssertEqual(try VerifiedMedia.photo(at: pending).sha256, try VerifiedMedia.photo(at: source).sha256)
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
        let source = try await photo(root)
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

    func testLegacyCommittedOutboxSurvivesKeychainFailureAndDeletionWithoutRefund() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        let state = try await coordinator.state()
        XCTAssertEqual(state, .emptyFilmInProgress(filmID: film.id))
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        let source = try await photo(root)
        let repository = try FilmRepository(rootURL: root)
        // A D3 database committed before upgrade must not lose its obligation.
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data(contentsOf: source))
        store.failConsumption = true
        do { try await coordinator.reconcile(); XCTFail("Legacy outbox must remain on unresolved write") }
        catch { }
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
        XCTAssertEqual(try repository.pendingTrialConsumptions().count, 1)
        do { _ = try await coordinator.start(camera: CameraCatalog.instant1970s, title: "No second Trial"); XCTFail("Must fail closed") }
        catch { }
        try await coordinator.deleteFilm(filmID: film.id)
        XCTAssertEqual(try repository.pendingTrialConsumptions().count, 1)
        store.failConsumption = false
        let reopened = try TrialCoordinator(root: root, store: store)
        try await reopened.reconcile()
        XCTAssertTrue(try XCTUnwrap(store.read()).isConsumed)
        XCTAssertNil(try XCTUnwrap(store.read()).consumedCaptureID, "Legacy consumption has no invented capture receipt")
        XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
        do { _ = try await reopened.start(camera: CameraCatalog.instant1970s, title: "Still consumed"); XCTFail("Used Trial cannot reset") }
        catch EntitlementDenial.currentDeviceTrialConsumed { }
    }

    func testLoadIsTheNewFilmEntitlementDecisionAndGivesLapsedSubscribersTheUnusedTrial() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: store)
        let repository = try FilmRepository(rootURL: root)
        let paid = try await coordinator.load(camera: CameraCatalog.super8HomeMovie, title: "Paid",
                                              orientation: .landscape, subscription: .active)
        XCTAssertEqual(try repository.filmAccess(filmID: paid.id), .subscription)
        XCTAssertEqual(paid.movieOrientation, .landscape)
        XCTAssertNil(try store.read(), "A subscriber's new Film never activates this iPhone's Trial")

        // PRD open question 7 is pending the captain; this asserts the provisional default only.
        let lapsed = try await coordinator.load(camera: CameraCatalog.disposable1990s, title: "Lapsed",
                                                subscription: .expired)
        let device = try XCTUnwrap(store.read())
        XCTAssertEqual(try repository.filmAccess(filmID: lapsed.id), .trial(originDevice: device.deviceID))
        for subscription in [SubscriptionAccess.expired, .notPurchased] {
            do { _ = try await coordinator.load(camera: CameraCatalog.instant1970s, title: "Second", subscription: subscription); XCTFail() }
            catch let EntitlementDenial.currentDeviceTrialAlreadyInProgress(id) { XCTAssertEqual(id, lapsed.id) }
        }

        try store.consume(filmID: lapsed.id, savedAt: Date(timeIntervalSince1970: 7))
        for subscription in [SubscriptionAccess.expired, .notPurchased] {
            do { _ = try await coordinator.load(camera: CameraCatalog.instant1970s, title: "Second", subscription: subscription); XCTFail() }
            catch EntitlementDenial.currentDeviceTrialConsumed { }
        }
        let renewed = try await coordinator.load(camera: CameraCatalog.instant1970s, title: "Renewed", subscription: .active)
        XCTAssertEqual(try repository.filmAccess(filmID: renewed.id), .subscription)
        XCTAssertEqual(try repository.allFilms().count, 3)
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
        try await coordinator.deleteFilm(filmID: film.id)
        let next = try await coordinator.start(camera: CameraCatalog.cinema16mm, title: "Replacement", orientation: .landscape, filmStock: .color)
        XCTAssertNotEqual(next.id, film.id)
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
    }

    func testRestoredEmptyAndCapturedTrialFilmsCoexistWithDestinationEntitlement() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let captured = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Restored captured", access: .trial(originDevice: UUID()))
        let source = try await photo(root)
        try repository.savePhotoCapture(filmID: captured.id, sourceData: Data(contentsOf: source))
        let empty = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Restored empty", access: .trial(originDevice: UUID()))
        let destination = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: destination)
        let own = try await coordinator.start(camera: CameraCatalog.mediumFormat6x6, title: "Destination Trial", filmStock: .color)
        for film in [captured, empty] {
            let receiver = try await coordinator.receiver(filmID: film.id)
            try await receiver.commit(.photoSaved(source))
        }
        XCTAssertFalse(try XCTUnwrap(destination.read()).isConsumed)
        XCTAssertEqual(try repository.film(id: captured.id).savedCaptureCount, 2)
        XCTAssertEqual(try repository.film(id: empty.id).savedCaptureCount, 1)
        let ownReceiver = try await coordinator.receiver(filmID: own.id)
        try await ownReceiver.commit(.photoSaved(source))
        XCTAssertEqual(try destination.read()?.consumedFilmID, own.id)
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TrialIntegrationTests-\(UUID())")
    }

    private func photo(_ root: URL) async throws -> URL {
        let fixtures = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let source = fixtures.appendingPathComponent("synthetic-developed-photo.jpg")
        _ = try VerifiedMedia.photo(at: source)
        return source
    }
}

final class MemoryDeviceStore: DeviceTrialStoring, Sendable {
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
    func consume(filmID: UUID, captureID: String? = nil, savedAt: Date) throws {
        try state.withLock { state in
            if state.fails { throw CocoaError(.fileWriteNoPermission) }
            let current = state.record ?? DeviceTrialRecord()
            if !current.isConsumed {
                state.record = DeviceTrialRecord(deviceID: current.deviceID, consumedFilmID: filmID,
                    consumedAt: savedAt, consumedCaptureID: captureID)
            }
        }
    }
}
