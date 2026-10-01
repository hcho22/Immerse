import EntitlementCore
import FilmDomain
import FilmPersistence
import Foundation
import Security
import XCTest
@testable import ReceiptScenarioHarness

final class ReceiptScenarioTests: XCTestCase {
    func testInvalidMediaDoesNotConsumeOrProject() async throws {
        let scenario = try make(fault: .invalidMedia)
        try await scenario.prepare()
        try await rejected(PersistenceError.invalidMedia) { try await scenario.commit() }
        let result = try await scenario.inventory()
        XCTAssertEqual(result.films.first?.savedCaptureCount, 0)
        XCTAssertEqual(result.films.first?.remainingExposures, 27)
        XCTAssertEqual(result.underlyingRecord?.isConsumed, false)
        XCTAssertNil(result.sqlReceipt)
        XCTAssertFalse(result.files.keys.contains { $0.contains("/Commit/") })
    }

    func testLostReplyMatchingReadbackAndUnknownReentry() async throws {
        for fault in [ReceiptFault.lostReply, .unknownApplied, .unknownNotApplied] {
            let scenario = try make(camera: .super8HomeMovie, fault: fault)
            try await scenario.prepare()
            if fault == .lostReply { try await scenario.commit() }
            else {
                try await rejectedKeychain(status: errSecInteractionNotAllowed) { try await scenario.commit() }
                let pending = try await scenario.inventory()
                XCTAssertTrue(pending.pending)
                assertPendingBytes(pending)
                XCTAssertEqual(pending.films.first?.savedCaptureCount, 0)
                XCTAssertEqual(pending.films.first?.remainingMovieSeconds, 200)
                XCTAssertEqual(pending.underlyingRecord?.isConsumed, fault == .unknownApplied)
                XCTAssertNotEqual(pending.logicalRead, "unused")
                let reopened = try ReceiptScenario(configuration: scenario.configuration)
                try await rejectedKeychain(status: errSecInteractionNotAllowed) { try await reopened.recover() }
                try await rejectedKeychain(status: errSecInteractionNotAllowed) { try await reopened.attemptSecondLoad() }
                try await reopened.resolveInjectedFault()
                try await reopened.recover()
                try await reopened.recover()
                try await reopened.commit()
                assertSaved(try await reopened.inventory())
            }
            assertSaved(try await scenario.inventory())
        }
    }

    func testProjectionFailureReentryAcrossPhotoAndBothMoviePackages() async throws {
        for camera in [CameraID.disposable1990s, .super8HomeMovie, .cinema16mm] {
            for fault in [ReceiptFault.beforeMove, .afterMove, .afterCommit] {
                let scenario = try make(camera: camera, fault: fault)
                try await scenario.prepare()
                try await rejected(PersistenceError.simulatedFailure(fault.projection!)) { try await scenario.commit() }
                let pending = try await scenario.inventory()
                XCTAssertEqual(pending.underlyingRecord?.isConsumed, true)
                XCTAssertEqual(pending.films.first?.savedCaptureCount, fault == .afterCommit ? 1 : 0)
                XCTAssertTrue(pending.pending)
                assertPendingBytes(pending)
                let reopened = try ReceiptScenario(configuration: scenario.configuration)
                try await reopened.recover()
                try await reopened.recover()
                try await reopened.commit()
                assertSaved(try await reopened.inventory())
                do { try await reopened.prepare(); XCTFail("Cannot prepare over a retained history") }
                catch HarnessError.alreadyPrepared { }
            }
        }
    }

