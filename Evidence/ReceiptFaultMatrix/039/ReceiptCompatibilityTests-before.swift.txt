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

private enum CompatibilityStop: Error { case prepared }

/// Ordinary memory only. The override simulates a successful but conflicting
/// readback; retained actual bytes distinguish it from a receipt rewrite.
private final class CompatibilityReceiptCalls: TrialKeychainCalling, Sendable {
    private struct State {
        var actual: Data
        let returnedAfterUpdate: Data?
        var updates = 0
        var adds = 0
    }
    private let state: Mutex<State>
    init(actual: Data, returnedAfterUpdate: Data? = nil) {
        state = Mutex(State(actual: actual, returnedAfterUpdate: returnedAfterUpdate))
    }
    var actual: Data { state.withLock { $0.actual } }
    var updates: Int { state.withLock { $0.updates } }
    var adds: Int { state.withLock { $0.adds } }
    func read(service: String) -> TrialKeychainRead {
        state.withLock {
            .init(status: errSecSuccess, data: $0.updates > 0 ? ($0.returnedAfterUpdate ?? $0.actual) : $0.actual)
        }
    }
    func add(service: String, data: Data) -> OSStatus {
        state.withLock { $0.adds += 1 }; return errSecDuplicateItem
    }
    func update(service: String, data: Data) -> OSStatus {
        state.withLock { $0.actual = data; $0.updates += 1 }; return errSecSuccess
    }
}

@MainActor final class ReceiptCompatibilityTests: XCTestCase {
    func testSamePendingOperationCounterfactualAndSameFilmRestoreCompatibility() async throws {
        #if os(iOS)
        let parent = URL.documentsDirectory
        #else
        let parent = FileManager.default.temporaryDirectory
        #endif
        let directory = parent.appendingPathComponent("ReceiptCompatibility/\(UUID())")
        let currentRoot = directory.appendingPathComponent("Current")
        let restoredRoot = directory.appendingPathComponent("RestoredEmptyBackup")
        let rejectedRoot = directory.appendingPathComponent("RejectedReadback")
        let exactRoot = directory.appendingPathComponent("ExactReadbackControl")
        print("RECEIPT_COMPATIBILITY \(directory.path)")

        let unused = try JSONEncoder().encode(DeviceTrialRecord())
        let originalCalls = CompatibilityReceiptCalls(actual: unused)
        let original = try TrialCoordinator(root: currentRoot, store: store(originalCalls))
        let film = try await original.start(camera: CameraCatalog.disposable1990s, title: "Synthetic restore compatibility")
        // Two filesystem snapshots of the same empty Film, before either save.
        try FileManager.default.copyItem(at: currentRoot, to: restoredRoot)
        try FileManager.default.copyItem(at: currentRoot, to: rejectedRoot)

        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 160; settings.photoHeight = 120
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        let fixtures = directory.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let photoBytes = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        let native = try CapturedMediaFiles(directory: directory.appendingPathComponent("NativeInput"))
        let earlierID = UUID(), laterID = UUID()
        let earlierDate = film.loadedAt.addingTimeInterval(1)
        try native.prepare(.init(id: earlierID, mediaKind: .photo, createdAt: earlierDate))
        let earlier = try native.savePhoto(photoBytes, id: earlierID)
        try native.prepare(.init(id: laterID, mediaKind: .photo, createdAt: earlierDate.addingTimeInterval(60)))
        let later = try native.savePhoto(photoBytes, id: laterID)

        // History R: save A, retain its receipt, restore the older empty Film,
        // then prepare a new capture B. No new Trial is granted or receipt reset.
        let originalReceiver = try await original.receiver(filmID: film.id)
        try await originalReceiver.commit(.photoSaved(earlier))
        let earlierReceipt = originalCalls.actual
        let restoredCalls = CompatibilityReceiptCalls(actual: earlierReceipt)
        let restored = try TrialCoordinator(root: restoredRoot, store: store(restoredCalls), checkpoint: {
            if $0 == .prepared { throw CompatibilityStop.prepared }
        })
        let restoredReceiver = try await restored.receiver(filmID: film.id)
        do { try await restoredReceiver.commit(.photoSaved(later)); XCTFail("Expected prepared stop") }
        catch CompatibilityStop.prepared { }

        // History M: first save B writes the correct receipt but readback returns
        // A. The local pending operation is identical to history R's operation.
        let rejectedCalls = CompatibilityReceiptCalls(actual: unused, returnedAfterUpdate: earlierReceipt)
        let rejected = try TrialCoordinator(root: rejectedRoot, store: store(rejectedCalls))
        let rejectedReceiver = try await rejected.receiver(filmID: film.id)
        do { try await rejectedReceiver.commit(.photoSaved(later)); XCTFail("Expected mismatched initial readback") }
        catch let error as TrialKeychainError { XCTAssertEqual(error.status, errSecNotAvailable) }
        XCTAssertEqual(rejectedCalls.updates, 1)
        XCTAssertNotEqual(try canonical(rejectedCalls.actual), try canonical(earlierReceipt))

        let restoredInput = try snapshot(root: restoredRoot, calls: restoredCalls, filmID: film.id,
                                         captureID: later.lastPathComponent, name: "before", directory: directory)
        let rejectedInput = try snapshot(root: rejectedRoot, calls: rejectedCalls, filmID: film.id,
                                         captureID: later.lastPathComponent, name: "before", directory: directory)
        XCTAssertEqual(restoredInput, rejectedInput, "Recovery-visible Film, grant, pending operation, media and readback coincide")
        try FileManager.default.copyItem(at: rejectedRoot, to: directory.appendingPathComponent("PendingBeforeRecovery"))

        // One-condition control: copy the rejected pending state and expose its
        // exact actual receipt instead. Neither branch has a SQL capture receipt.
        try FileManager.default.copyItem(at: rejectedRoot, to: exactRoot)
        let exactCalls = CompatibilityReceiptCalls(actual: rejectedCalls.actual)
        _ = try snapshot(root: exactRoot, calls: exactCalls, filmID: film.id,
                         captureID: later.lastPathComponent, name: "before", directory: directory)
        for root in [restoredRoot, rejectedRoot, exactRoot] {
            let repository = try FilmRepository(rootURL: root)
            XCTAssertNil(try repository.captureReceipt(filmID: film.id, captureID: later.lastPathComponent))
            XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
            XCTAssertTrue(try repository.hasPendingCapture(filmID: film.id))
        }

        for (root, calls) in [(restoredRoot, restoredCalls), (exactRoot, exactCalls)] {
            let reopened = try TrialCoordinator(root: root, store: store(calls))
            try await reopened.reconcile()
            try await reopened.reconcile()
            let repository = try FilmRepository(rootURL: root)
            XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
            XCTAssertEqual(try repository.film(id: film.id).captures.first?.revealState, .sealed)
            XCTAssertFalse(try repository.hasPendingCapture(filmID: film.id))
            XCTAssertEqual(calls.updates, 0)
            XCTAssertEqual(calls.adds, 0)
            let source = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
            XCTAssertEqual(try VerifiedMedia.photo(at: source.url).sha256, source.record.sha256)
            _ = try snapshot(root: root, calls: calls, filmID: film.id,
                             captureID: later.lastPathComponent, name: "after", directory: directory)
        }

        let actualBefore = rejectedCalls.actual
        let returnedBefore = try XCTUnwrap(rejectedCalls.read(service: "injected-only").data)
        let recovery = try TrialCoordinator(root: rejectedRoot, store: store(rejectedCalls))
        do { try await recovery.reconcile(); XCTFail("Still-conflicting readback must remain unresolved") }
        catch let error as TrialKeychainError { XCTAssertEqual(error.status, errSecNotAvailable) }
        let repository = try FilmRepository(rootURL: rejectedRoot)
        _ = try snapshot(root: rejectedRoot, calls: rejectedCalls, filmID: film.id,
                         captureID: later.lastPathComponent, name: "after", directory: directory)
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
        XCTAssertTrue(try repository.hasPendingCapture(filmID: film.id))
        XCTAssertEqual(rejectedCalls.actual, actualBefore)
        XCTAssertEqual(rejectedCalls.read(service: "injected-only").data, returnedBefore)
        XCTAssertEqual(rejectedCalls.updates, 1)
        XCTAssertEqual(rejectedCalls.adds, 0)
    }

