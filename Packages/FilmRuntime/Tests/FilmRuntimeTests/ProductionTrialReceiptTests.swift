import EntitlementCore
import FilmDomain
import FilmPersistence
import Foundation
import NativeAdapters
import RenderFixtures
import Security
import Synchronization
import XCTest
@testable import FilmRuntime

final class ProductionTrialReceiptTests: XCTestCase {
    func testNativeLostRepliesKeepPendingMediaUntilReadbackThenProjectExactlyOnce() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try await fixtures(root)
        for applied in [false, true] {
            let app = root.appendingPathComponent("App-\(applied)")
            let calls = ReceiptCalls()
            let store = KeychainDeviceTrialStore(calls: calls)
            let coordinator = try TrialCoordinator(root: app, store: store)
            let film = try await coordinator.start(camera: CameraCatalog.super8HomeMovie, title: "Pending", orientation: .portrait)
            let receiver = try await coordinator.receiver(filmID: film.id)
            let event = CaptureSaveEvent.movieClipSaved(url: fixtures.movie, durationSeconds: fixtures.seconds, orientation: .landscape)
            calls.configure(applies: applied, status: errSecNotAvailable, unreadableAfterWrite: true)
            do { try await receiver.commit(event); XCTFail("Unreadable outcome must stay pending") }
            catch let error as TrialKeychainError { XCTAssertEqual(error.status, errSecInteractionNotAllowed) }
            let repository = try FilmRepository(rootURL: app)
            XCTAssertTrue(try repository.hasPendingCapture(filmID: film.id))
            XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
            XCTAssertEqual(try repository.film(id: film.id).remainingMovieSeconds, 200)
            let reopened = try TrialCoordinator(root: app, store: store)
            do { _ = try await reopened.state(); XCTFail("Pending capture cannot expose eligibility") } catch { }
            do { _ = try await reopened.start(camera: CameraCatalog.instant1970s, title: "No reset"); XCTFail("Unavailable") } catch { }
            calls.configure(applies: true, status: errSecSuccess, unreadableAfterWrite: false)
            try await reopened.reconcile()
            let retry = try await reopened.receiver(filmID: film.id)
            try await retry.commit(event)
            try await reopened.reconcile()
            let saved = try repository.film(id: film.id)
            XCTAssertEqual(saved.savedCaptureCount, 1)
            XCTAssertEqual(saved.consumedMovieSeconds, fixtures.seconds)
            XCTAssertEqual(saved.movieOrientation, .portrait)
            XCTAssertEqual(saved.captures.first?.revealState, .sealed)
            XCTAssertFalse(try repository.hasPendingCapture(filmID: film.id))
            XCTAssertEqual(calls.updates, applied ? 1 : 2)
            XCTAssertFalse(calls.calledOnMainThread, "All Security-boundary calls in the production owner run off main")
            XCTAssertEqual(try store.read()?.consumedCaptureID, fixtures.movie.lastPathComponent)
            let source = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
            let verified = try await VerifiedMedia.movie(at: source.url)
            XCTAssertEqual(verified.sha256, source.record.sha256)
            print("PRODUCTION_NATIVE_REPLY applied=\(applied) updates=\(calls.updates) count=1 pending=false")
        }
    }

    func testProjectionFaultsReopenAndDestinationCopiesKeepIndependentEntitlement() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try await fixtures(root)
        for camera in [CameraCatalog.disposable1990s, CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm] {
            for fault in [SaveFailureInjection.beforeDurableMove, .afterDurableMoveBeforeDebit, .afterDatabaseCommitBeforeAcknowledgement] {
                let app = root.appendingPathComponent("\(camera.id)-\(fault)")
                let calls = ReceiptCalls()
                let store = KeychainDeviceTrialStore(calls: calls)
                let coordinator = try TrialCoordinator(root: app, store: store, projectionFailure: fault)
                let film = try await coordinator.start(camera: camera, title: "Projection", orientation: camera.medium == .movie ? .portrait : nil)
                let receiver = try await coordinator.receiver(filmID: film.id)
                let event = event(camera, fixtures)
                do { try await receiver.commit(event); XCTFail("Expected fault") }
                catch PersistenceError.simulatedFailure(let observed) { XCTAssertEqual(observed, fault) }
                XCTAssertTrue(try XCTUnwrap(store.read()).isConsumed)
                let snapshot = root.appendingPathComponent("Copy-\(UUID())")
                try FileManager.default.copyItem(at: app, to: snapshot)
                for used in [false, true] {
                    let destinationRoot = root.appendingPathComponent("Destination-\(UUID())")
                    try FileManager.default.copyItem(at: snapshot, to: destinationRoot)
                    let destinationCalls = ReceiptCalls(used: used)
                    let destinationStore = KeychainDeviceTrialStore(calls: destinationCalls)
                    let before = try destinationStore.read()
                    let destination = try TrialCoordinator(root: destinationRoot, store: destinationStore)
                    try await destination.recoverSavedCaptures()
                    try await destination.recoverSavedCaptures()
                    XCTAssertEqual(try FilmRepository(rootURL: destinationRoot).film(id: film.id).savedCaptureCount, 1)
                    XCTAssertEqual(try destinationStore.read(), before)
                    XCTAssertEqual(destinationCalls.updates, 0)
                    if !used { _ = try await destination.start(camera: CameraCatalog.instant1970s, title: "Own Trial") }
                }
                let reopened = try TrialCoordinator(root: app, store: store)
                try await reopened.recoverSavedCaptures()
                let retry = try await reopened.receiver(filmID: film.id)
                try await retry.commit(event)
                let repository = try FilmRepository(rootURL: app)
                XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
                XCTAssertEqual(calls.updates, 1)
                XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
                XCTAssertFalse(try repository.hasPendingCapture(filmID: film.id))
                print("PRODUCTION_PROJECTION camera=\(camera.id) fault=\(fault) reopened=1 destinations=unused,used destinationWrites=0")
            }
        }
    }

    func testSameDeviceOlderEmptyFilmCanContinueWithoutReplacingConsumption() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try await fixtures(root)
        let calls = ReceiptCalls()
        let store = KeychainDeviceTrialStore(calls: calls)
        let coordinator = try TrialCoordinator(root: root.appendingPathComponent("App"), store: store)
        let old = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Earlier empty Film")
        let backup = root.appendingPathComponent("Backup")
        try FileManager.default.copyItem(at: root.appendingPathComponent("App"), to: backup)
        try await coordinator.deleteFilm(filmID: old.id)
        let current = try await coordinator.start(camera: CameraCatalog.instant1970s, title: "Current Trial")
        let currentReceiver = try await coordinator.receiver(filmID: current.id)
        try await currentReceiver.commit(.photoSaved(fixtures.photo))
        let consumed = try store.read()
        let restored = try TrialCoordinator(root: backup, store: store)
        let receiver = try await restored.receiver(filmID: old.id)
        try await receiver.commit(.photoSaved(fixtures.photo))
        XCTAssertEqual(try store.read(), consumed)
        XCTAssertEqual(calls.updates, 1)
        XCTAssertEqual(try FilmRepository(rootURL: backup).film(id: old.id).savedCaptureCount, 1)
    }

    func testQueuedDeletionQuiescesReceiptProjectionAndStaleCallbacksCannotRecreateFilm() async throws {
        #if os(iOS)
        let parent = URL.documentsDirectory
        #else
        let parent = FileManager.default.temporaryDirectory
        #endif
        let directory = parent.appendingPathComponent("ReceiptFIFO/\(UUID())")
        let root = directory.appendingPathComponent("App")
        let fixtures = try await fixtures(directory)
        let calls = ReceiptCalls()
        let gate = CommitSuspension()
        let coordinator = try TrialCoordinator(root: root, store: KeychainDeviceTrialStore(calls: calls), checkpoint: {
            if $0 == .receiptResolved { await gate.suspend() }
        })
        let film = try await coordinator.start(camera: CameraCatalog.cinema16mm, title: "Delete pending", orientation: .portrait)
        let receiver = try await coordinator.receiver(filmID: film.id)
        let event = event(CameraCatalog.cinema16mm, fixtures)
        let save = Task { try await receiver.commit(event) }
        try await gate.waitForEntry()
        let initialCount = await coordinator.queuedOperationCount
        XCTAssertEqual(initialCount, 0)
        // The save owns the lease throughout these observations. Delete is the
        // only newly launched operation until count 1 is actually observed.
        let delete = Task { try await coordinator.deleteFilm(filmID: film.id) }
        try await waitForQueue(1, coordinator)
        let deleteCount = await coordinator.queuedOperationCount
        XCTAssertEqual(deleteCount, 1)
        let stale = Task { try await receiver.commit(event) }
        try await waitForQueue(2, coordinator)
        let callbackCount = await coordinator.queuedOperationCount
        XCTAssertEqual(callbackCount, 2)
        let repository = try FilmRepository(rootURL: root)
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
        let receiptBeforeRelease = try XCTUnwrap(KeychainDeviceTrialStore(calls: calls).read())
        XCTAssertTrue(receiptBeforeRelease.isConsumed)
        try persistFIFO(["initial": initialCount, "deleteQueued": deleteCount, "callbackQueued": callbackCount],
                        name: "held-counts.json", in: directory)
        try persistFIFO(try repository.film(id: film.id), name: "held-film.json", in: directory)
        try persistFIFO(receiptBeforeRelease, name: "injected-receipt-before.json", in: directory)
        await gate.release()
        try await save.value
        try await delete.value
        do { try await stale.value; XCTFail("Deleted Film must not return") }
        catch PersistenceError.filmNotFound { }
        do { _ = try repository.film(id: film.id); XCTFail("Film still present") }
        catch PersistenceError.filmNotFound { }
        try repository.recover()
        XCTAssertTrue(try repository.allFilms().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Staging/\(film.id)").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id)").path))
        XCTAssertEqual(calls.updates, 1)
        let finalCount = await coordinator.queuedOperationCount
        XCTAssertEqual(finalCount, 0)
        let finalReceipt = try XCTUnwrap(KeychainDeviceTrialStore(calls: calls).read())
        XCTAssertEqual(finalReceipt, receiptBeforeRelease)
        try persistFIFO(finalReceipt, name: "injected-receipt-after.json", in: directory)
        try persistFIFO(["queued": finalCount, "privateFilms": try repository.allFilms().count,
                         "injectedReceiptUpdates": calls.updates], name: "completed.json", in: directory)
        print("RECEIPT_FIFO injected-memory-only counts=\(initialCount),\(deleteCount),\(callbackCount),\(finalCount) stale=filmNotFound evidence=\(directory.path)")
    }

    private func persistFIFO<T: Encodable>(_ value: T, name: String, in directory: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: directory.appendingPathComponent(name), options: .withoutOverwriting)
    }

    func testUnknownReceiptDeletionDoesNotRefundAndCorruptMediaCannotProject() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try await fixtures(root)
        for applied in [false, true] {
            let app = root.appendingPathComponent("App-\(applied)")
            let calls = ReceiptCalls()
            let store = KeychainDeviceTrialStore(calls: calls)
            let coordinator = try TrialCoordinator(root: app, store: store)
            let film = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Unknown")
            let receiver = try await coordinator.receiver(filmID: film.id)
            calls.configure(applies: applied, status: errSecNotAvailable, unreadableAfterWrite: true)
            do { try await receiver.commit(.photoSaved(fixtures.photo)); XCTFail("Expected unavailable") } catch { }
            let pending = app.appendingPathComponent("Staging/\(film.id)/Commit/\(fixtures.photo.lastPathComponent)")
            try Data("corrupt private synthetic media".utf8).write(to: pending)
            calls.configure(applies: true, status: errSecSuccess, unreadableAfterWrite: false)
            do { try await coordinator.reconcile(); XCTFail("Must decode and match hash before projection") } catch { }
            XCTAssertEqual(try FilmRepository(rootURL: app).film(id: film.id).savedCaptureCount, 0)
            try await coordinator.deleteFilm(filmID: film.id)
            XCTAssertEqual(try store.read()?.isConsumed, applied)
            XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
            try await coordinator.reconcile()
            XCTAssertTrue(try FilmRepository(rootURL: app).allFilms().isEmpty)
        }
    }

    func testEligibilityRefreshNeverRecoversAnActiveNativeWriter() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let calls = ReceiptCalls()
        let coordinator = try TrialCoordinator(root: root, store: KeychainDeviceTrialStore(calls: calls))
        let film = try await coordinator.start(camera: CameraCatalog.super8HomeMovie, title: "Still recording", orientation: .portrait)
        let repository = try FilmRepository(rootURL: root)
        let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
        try files.prepare(PendingCaptureRecord(id: UUID(), mediaKind: .movie, orientation: .landscape, remainingSeconds: 200))
        _ = try await coordinator.state()
        try await coordinator.reconcile()
        XCTAssertEqual(try files.pendingRecords().count, 1, "Refresh must not prune an active writer's metadata")
        XCTAssertTrue(try repository.hasPendingCapture(filmID: film.id))
        try await coordinator.recoverSavedCaptures()
        XCTAssertTrue(try files.pendingRecords().isEmpty, "Explicit quiescent launch recovery removes empty abandoned metadata")
        XCTAssertFalse(try repository.hasPendingCapture(filmID: film.id))
    }

    func testUnresolvedLegacyTrialDoesNotLockIndependentExistingSubscriptionFilm() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try await fixtures(root)
        let calls = ReceiptCalls()
        let store = KeychainDeviceTrialStore(calls: calls)
        let coordinator = try TrialCoordinator(root: root, store: store)
        let legacy = try await coordinator.start(camera: CameraCatalog.disposable1990s, title: "Legacy obligation")
        let repository = try FilmRepository(rootURL: root)
        try repository.savePhotoCapture(filmID: legacy.id, sourceData: Data(contentsOf: fixtures.photo))
        let existing = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Existing subscription rights", access: .subscription)
        calls.configure(applies: false, status: errSecNotAvailable, unreadableAfterWrite: true)
        do { _ = try await coordinator.state(); XCTFail("Legacy Trial unresolved") } catch { }
        let receiver = try await coordinator.receiver(filmID: existing.id)
        try await receiver.commit(.photoSaved(fixtures.photo))
        try await coordinator.recoverSavedCaptures(filmID: existing.id)
        XCTAssertEqual(try repository.film(id: existing.id).savedCaptureCount, 1)
        XCTAssertEqual(try repository.pendingTrialConsumptions().map(\.filmID), [legacy.id])
        XCTAssertEqual(calls.updates, 1, "Only the failed legacy attempt touches Keychain")
    }

    private func waitForQueue(_ count: Int, _ coordinator: TrialCoordinator) async throws {
        let deadline = Date().addingTimeInterval(5)
        while await coordinator.queuedOperationCount < count {
            guard Date() < deadline else { throw CocoaError(.executableRuntimeMismatch) }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    private struct Fixtures { let photo: URL; let movie: URL; let seconds: Double }
    private func fixtures(_ root: URL) async throws -> Fixtures {
        let directory = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 160; settings.photoHeight = 120
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: directory, settings: settings)
        return Fixtures(photo: directory.appendingPathComponent("synthetic-developed-photo.jpg"),
            movie: directory.appendingPathComponent("synthetic-developed-movie.mov"), seconds: manifest.movie.durationSeconds)
    }
    private func event(_ camera: CameraPackage, _ fixtures: Fixtures) -> CaptureSaveEvent {
        camera.medium == .photo ? .photoSaved(fixtures.photo)
            : .movieClipSaved(url: fixtures.movie, durationSeconds: fixtures.seconds, orientation: .landscape)
    }
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ProductionTrialReceipt-\(UUID())")
    }
}

