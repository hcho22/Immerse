import Foundation
@testable import NativeAdapters
import XCTest

final class CaptureOperationTests: XCTestCase {
    func testFailedPersistenceRetainsCaptureAndPreventsRecaptureOrLensSwitchUntilRetryCommits() throws {
        var coordinator = CaptureOperationCoordinator()
        let id = try coordinator.begin(.photo)
        let event = CaptureSaveEvent.photoSaved(URL(fileURLWithPath: "/synthetic/\(id).photo"))
        XCTAssertTrue(coordinator.stage(event, id: id))
        _ = try coordinator.beginCommit()
        XCTAssertThrowsError(try coordinator.beginCommit())
        coordinator.commitFailed(id: id)

        XCTAssertThrowsError(try coordinator.requireIdle())
        XCTAssertThrowsError(try coordinator.begin(.photo))
        XCTAssertEqual(coordinator.pendingSave, event)
        let retry = try coordinator.beginCommit()
        XCTAssertEqual(retry.0, id)
        XCTAssertEqual(retry.1, event)

        coordinator.finish(id: id)
        XCTAssertNoThrow(try coordinator.requireIdle())
        XCTAssertNil(coordinator.pendingSave)
    }

    func testInterruptionDuringRecordingSalvagesPendingSaveButNeverRestartsRecording() throws {
        var coordinator = CaptureOperationCoordinator()
        let id = try coordinator.begin(.movie)
        coordinator.interrupt()
        XCTAssertEqual(coordinator.phase, .savingMovieClip)
        let event = CaptureSaveEvent.movieClipSaved(
            url: URL(fileURLWithPath: "/synthetic/\(id).mov"), durationSeconds: 0.375, orientation: .portrait
        )
        XCTAssertTrue(coordinator.stage(event, id: id))
        _ = try coordinator.beginCommit()
        coordinator.finish(id: id)
        XCTAssertEqual(coordinator.phase, .interrupted)
        XCTAssertThrowsError(try coordinator.begin(.movie))
        coordinator.resumeSession()
        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertNil(coordinator.operationID)
    }

    func testLateAndDuplicateCallbacksCannotReplaceAnotherCaptureOrCommitTwice() throws {
        var coordinator = CaptureOperationCoordinator()
        let first = try coordinator.begin(.photo)
        let event = CaptureSaveEvent.photoSaved(URL(fileURLWithPath: "/synthetic/first.photo"))
        XCTAssertTrue(coordinator.stage(event, id: first))
        XCTAssertFalse(coordinator.stage(event, id: first))
        coordinator.finish(id: first)
        let second = try coordinator.begin(.photo)
        XCTAssertFalse(coordinator.stage(event, id: first))
        coordinator.finish(id: first)
        XCTAssertEqual(coordinator.operationID, second)
        XCTAssertEqual(coordinator.phase, .savingPhoto)
    }
}
