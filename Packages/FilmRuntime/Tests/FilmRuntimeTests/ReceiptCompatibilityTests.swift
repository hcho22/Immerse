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

private enum CompatibilityStop: Error { case boundary }

/// Injected ordinary memory, not Security. Successful reads always return the
/// actual stored item; deliberately fabricated readbacks live in the fault tests.
private final class AuthoritativeReceiptCalls: TrialKeychainCalling, Sendable {
    private struct State { var actual: Data; var updates = 0; var adds = 0 }
    private let state: Mutex<State>
    init(actual: Data) { state = Mutex(State(actual: actual)) }
    var actual: Data { state.withLock { $0.actual } }
    var updates: Int { state.withLock { $0.updates } }
    var adds: Int { state.withLock { $0.adds } }
    func read(service: String) -> TrialKeychainRead {
        state.withLock { .init(status: errSecSuccess, data: $0.actual) }
    }
    func add(service: String, data: Data) -> OSStatus {
        state.withLock { $0.adds += 1 }; return errSecDuplicateItem
    }
    func update(service: String, data: Data) -> OSStatus {
        state.withLock { $0.actual = data; $0.updates += 1 }; return errSecSuccess
    }
}

@MainActor final class ReceiptCompatibilityTests: XCTestCase {
    func testSameFilmEmptyBackupKeepsEarlierConsumptionAndSavesNewCaptureOnce() async throws {
        let fixture = try await Fixture()
        let backup = fixture.directory.appendingPathComponent("EmptyBackup")
        try FileManager.default.copyItem(at: fixture.root, to: backup)
        let earlier = try fixture.photo()
        let original = try TrialCoordinator(root: fixture.root, store: store(fixture.calls))
        let receiver = try await original.receiver(filmID: fixture.film.id)
        try await receiver.commit(.photoSaved(earlier))
        let consumed = fixture.calls.actual
        let later = try fixture.photo()
        XCTAssertNotEqual(earlier.lastPathComponent, later.lastPathComponent)
        let restored = try TrialCoordinator(root: backup, store: store(fixture.calls))
        let restoredReceiver = try await restored.receiver(filmID: fixture.film.id)
        try await restoredReceiver.commit(.photoSaved(later))
        try await restoredReceiver.commit(.photoSaved(later))
        try await restored.reconcile()
        try verifyOneSaved(fixture, root: backup, calls: fixture.calls, writes: 1)
        XCTAssertEqual(fixture.calls.actual, consumed)
        let receipt = try XCTUnwrap(store(fixture.calls).read())
        XCTAssertEqual(receipt.consumedCaptureID, earlier.lastPathComponent)
        let sql = try XCTUnwrap(FilmRepository(rootURL: backup)
            .captureReceipt(filmID: fixture.film.id, captureID: later.lastPathComponent))
        XCTAssertEqual(sql.sequenceNumber, 1)
        try snapshot(fixture, root: backup, calls: fixture.calls, name: "empty-backup-after")
    }

    func testAuthoritativeExistingGrantPermutationsRecoverPendingBackupWithoutReceiptMutation() async throws {
        let fixture = try await Fixture()
        let photo = try fixture.photo()
        let owner = try TrialCoordinator(root: fixture.root, store: store(fixture.calls), checkpoint: {
            if $0 == .prepared { throw CompatibilityStop.boundary }
        })
        let receiver = try await owner.receiver(filmID: fixture.film.id)
        do { try await receiver.commit(.photoSaved(photo)); XCTFail("Expected prepared stop") }
        catch CompatibilityStop.boundary { }
        let operation = try XCTUnwrap(CaptureCommitJournal(root: fixture.root).pending(filmID: fixture.film.id).first)
        let deviceID = try XCTUnwrap(store(fixture.calls).read()).deviceID
        var records: [(String, Data)] = []
        // These are declared existing-item states under the ordinary read
        // contract, not arbitrary read overrides or physical restore evidence.
        for sameFilm in [false, true] {
            for sameCapture in [false, true] {
                for sameDate in [false, true] {
                    let record = DeviceTrialRecord(deviceID: deviceID,
                        consumedFilmID: sameFilm ? fixture.film.id : UUID(),
                        consumedAt: sameDate ? operation.savedAt : operation.savedAt.addingTimeInterval(-60),
                        consumedCaptureID: sameCapture ? operation.captureID : "earlier-capture")
                    records.append(("film-\(sameFilm)-capture-\(sameCapture)-date-\(sameDate)",
                                    try JSONEncoder().encode(record)))
                }
            }
        }
        let historical = DeviceTrialRecord(deviceID: deviceID, consumedFilmID: fixture.film.id,
            consumedAt: operation.savedAt.addingTimeInterval(-120))
        let historicalData = try JSONEncoder().encode(historical)
        records.append(("historical-no-capture", historicalData))
        var versionless = try XCTUnwrap(JSONSerialization.jsonObject(with: historicalData) as? [String: Any])
        versionless.removeValue(forKey: "schemaVersion")
        records.append(("versionless", try JSONSerialization.data(withJSONObject: versionless)))
        for used in [false, true] {
            records.append(("foreign-used-\(used)", try JSONEncoder().encode(DeviceTrialRecord(
                consumedFilmID: used ? UUID() : nil, consumedAt: used ? operation.savedAt : nil,
                consumedCaptureID: used ? "foreign-capture" : nil))))
        }
        for (name, data) in records {
            let root = fixture.directory.appendingPathComponent(name)
            try FileManager.default.copyItem(at: fixture.root, to: root)
            let calls = AuthoritativeReceiptCalls(actual: data)
            try snapshot(fixture, root: root, calls: calls, name: "\(name)-before")
            XCTAssertEqual(calls.read(service: "injected-only").data, calls.actual)
            let reopened = try TrialCoordinator(root: root, store: store(calls))
            try await reopened.reconcile()
            try await reopened.reconcile()
            try verifyOneSaved(fixture, root: root, calls: calls, writes: 0)
            XCTAssertEqual(calls.actual, data)
            try snapshot(fixture, root: root, calls: calls, name: "\(name)-after")
        }
        XCTAssertEqual(records.count, 12)
    }