    func testDeleteUnknownPendingThenStaleCallbackCannotResurrect() async throws {
        let scenario = try make(fault: .unknownApplied)
        try await scenario.prepare()
        try await rejectedKeychain(status: errSecInteractionNotAllowed) { try await scenario.commit() }
        let before = try await scenario.inventory()
        XCTAssertTrue(before.pending)
        try await scenario.deleteFilm()
        do { try await scenario.staleCallback(); XCTFail("Stale callback accepted") }
        catch PersistenceError.filmNotFound { }
        let after = try await scenario.inventory()
        XCTAssertTrue(after.films.isEmpty)
        XCTAssertFalse(after.stagingExists)
        XCTAssertEqual(after.underlyingRecord, before.underlyingRecord)
        XCTAssertTrue(after.files.keys.allSatisfy { !$0.hasPrefix("Media/") && !$0.hasPrefix("Staging/") })
        try await scenario.resolveInjectedFault()
        let reopened = try ReceiptScenario(configuration: scenario.configuration)
        try await reopened.recover()
        try await rejected(EntitlementDenial.currentDeviceTrialConsumed) { try await reopened.attemptSecondLoad() }
        let reopenedResult = try await reopened.inventory()
        XCTAssertTrue(reopenedResult.films.isEmpty)
    }

    func testPausedDeleteRequestCompletesBeforeLateCallback() async throws {
        let scenario = try make(camera: .cinema16mm, boundary: "receiptResolved")
        try await scenario.prepare()
        let save = Task { try await scenario.commit() }
        try await waitPaused(scenario)
        let paused = try await scenario.inventory()
        XCTAssertEqual(paused.films.first?.savedCaptureCount, 0)
        assertPendingBytes(paused)
        let deletion = Task { try await scenario.deleteFilm() }
        let deadline = Date().addingTimeInterval(5)
        while !(try String(contentsOf: scenario.evidence.directory.appendingPathComponent("events.jsonl"), encoding: .utf8)).contains("delete-requested") {
            guard Date() < deadline else { throw HarnessError.busy }
            try await Task.sleep(for: .milliseconds(10))
        }
        try await scenario.release()
        try await save.value
        try await deletion.value
        do { try await scenario.staleCallback(); XCTFail("Stale callback accepted") }
        catch PersistenceError.filmNotFound { }
        let result = try await scenario.inventory()
        XCTAssertTrue(result.films.isEmpty)
        XCTAssertFalse(result.stagingExists)
        XCTAssertEqual(result.underlyingRecord?.isConsumed, true)
    }

    func testCorruptPreparedMediaFailsClosedAndRemainsForInspection() async throws {
        let scenario = try make(fault: .corruptPending, boundary: "prepared")
        try await scenario.prepare()
        let save = Task { try await scenario.commit() }
        try await waitPaused(scenario)
        assertPendingBytes(try await scenario.inventory())
        try await scenario.corruptPending()
        try await scenario.release()
        try await rejected(PersistenceError.invalidMedia) { try await save.value }
        try await rejected(PersistenceError.invalidMedia) { try await scenario.recover() }
        let result = try await scenario.inventory()
        XCTAssertTrue(result.pending)
        XCTAssertEqual(result.films.first?.savedCaptureCount, 0)
        XCTAssertEqual(result.underlyingRecord?.isConsumed, false)
        XCTAssertNil(result.sqlReceipt)
    }

    func testLegacyOutboxIncludingDeletedFilmNeverRefunds() async throws {
        for fault in [ReceiptFault.legacyPending, .legacyDeleted] {
            let scenario = try make(fault: fault)
            try await scenario.prepare()
            let before = try await scenario.inventory()
            XCTAssertNil(before.underlyingRecord?.schemaVersion)
            XCTAssertEqual(before.outboxFilmIDs.count, 1)
            XCTAssertEqual(before.underlyingRecord?.isConsumed, false)
            try await scenario.recover()
            try await scenario.recover()
            let after = try await scenario.inventory()
            XCTAssertTrue(after.outboxFilmIDs.isEmpty)
            XCTAssertEqual(after.underlyingRecord?.isConsumed, true)
            XCTAssertNil(after.underlyingRecord?.consumedCaptureID, "Legacy migration must not invent a receipt")
            XCTAssertEqual(after.films.count, fault == .legacyDeleted ? 0 : 1)
            XCTAssertEqual(after.underlyingRecord?.deviceID, before.underlyingRecord?.deviceID)
        }
    }

