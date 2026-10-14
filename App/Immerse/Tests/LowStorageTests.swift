import EntitlementCore
import FilmDomain
import FilmPersistence
import NativeAdapters
import Synchronization
import XCTest
@testable import Immerse

/// The low-storage warning (DEC-12) with the free-space reading set by the test: it shows before each step that
/// needs space only while the reading is under 2 GB, a reading that fails shows none, and the Journal reads again
/// as it refreshes. The screens themselves are covered by `LowStorageUITests` and the populated Journal harness.
@MainActor
final class LowStorageTests: XCTestCase {
    private static let justUnder: Int64 = 1_999_999_999
    private static let exactly: Int64 = 2_000_000_000
    private static let justOver: Int64 = 2_000_000_001

    func testWarningShowsBeforeEachStepOnlyBelowTwoGigabytes() async {
        for step in LowStorageStep.allCases {
            let reading = SetFreeSpace(bytes: Self.justUnder)
            let check = LowStorageCheck(reader: reading)
            XCTAssertNil(check.warning(for: step), "No warning before the first reading")
            await check.refresh()
            XCTAssertEqual(check.warning(for: step), LowStorageCopy.warning(for: step), "Just under 2 GB, \(step)")
            reading.bytes = Self.exactly
            await check.refresh()
            XCTAssertNil(check.warning(for: step), "Exactly 2 GB, \(step)")
            reading.bytes = Self.justOver
            await check.refresh()
            XCTAssertNil(check.warning(for: step), "Just over 2 GB, \(step)")
            reading.bytes = 0
            await check.refresh()
            XCTAssertNotNil(check.warning(for: step), "Nothing free, \(step)")
        }
    }

    func testAReadingThatFailsShowsNoWarningAndClearsAnEarlierOne() async {
        for step in LowStorageStep.allCases {
            let reading = SetFreeSpace(bytes: nil)
            let check = LowStorageCheck(reader: reading)
            await check.refresh()
            XCTAssertNil(check.warning(for: step), "A failed reading is not low, \(step)")
            reading.bytes = Self.justUnder
            await check.refresh()
            XCTAssertNotNil(check.warning(for: step))
            reading.bytes = nil
            await check.refresh()
            XCTAssertNil(check.warning(for: step), "The app does not keep stating what it can no longer read, \(step)")
        }
    }

    func testTheWordsNameTheCauseWhatIsUnaffectedAndWhatToDo() {
        XCTAssertEqual(LowStorageCopy.warning(for: .capture),
                       "This iPhone has less than 2 GB free, so a capture may not save. A capture that does not save uses no exposures or time, and saved captures are unchanged. Free space in iPhone Settings.")
        XCTAssertEqual(LowStorageCopy.warning(for: .development),
                       "This iPhone has less than 2 GB free, so Development may not finish. Saved captures are unchanged, and Development can be resumed. Free space in iPhone Settings.")
    }

    func testJournalReadsFreeSpaceAgainEachTimeItRefreshes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LowStorage-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let reading = SetFreeSpace(bytes: Self.justUnder)
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true), freeSpace: reading)
        XCTAssertFalse(model.storage.isLow, "Nothing is stated before a reading")
        model.refresh()
        try await waitUntil { model.storage.isLow }
        // Space is freed in iPhone Settings and the app comes back, which refreshes the Journal.
        reading.bytes = Self.exactly
        model.refresh()
        try await waitUntil { !model.storage.isLow }
    }

    func testFilmScreenWarnsBeforeCapturesThenBeforeDevelopmentAndNeverOnceDeveloped() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LowStorage-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true), freeSpace: SetFreeSpace(bytes: 0))
        await model.recoverAtLaunch()
        let roll = try model.repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Roll", access: .subscription)
        XCTAssertEqual(roll.stepNeedingSpace, .capture, "An open Film takes captures")
        let source = try syntheticPhoto()
        try model.repository.savePhotoCapture(filmID: roll.id, sourceData: source)
        XCTAssertEqual(try model.repository.film(id: roll.id).stepNeedingSpace, .capture)
        _ = try model.repository.completeEarly(filmID: roll.id, confirmedCaptureCount: 1)
        XCTAssertEqual(try model.repository.film(id: roll.id).stepNeedingSpace, .development, "A complete Film awaits Development")
        try model.chooseOriginals(roll.id, sequences: [1], export: false)
        try await model.develop(roll.id)
        XCTAssertNil(try model.repository.film(id: roll.id).stepNeedingSpace, "A developed Film needs no space")

        let pack = try model.repository.createFilm(camera: CameraCatalog.instant1970s, title: "Pack", access: .subscription)
        XCTAssertEqual(pack.stepNeedingSpace, .capture)
    }

    /// The reading the app really uses, on the volume that holds its Films. The simulator reports its Mac's volume.
    func testTheAppsOwnReadingIsAvailable() throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        XCTAssertGreaterThan(try VolumeFreeSpaceReader(url: support).availableBytes(), 0)
    }

    func testDebugReadingComesOnlyFromItsLaunchArgument() throws {
        let suite = "LowStorageTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(DebugFreeSpace(defaults: defaults), "Without the argument the app reads the iPhone")
        defaults.set("1999999999", forKey: DebugFreeSpace.defaultsKey)
        XCTAssertEqual(try DebugFreeSpace(defaults: defaults)?.availableBytes(), Self.justUnder)
        defaults.set("unreadable", forKey: DebugFreeSpace.defaultsKey)
        let unreadable = try XCTUnwrap(DebugFreeSpace(defaults: defaults))
        XCTAssertThrowsError(try unreadable.availableBytes())
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertTrue(condition())
    }
}

/// A free-space reading the test sets; nil is a reading that fails.
private final class SetFreeSpace: FreeSpaceReading, Sendable {
    private let state: Mutex<Int64?>

    init(bytes: Int64?) { state = Mutex(bytes) }

    var bytes: Int64? {
        get { state.withLock { $0 } }
        set { state.withLock { $0 = newValue } }
    }

    func availableBytes() throws -> Int64 {
        guard let bytes else { throw FreeSpaceError.noReading }
        return bytes
    }
}