    private func store(_ calls: CompatibilityReceiptCalls) -> KeychainDeviceTrialStore {
        KeychainDeviceTrialStore(service: "injected-only-compatibility", calls: calls)
    }

    private func canonical(_ data: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: data), options: .sortedKeys)
    }

    private func snapshot(root: URL, calls: CompatibilityReceiptCalls, filmID: UUID, captureID: String,
                          name: String, directory: URL) throws -> Data {
        let repository = try FilmRepository(rootURL: root)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let returned = try XCTUnwrap(calls.read(service: "injected-only").data)
        var observed: [String: Any] = [
            "film": try JSONSerialization.jsonObject(with: encoder.encode(repository.film(id: filmID))),
            "access": try JSONSerialization.jsonObject(with: encoder.encode(repository.filmAccess(filmID: filmID))),
            "returnedReceipt": try JSONSerialization.jsonObject(with: returned),
            "pending": try repository.hasPendingCapture(filmID: filmID),
            "hasSQLCaptureReceipt": try repository.captureReceipt(filmID: filmID, captureID: captureID) != nil
        ]
        let pendingMedia = root.appendingPathComponent("Staging/\(filmID)/Commit/\(captureID)")
        if FileManager.default.fileExists(atPath: pendingMedia.path) {
            observed["pendingOperation"] = try JSONSerialization.jsonObject(with: Data(contentsOf: pendingMedia.appendingPathExtension("json")))
            observed["verifiedPendingSHA256"] = try VerifiedMedia.photo(at: pendingMedia).sha256
        }
        let output = try JSONSerialization.data(withJSONObject: observed, options: [.sortedKeys, .prettyPrinted])
        let prefix = "\(root.lastPathComponent)-\(name)"
        try output.write(to: directory.appendingPathComponent("\(prefix)-observed.json"), options: .withoutOverwriting)
        try calls.actual.write(to: directory.appendingPathComponent("\(prefix)-actual.json"), options: .withoutOverwriting)
        try returned.write(to: directory.appendingPathComponent("\(prefix)-returned.json"), options: .withoutOverwriting)
        try encoder.encode(["updates": calls.updates, "adds": calls.adds])
            .write(to: directory.appendingPathComponent("\(prefix)-calls.json"), options: .withoutOverwriting)
        return output
    }
}