    func testAdapterRejectsForeignNamespaceWithoutNativeDispatch() throws {
        let scenario = try make()
        let calls = try RecordedReceiptCalls(configuration: scenario.configuration, evidence: scenario.evidence)
        XCTAssertEqual(calls.read(service: "com.immerse.device-trial.v1").status, errSecParam)
        XCTAssertEqual(calls.add(service: "com.immerse.trial-keychain-probe", data: Data()).description, errSecParam.description)
        XCTAssertEqual(calls.update(service: "wrong", data: Data()), errSecParam)
    }

    private func make(camera: CameraID = .disposable1990s, backend: ReceiptBackend = .injectedFile,
                      fault: ReceiptFault = .none, boundary: String = "none") throws -> ReceiptScenario {
        try ReceiptScenario(configuration: .init(runID: UUID(), cameraID: camera, backend: backend, fault: fault, pauseAt: boundary))
    }
    private func waitPaused(_ scenario: ReceiptScenario) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !(await scenario.phase()).hasPrefix("paused-") {
            guard Date() < deadline else { throw HarnessError.notPaused }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    private func rejected<E: Error & Equatable>(_ expected: E, _ action: () async throws -> Void) async throws {
        do { try await action(); XCTFail("Operation unexpectedly succeeded") }
        catch { XCTAssertEqual(error as? E, expected, "Unexpected rejection: \(error)") }
    }
    private func rejectedKeychain(status: OSStatus, _ action: () async throws -> Void) async throws {
        do { try await action(); XCTFail("Operation unexpectedly succeeded") }
        catch { XCTAssertEqual((error as? TrialKeychainError)?.status, status, "Unexpected rejection: \(error)") }
    }
    private func assertSaved(_ inventory: ScenarioInventory, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(inventory.films.count, 1, file: file, line: line)
        XCTAssertEqual(inventory.films.first?.savedCaptureCount, 1, file: file, line: line)
        XCTAssertEqual(inventory.films.first?.captures.first?.sequenceNumber, 1, file: file, line: line)
        XCTAssertEqual(inventory.films.first?.captures.first?.savedAt, inventory.manifest.savedAt, file: file, line: line)
        XCTAssertEqual(inventory.films.first?.captures.first?.revealState, .sealed, file: file, line: line)
        XCTAssertEqual(inventory.sourceMatches, true, file: file, line: line)
        XCTAssertGreaterThan(inventory.decodedFrames ?? 0, 0, file: file, line: line)
        XCTAssertFalse(inventory.pending, file: file, line: line)
        XCTAssertTrue(inventory.outboxFilmIDs.isEmpty, file: file, line: line)
        XCTAssertEqual(inventory.underlyingRecord?.consumedCaptureID, inventory.sqlReceipt?.captureID, file: file, line: line)
        XCTAssertEqual(inventory.underlyingRecord?.isConsumed, true, file: file, line: line)
        if inventory.configuration.camera.medium == .movie {
            XCTAssertEqual(inventory.films.first?.movieOrientation, .portrait, file: file, line: line)
            XCTAssertEqual(inventory.films.first?.consumedMovieSeconds, inventory.manifest.duration, file: file, line: line)
            if let duration = inventory.manifest.duration {
                XCTAssertEqual(inventory.films.first?.captures.first?.kind, .movieClip(seconds: duration, orientation: .landscape), file: file, line: line)
            }
        } else { XCTAssertEqual(inventory.films.first?.remainingExposures, 26, file: file, line: line) }
        XCTAssertEqual(inventory.underlyingRecord?.consumedFilmID, inventory.manifest.filmID, file: file, line: line)
        XCTAssertEqual(inventory.underlyingRecord?.consumedAt, inventory.manifest.savedAt, file: file, line: line)
    }
    private func assertPendingBytes(_ inventory: ScenarioInventory, file: StaticString = #filePath, line: UInt = #line) {
        guard let film = inventory.manifest.filmID, let source = inventory.manifest.sourcePath else {
            return XCTFail("Pending identity absent", file: file, line: line)
        }
        let key = "Staging/\(film)/Commit/\(URL(fileURLWithPath: source).lastPathComponent)"
        XCTAssertEqual(inventory.files[key], inventory.manifest.sourceHash, file: file, line: line)
        XCTAssertNotNil(inventory.files[key + ".json"], file: file, line: line)
    }
}