    func testPendingBackupsBeforeAndAfterReceiptResolutionProjectOnce() async throws {
        for boundary in [TrialCommitCheckpoint.prepared, .receiptResolved] {
            let fixture = try await Fixture()
            let photo = try fixture.photo()
            let owner = try TrialCoordinator(root: fixture.root, store: store(fixture.calls), checkpoint: {
                if $0 == boundary { throw CompatibilityStop.boundary }
            })
            let receiver = try await owner.receiver(filmID: fixture.film.id)
            do { try await receiver.commit(.photoSaved(photo)); XCTFail("Expected boundary stop") }
            catch CompatibilityStop.boundary { }
            XCTAssertEqual(try FilmRepository(rootURL: fixture.root).film(id: fixture.film.id).savedCaptureCount, 0)
            let backup = fixture.directory.appendingPathComponent("PendingBackup-\(boundary)")
            try FileManager.default.copyItem(at: fixture.root, to: backup)
            try snapshot(fixture, root: backup, calls: fixture.calls, name: "before")
            let reopened = try TrialCoordinator(root: backup, store: store(fixture.calls))
            try await reopened.reconcile()
            try await reopened.reconcile()
            try verifyOneSaved(fixture, root: backup, calls: fixture.calls, writes: 1)
            XCTAssertEqual(try store(fixture.calls).read()?.consumedCaptureID, photo.lastPathComponent)
            try snapshot(fixture, root: backup, calls: fixture.calls, name: "after")
        }
    }

    private func store(_ calls: AuthoritativeReceiptCalls) -> KeychainDeviceTrialStore {
        KeychainDeviceTrialStore(service: "injected-only-existing-grant", calls: calls)
    }

    private func verifyOneSaved(_ fixture: Fixture, root: URL, calls: AuthoritativeReceiptCalls, writes: Int) throws {
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.film(id: fixture.film.id)
        XCTAssertEqual(film.savedCaptureCount, 1)
        XCTAssertEqual(film.remainingExposures, 26)
        XCTAssertEqual(film.captures.first?.revealState, .sealed)
        XCTAssertFalse(try repository.hasPendingCapture(filmID: film.id))
        XCTAssertEqual(calls.updates, writes)
        XCTAssertEqual(calls.adds, 0)
        let source = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertEqual(try VerifiedMedia.photo(at: source.url).sha256, source.record.sha256)
    }

    private func snapshot(_ fixture: Fixture, root: URL, calls: AuthoritativeReceiptCalls, name: String) throws {
        let repository = try FilmRepository(rootURL: root)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let film = try repository.film(id: fixture.film.id)
        try encoder.encode(film).write(to: fixture.directory.appendingPathComponent("\(name)-film.json"), options: .withoutOverwriting)
        try calls.actual.write(to: fixture.directory.appendingPathComponent("\(name)-actual.json"), options: .withoutOverwriting)
        try XCTUnwrap(calls.read(service: "injected-only").data)
            .write(to: fixture.directory.appendingPathComponent("\(name)-returned.json"), options: .withoutOverwriting)
        try encoder.encode(["updates": calls.updates, "adds": calls.adds, "saved": film.savedCaptureCount,
                            "pending": try repository.hasPendingCapture(filmID: film.id) ? 1 : 0])
            .write(to: fixture.directory.appendingPathComponent("\(name)-counts.json"), options: .withoutOverwriting)
    }

    @MainActor private struct Fixture {
        let directory: URL
        let root: URL
        let film: Film
        let calls: AuthoritativeReceiptCalls
        let photoBytes: Data

        init() async throws {
            #if os(iOS)
            let parent = URL.documentsDirectory
            #else
            let parent = FileManager.default.temporaryDirectory
            #endif
            directory = parent.appendingPathComponent("ReceiptCompatibility039/\(UUID())")
            root = directory.appendingPathComponent("App")
            calls = AuthoritativeReceiptCalls(actual: try JSONEncoder().encode(DeviceTrialRecord()))
            let store = KeychainDeviceTrialStore(service: "injected-only-existing-grant", calls: calls)
            let owner = try TrialCoordinator(root: root, store: store)
            film = try await owner.start(camera: CameraCatalog.disposable1990s, title: "Synthetic existing grant")
            var settings = RenderFixtureSettings.defaultExperimental
            settings.photoWidth = 160; settings.photoHeight = 120
            settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
            let fixtures = directory.appendingPathComponent("Fixtures")
            _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
            photoBytes = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
            print("RECEIPT_COMPATIBILITY039 \(directory.path)")
        }

        func photo() throws -> URL {
            let native = try CapturedMediaFiles(directory: directory.appendingPathComponent("NativeInput"))
            let id = UUID()
            try native.prepare(.init(id: id, mediaKind: .photo, createdAt: Date()))
            return try native.savePhoto(photoBytes, id: id)
        }
    }
}
