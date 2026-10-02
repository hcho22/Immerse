import FilmDomain
import FilmPersistence
import Foundation
import RenderFixtures
import Security
import Synchronization
import XCTest
@testable import TrialReceiptStudy

final class ReceiptStudyTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_870_000)
    private let saveBoundaries: [Boundary] = [.preparedMetadata, .copiedMedia, .pendingManifest,
        .beforeReceipt, .afterReceipt, .beforeProjection, .afterProjection, .beforeCleanup, .afterSourceCleanup, .afterCleanup]

    func testAbruptProcessExitsRecoverWithoutLanguageCleanup() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        let executable = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("ReceiptCrashWorker")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        for camera in [CameraCatalog.disposable1990s, CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm] {
            for point in saveBoundaries {
                let app = root.appendingPathComponent("\(camera.id)-\(point)")
                let receiptFile = root.appendingPathComponent("Receipt-\(UUID()).json")
                let source = camera.medium == .photo ? fixture.photo : fixture.movie
                let child = Process()
                child.executableURL = executable
                child.arguments = [app.path, receiptFile.path, source.path, camera.id.rawValue, point.rawValue]
                try child.run()
                child.waitUntilExit()
                XCTAssertEqual(child.terminationReason, .exit)
                XCTAssertEqual(child.terminationStatus, 77)
                let film = try XCTUnwrap(FilmRepository(rootURL: app).allFilms().first)
                let store = try FileReceiptStore(url: receiptFile)
                let before = try store.read().receipt
                let input = input(film: film, fixture: fixture, id: UUID(uuidString: "00000000-0000-0000-0000-000000000456")!)
                let coordinator = try ReceiptCoordinator(root: app, store: store)
                try await coordinator.reconcile()
                try await coordinator.reconcile()
                try await assertSaved(root: app, input: input, count: point == .preparedMetadata ? 0 : 1)
                if let before { XCTAssertEqual(try store.read().receipt, before) }
                print("RECEIPT_PROCESS_EXIT camera=\(camera.id) point=\(point.rawValue) status=77 receiptBefore=\(before != nil) savedAfter=\(point == .preparedMetadata ? 0 : 1)")
            }
        }
    }

    func testEverySavePrefixReopensAndRestoresWithoutUsingDestinationTrial() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for camera in [CameraCatalog.disposable1990s, CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm] {
            for point in saveBoundaries {
                let source = root.appendingPathComponent("\(camera.id)-\(point)")
                let store = ScriptedStore()
                let input = try await interruptedSave(root: source, store: store, camera: camera, fixture: fixture, point: point)
                let prior = try FilmRepository(rootURL: source).film(id: input.filmID).savedCaptureCount
                let expected = point == .preparedMetadata ? 0 : 1
                let snapshot = root.appendingPathComponent("Snapshot-\(UUID())")
                try FileManager.default.copyItem(at: source, to: snapshot)
                for alreadyConsumed in [false, true] {
                    let restored = root.appendingPathComponent("Restored-\(UUID())")
                    try FileManager.default.copyItem(at: snapshot, to: restored)
                    let destination = ScriptedStore(consumed: alreadyConsumed)
                    let before = try destination.read()
                    let coordinator = try ReceiptCoordinator(root: restored, store: destination)
                    try await coordinator.reconcile()
                    try await coordinator.reconcile()
                    try await assertSaved(root: restored, input: input, count: expected)
                    XCTAssertEqual(try destination.read().receipt, before.receipt)
                    XCTAssertEqual(destination.publications, 0)
                    if !alreadyConsumed {
                        let own = try await coordinator.start(camera: CameraCatalog.instant1970s)
                        XCTAssertNotEqual(own.id, input.filmID)
                    }
                    try await coordinator.deleteFilm(input.filmID)
                    try await coordinator.reconcile()
                    XCTAssertThrowsError(try FilmRepository(rootURL: restored).film(id: input.filmID))
                    XCTAssertFalse(FileManager.default.fileExists(atPath: restored.appendingPathComponent("Staging/\(input.filmID)").path))
                }
                let reopened = try ReceiptCoordinator(root: source, store: store)
                try await reopened.reconcile()
                try await reopened.reconcile()
                try await assertSaved(root: source, input: input, count: expected)
                if expected == 1 {
                    try await reopened.save(input)
                    XCTAssertEqual(try store.read().receipt?.captureID, input.id)
                    XCTAssertEqual(store.publications, 1)
                }
                print("RECEIPT_PREFIX camera=\(camera.id) point=\(point.rawValue) initialSQL=\(prior) reopened=\(expected) destinations=unused,consumed destinationWrites=0 capture=\(input.id) hash=\(ReceiptCoordinator.hash(try Data(contentsOf: input.url)))")
            }
        }
    }

    func testStorageLossAtEachPrefixDoesNotGrantTrialAfterReceiptCommit() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for point in saveBoundaries {
            let app = root.appendingPathComponent(point.rawValue)
            let store = ScriptedStore()
            _ = try await interruptedSave(root: app, store: store, camera: CameraCatalog.disposable1990s, fixture: fixture, point: point)
            let committed = try store.read().receipt != nil
            try FileManager.default.removeItem(at: app)
            let reinstalled = try ReceiptCoordinator(root: app, store: store)
            if committed {
                do { _ = try await reinstalled.start(camera: CameraCatalog.instant1970s); XCTFail("Committed Trial must not reset") }
                catch StudyError.consumed { }
            } else { _ = try await reinstalled.start(camera: CameraCatalog.instant1970s) }
            print("RECEIPT_STORAGE_LOSS point=\(point.rawValue) consumed=\(committed)")
        }
    }

    func testLostRepliesRemainPendingUntilAuthoritativeReadThenDebitOnce() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for mode in [ScriptedStore.Mode.committedLostReply, .notCommittedLostReply] {
            let app = root.appendingPathComponent("\(mode)")
            let store = ScriptedStore()
            let coordinator = try ReceiptCoordinator(root: app, store: store)
            let film = try await coordinator.start(camera: CameraCatalog.disposable1990s)
            let input = input(film: film, fixture: fixture)
            store.mode = mode
            do { try await coordinator.save(input); XCTFail("Lost outcome must remain pending") }
            catch ReceiptFailure.unknown { }
            XCTAssertEqual(try FilmRepository(rootURL: app).film(id: film.id).savedCaptureCount, 0)
            store.unavailable = true
            for action in 0..<3 {
                do {
                    switch action {
                    case 0: try await coordinator.reconcile()
                    case 1: try await coordinator.save(input)
                    default: _ = try await coordinator.start(camera: CameraCatalog.instant1970s)
                    }
                    XCTFail("Unreadable receipt must fail closed")
                } catch ReceiptFailure.unavailable { }
            }
            XCTAssertEqual(try FilmRepository(rootURL: app).film(id: film.id).savedCaptureCount, 0)
            store.unavailable = false; store.mode = .success
            try await coordinator.save(input)
            try await coordinator.save(input)
            try await assertSaved(root: app, input: input, count: 1)
            XCTAssertEqual(try store.read().receipt?.captureID, input.id)
        }
    }

    func testNativeStatusAdapterKeepsUnknownCapturePendingAcrossActualSQLiteRecovery() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for applied in [false, true] {
            let app = root.appendingPathComponent("NativeStatus-\(applied)")
            let device = UUID()
            let initial = NativeReceiptEnvelope(record: ReceiptRecord(deviceID: device, receipt: nil))
            let calls = StatusCalls(bytes: try JSONEncoder().encode(initial))
            let store = NativeReceiptStatusAdapter(calls: calls, expectedDeviceID: device)
            let coordinator = try ReceiptCoordinator(root: app, store: store)
            let film = try await coordinator.start(camera: CameraCatalog.super8HomeMovie)
            let input = input(film: film, fixture: fixture)
            calls.appliesUpdate = applied
            calls.updateStatus = errSecNotAvailable
            calls.readAfterUpdate = .init(status: errSecInteractionNotAllowed, data: nil)
            do { try await coordinator.save(input); XCTFail("Unknown native reply must remain pending") }
            catch ReceiptFailure.unknown { }
            XCTAssertEqual(try FilmRepository(rootURL: app).film(id: film.id).savedCaptureCount, 0)
            let reopened = try ReceiptCoordinator(root: app, store: store)
            do { try await reopened.save(input); XCTFail("Read unavailable must block capture") }
            catch ReceiptFailure.unavailable { }
            do { _ = try await reopened.start(camera: CameraCatalog.instant1970s); XCTFail("Read unavailable must block Trial start") }
            catch ReceiptFailure.unavailable { }
            calls.overrideRead = nil; calls.readAfterUpdate = nil
            calls.appliesUpdate = true; calls.updateStatus = errSecSuccess
            try await reopened.reconcile()
            try await reopened.save(input)
            try await assertSaved(root: app, input: input, count: 1)
            XCTAssertEqual(calls.updateCount, applied ? 1 : 2)
            XCTAssertEqual(try store.read().receipt?.captureID, input.id)
        }
    }

    func testDurableAbortPreventsReplayAndKeepsZeroSaveReplacement() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for point in [Boundary.afterAbort, .afterAbortCleanup] {
            let app = root.appendingPathComponent(point.rawValue)
            let store = ScriptedStore()
            let film = try await rejectAt(root: app, store: store, fixture: fixture, point: point)
            store.mode = .success
            let reopened = try ReceiptCoordinator(root: app, store: store)
            try await reopened.reconcile()
            XCTAssertEqual(try FilmRepository(rootURL: app).film(id: film.id).savedCaptureCount, 0)
            do { try await reopened.save(input(film: film, fixture: fixture, id: rejectedID)); XCTFail("Aborted operation cannot replay") }
            catch StudyError.aborted { }
            let restored = root.appendingPathComponent("AbortedBackup-\(UUID())")
            try FileManager.default.copyItem(at: app, to: restored)
            let destination = try ReceiptCoordinator(root: restored, store: ScriptedStore())
            try await destination.reconcile()
            XCTAssertEqual(try FilmRepository(rootURL: restored).film(id: film.id).savedCaptureCount, 0)
            try await reopened.deleteFilm(film.id)
            _ = try await reopened.start(camera: CameraCatalog.instant1970s)
            XCTAssertNil(try store.read().receipt)
        }
    }

    func testProjectionFailureKeepsReceiptAndNativeMediaRecoverable() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for fault in [SaveFailureInjection.beforeDurableMove, .afterDurableMoveBeforeDebit, .afterDatabaseCommitBeforeAcknowledgement] {
            let app = root.appendingPathComponent("\(fault)")
            let store = ScriptedStore()
            let input = try await failProjection(root: app, store: store, fixture: fixture, fault: fault)
            XCTAssertEqual(try store.read().receipt?.captureID, input.id)
            let reopened = try ReceiptCoordinator(root: app, store: store)
            try await reopened.reconcile()
            try await reopened.save(input)
            try await assertSaved(root: app, input: input, count: 1)
            XCTAssertEqual(store.publications, 1)
        }
    }

    func testUnknownOutcomeDeletionRetainsConsumptionAndOldBackupOnlyCanRestoreFilm() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for mode in [ScriptedStore.Mode.committedLostReply, .notCommittedLostReply] {
            let app = root.appendingPathComponent("\(mode)")
            let store = ScriptedStore()
            let input = try await loseReceiptReply(root: app, store: store, fixture: fixture, mode: mode)
            let old = root.appendingPathComponent("Old-\(mode)")
            try FileManager.default.copyItem(at: app, to: old)
            store.unavailable = true
            let coordinator = try ReceiptCoordinator(root: app, store: store)
            try await coordinator.deleteFilm(input.filmID)
            store.unavailable = false; store.mode = .success
            try await coordinator.reconcile()
            XCTAssertThrowsError(try FilmRepository(rootURL: app).film(id: input.filmID))
            XCTAssertEqual(try store.read().receipt != nil, mode == .committedLostReply)
            let restored = try ReceiptCoordinator(root: old, store: ScriptedStore())
            try await restored.reconcile()
            try await assertSaved(root: old, input: input, count: 1)
        }
    }

    func testCorruptPreparedMediaCannotProjectOrConsumeAndDeletionRemainsPossible() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for point in [Boundary.beforeReceipt, .afterReceipt] {
            let app = root.appendingPathComponent(point.rawValue)
            let store = ScriptedStore()
            let input = try await interruptedSave(root: app, store: store, camera: CameraCatalog.super8HomeMovie, fixture: fixture, point: point)
            let media = app.appendingPathComponent("Staging/\(input.filmID)/ReceiptStudy/\(input.id).mov")
            try Data("corrupt synthetic bytes".utf8).write(to: media)
            let coordinator = try ReceiptCoordinator(root: app, store: store)
            do { try await coordinator.reconcile(); XCTFail("Must not project corrupted source") } catch { }
            XCTAssertEqual(try FilmRepository(rootURL: app).film(id: input.filmID).savedCaptureCount, 0)
            XCTAssertEqual(try store.read().receipt != nil, point == .afterReceipt)
            try await coordinator.deleteFilm(input.filmID)
            XCTAssertFalse(FileManager.default.fileExists(atPath: media.path))
        }
    }

    func testCapacityFullAndDurationMismatchNeverPublishAnExtraReceipt() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        for camera in [CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm] {
            guard case let .seconds(budget) = camera.capacity else { return XCTFail() }
            let fixture = try await fixtures(root.appendingPathComponent(camera.id.rawValue), seconds: Double(budget))
            let app = root.appendingPathComponent("Full-\(camera.id)")
            let store = ScriptedStore()
            let coordinator = try ReceiptCoordinator(root: app, store: store)
            let film = try await coordinator.start(camera: camera)
            let input = input(film: film, fixture: fixture)
            let mismatch = CaptureInput(id: UUID(), filmID: film.id, url: input.url,
                kind: .movieClip(seconds: Double(budget) + 1, orientation: .portrait), savedAt: date)
            do { try await coordinator.save(mismatch); XCTFail("Metadata cannot invent duration") }
            catch StudyError.invalidOperation { }
            XCTAssertNil(try store.read().receipt)
            try await coordinator.save(input)
            let full = try FilmRepository(rootURL: app).film(id: film.id)
            XCTAssertEqual(full.remainingMovieSeconds, 0)
            XCTAssertEqual(full.completionState, .capacityFull)
            do { try await coordinator.save(self.input(film: film, fixture: fixture)); XCTFail("Full Film must reject capture") }
            catch FilmDomainError.captureAlreadyComplete { }
            XCTAssertEqual(store.publications, 1)
            try await assertSaved(root: app, input: input, count: 1)
        }
    }

    func testQueuedDeletionWaitsForReceiptOwnerAndRejectsStaleSave() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        let app = root.appendingPathComponent("App")
        let store = ScriptedStore()
        let gate = SuspensionGate()
        let coordinator = try ReceiptCoordinator(root: app, store: store, boundary: { point in
            if point == .afterReceipt { await gate.suspend() }
        })
        let film = try await coordinator.start(camera: CameraCatalog.cinema16mm)
        let input = input(film: film, fixture: fixture)
        let save = Task { try await coordinator.save(input) }
        try await gate.waitUntilEntered()
        let deletion = Task { try await coordinator.deleteFilm(film.id) }
        try await waitForQueued(1, coordinator)
        let stale = Task { try await coordinator.save(input) }
        try await waitForQueued(2, coordinator)
        XCTAssertEqual(try FilmRepository(rootURL: app).film(id: film.id).savedCaptureCount, 0)
        await gate.release()
        try await save.value
        try await deletion.value
        do { try await stale.value; XCTFail("Queued callback must not recreate deleted Film") }
        catch PersistenceError.filmNotFound { }
        XCTAssertThrowsError(try FilmRepository(rootURL: app).film(id: film.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.appendingPathComponent("Staging/\(film.id)").path))
        XCTAssertEqual(try store.read().receipt?.captureID, input.id)
    }

    func testAbortAfterReceiptCannotRefundAndFailedAbortWriteStaysPending() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try await fixtures(root)
        for point in [Boundary.beforeReceipt, .afterReceipt] {
            let app = root.appendingPathComponent(point.rawValue)
            let store = ScriptedStore()
            let input = try await interruptedSave(root: app, store: store, camera: CameraCatalog.disposable1990s, fixture: fixture, point: point)
            let coordinator = try ReceiptCoordinator(root: app, store: store, boundary: fault(at: .beforeAbort))
            do { try await coordinator.abort(filmID: input.filmID, captureID: input.id); XCTFail("Cannot acknowledge abort") }
            catch StudyError.alreadyCommitted { XCTAssertEqual(point, .afterReceipt) }
            catch let error as CocoaError { XCTAssertEqual(error.code, .fileWriteOutOfSpace); XCTAssertEqual(point, .beforeReceipt) }
            // Failed abort was never terminal. The same pending operation can recover.
            let reopened = try ReceiptCoordinator(root: app, store: store)
            try await reopened.reconcile()
            try await assertSaved(root: app, input: input, count: 1)
        }
    }

    private func waitForQueued(_ count: Int, _ coordinator: ReceiptCoordinator) async throws {
        let deadline = Date().addingTimeInterval(5)
        while await coordinator.queuedOperations() < count {
            guard Date() < deadline else { throw ReceiptFailure.unavailable }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private let rejectedID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!

    private func rejectAt(root: URL, store: ScriptedStore, fixture: Fixtures, point: Boundary) async throws -> Film {
        let coordinator = try ReceiptCoordinator(root: root, store: store, boundary: fault(at: point))
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s)
        store.mode = .reject
        do { try await coordinator.save(input(film: film, fixture: fixture, id: rejectedID)); XCTFail("Expected abort interruption") }
        catch let error as CocoaError { XCTAssertEqual(error.code, .fileWriteOutOfSpace) }
        return film
    }
    private func loseReceiptReply(root: URL, store: ScriptedStore, fixture: Fixtures, mode: ScriptedStore.Mode) async throws -> CaptureInput {
        let coordinator = try ReceiptCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s)
        let input = input(film: film, fixture: fixture)
        store.mode = mode
        do { try await coordinator.save(input); XCTFail("Expected lost reply") } catch ReceiptFailure.unknown { }
        return input
    }
    private func failProjection(root: URL, store: ScriptedStore, fixture: Fixtures, fault: SaveFailureInjection) async throws -> CaptureInput {
        let coordinator = try ReceiptCoordinator(root: root, store: store, projectionFailure: fault)
        let film = try await coordinator.start(camera: CameraCatalog.disposable1990s)
        let input = input(film: film, fixture: fixture)
        do { try await coordinator.save(input); XCTFail("Expected injected projection failure") }
        catch PersistenceError.simulatedFailure(let actual) { XCTAssertEqual(actual, fault) }
        return input
    }
    private func interruptedSave(root: URL, store: ScriptedStore, camera: CameraPackage, fixture: Fixtures, point: Boundary) async throws -> CaptureInput {
        let coordinator = try ReceiptCoordinator(root: root, store: store, boundary: fault(at: point))
        let film = try await coordinator.start(camera: camera)
        let input = input(film: film, fixture: fixture)
        do { try await coordinator.save(input); XCTFail("Expected boundary fault") }
        catch let error as CocoaError { XCTAssertEqual(error.code, .fileWriteOutOfSpace) }
        return input
    }
    private func fault(at point: Boundary) -> @Sendable (Boundary) async throws -> Void {
        { if $0 == point { throw CocoaError(.fileWriteOutOfSpace) } }
    }
    private struct Fixtures {
        let photo: URL
        let movie: URL
        let duration: Double
    }
    private func fixtures(_ root: URL, seconds: Double = 1) async throws -> Fixtures {
        let directory = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 160; settings.photoHeight = 120
        settings.movieWidth = 160; settings.movieHeight = 96
        settings.movieDurationSeconds = seconds; settings.movieFrameRate = 1
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: directory, settings: settings)
        return Fixtures(photo: directory.appendingPathComponent("synthetic-developed-photo.jpg"),
            movie: directory.appendingPathComponent("synthetic-developed-movie.mov"), duration: manifest.movie.durationSeconds)
    }
    private func input(film: Film, fixture: Fixtures, id: UUID = UUID()) -> CaptureInput {
        CaptureInput(id: id, filmID: film.id, url: film.camera.medium == .photo ? fixture.photo : fixture.movie,
            kind: film.camera.medium == .photo ? .photo : .movieClip(seconds: fixture.duration, orientation: .landscape), savedAt: date)
    }
    private func assertSaved(root: URL, input: CaptureInput, count: Int) async throws {
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.film(id: input.filmID)
        XCTAssertEqual(film.savedCaptureCount, count)
        guard count == 1 else { return }
        XCTAssertEqual(film.captures[0].savedAt, input.savedAt)
        XCTAssertEqual(film.captures[0].kind, input.kind)
        XCTAssertEqual(film.captures[0].sequenceNumber, 1)
        XCTAssertEqual(film.captures[0].revealState, .sealed)
        switch input.kind {
        case .photo: XCTAssertEqual(film.remainingExposures, 26)
        case let .movieClip(seconds, _):
            XCTAssertEqual(film.consumedMovieSeconds, seconds)
            XCTAssertEqual(film.movieOrientation, .portrait)
        }
        let source = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        let verified: VerifiedMedia
        if film.camera.medium == .photo { verified = try VerifiedMedia.photo(at: source.url) }
        else { verified = try await VerifiedMedia.movie(at: source.url) }
        XCTAssertEqual(verified.sha256, ReceiptCoordinator.hash(try Data(contentsOf: input.url)))
        XCTAssertEqual(source.record.sha256, verified.sha256)
        XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
    }
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TrialReceiptStudy-\(UUID())")
    }
}