private actor CommitSuspension {
    private var entered = false
    private var waiter: CheckedContinuation<Void, Never>?
    func suspend() async { entered = true; await withCheckedContinuation { waiter = $0 } }
    func waitForEntry() async throws {
        let deadline = Date().addingTimeInterval(5)
        while !entered {
            guard Date() < deadline else { throw CocoaError(.executableRuntimeMismatch) }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    func release() { waiter?.resume(); waiter = nil }
}

private final class ReceiptCalls: TrialKeychainCalling, Sendable {
    private struct State {
        var data: Data?
        var applies = true
        var status = errSecSuccess
        var unreadableAfterWrite = false
        var unreadable = false
        var updates = 0
        var mainThread = false
    }
    private let state: Mutex<State>
    init(used: Bool = false) {
        let record = DeviceTrialRecord(consumedFilmID: used ? UUID() : nil,
            consumedAt: used ? Date(timeIntervalSince1970: 1) : nil)
        state = Mutex(State(data: try! JSONEncoder().encode(record)))
    }
    var updates: Int { state.withLock { $0.updates } }
    var calledOnMainThread: Bool { state.withLock { $0.mainThread } }
    func configure(applies: Bool, status: OSStatus, unreadableAfterWrite: Bool) {
        state.withLock {
            $0.applies = applies; $0.status = status
            $0.unreadableAfterWrite = unreadableAfterWrite; $0.unreadable = false
        }
    }
    func read(service: String) -> TrialKeychainRead {
        state.withLock {
            $0.mainThread = $0.mainThread || Thread.isMainThread
            return TrialKeychainRead(status: $0.unreadable ? errSecInteractionNotAllowed : errSecSuccess,
                data: $0.unreadable ? nil : $0.data)
        }
    }
    func add(service: String, data: Data) -> OSStatus { errSecDuplicateItem }
    func update(service: String, data: Data) -> OSStatus {
        state.withLock {
            $0.mainThread = $0.mainThread || Thread.isMainThread
            $0.updates += 1
            if $0.applies { $0.data = data }
            $0.unreadable = $0.unreadableAfterWrite
            return $0.status
        }
    }
}
