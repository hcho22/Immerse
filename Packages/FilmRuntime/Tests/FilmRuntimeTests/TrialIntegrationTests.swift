import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import Synchronization
import XCTest

final class TrialIntegrationTests: XCTestCase {
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