private actor SuspensionGate {
    private var entered = false
    private var waiter: CheckedContinuation<Void, Never>?
    func suspend() async {
        entered = true
        await withCheckedContinuation { waiter = $0 }
    }
    func waitUntilEntered() async throws {
        let deadline = Date().addingTimeInterval(5)
        while !entered {
            guard Date() < deadline else { throw ReceiptFailure.unavailable }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    func release() { waiter?.resume(); waiter = nil }
}

private final class ScriptedStore: ReceiptStoring, Sendable {
    enum Mode { case success, reject, committedLostReply, notCommittedLostReply }
    private struct State {
        var record: ReceiptRecord
        var mode = Mode.success
        var unavailable = false
        var publications = 0
    }
    private let state: Mutex<State>
    init(consumed: Bool = false) {
        state = Mutex(State(record: ReceiptRecord(deviceID: UUID(), receipt: consumed
            ? Receipt(filmID: UUID(), captureID: UUID(), savedAt: Date(timeIntervalSince1970: 1)) : nil)))
    }
    var mode: Mode {
        get { state.withLock { $0.mode } }
        set { state.withLock { $0.mode = newValue } }
    }
    var unavailable: Bool {
        get { state.withLock { $0.unavailable } }
        set { state.withLock { $0.unavailable = newValue } }
    }
    var publications: Int { state.withLock { $0.publications } }
    func read() throws -> ReceiptRecord {
        try state.withLock { value in
            if value.unavailable { throw ReceiptFailure.unavailable }
            return value.record
        }
    }
    func publish(_ receipt: Receipt) throws {
        try state.withLock { value in
            value.publications += 1
            if let prior = value.record.receipt {
                guard prior == receipt else { throw ReceiptFailure.conflict }
                return
            }
            switch value.mode {
            case .reject: throw ReceiptFailure.rejected
            case .notCommittedLostReply: throw ReceiptFailure.unknown
            case .success, .committedLostReply:
                value.record = ReceiptRecord(deviceID: value.record.deviceID, receipt: receipt)
                if value.mode == .committedLostReply { throw ReceiptFailure.unknown }
            }
        }
    }
}
