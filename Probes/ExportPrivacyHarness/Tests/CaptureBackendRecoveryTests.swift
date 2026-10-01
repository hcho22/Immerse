import Foundation
import NativeAdapters
import RenderFixtures
import XCTest

final class CaptureBackendRecoveryTests: XCTestCase {
    func testPrivacyCancelBeforeRecoveryDeletesStagedFilesWithoutCommit() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let photo = try await fixturePhoto(at: root)
        let staging = root.appendingPathComponent("Staging")
        let files = try CapturedMediaFiles(directory: staging)
        let photoID = UUID()
        let movieID = UUID()
        let savedPhoto = try files.savePhoto(Data(contentsOf: photo), id: photoID)
        try files.prepare(PendingCaptureRecord(id: movieID, mediaKind: .movie, orientation: .landscape, remainingSeconds: 200))
        let partialMovie = files.movieDestination(id: movieID)
        try Data("partial synthetic movie".utf8).write(to: partialMovie)
        let committer = RecordingCaptureCommitter()
        let backend = try AVFoundationCaptureBackend(stagingDirectory: staging, committer: committer)

        try await backend.cancelForPrivacy()

        XCTAssertTrue(try files.pendingRecords().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedPhoto.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: partialMovie.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: staging.path).isEmpty)
        let events = await committer.events
        let phase = await backend.phase
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(phase, .interrupted)
    }

    func testPrivacyCancelWaitsForInFlightRecoveryAndLeavesNoRetry() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let photo = try await fixturePhoto(at: root)
        let staging = root.appendingPathComponent("Staging")
        let files = try CapturedMediaFiles(directory: staging)
        let savedPhoto = try files.savePhoto(Data(contentsOf: photo), id: UUID())
        let committer = RecordingCaptureCommitter(holdCommits: true)
        let backend = try AVFoundationCaptureBackend(stagingDirectory: staging, committer: committer)
        let cancelState = CompletionState()

        let recovery = Task { try await backend.recoverPendingCaptures() }
        try await committer.waitForEntry()

        do {
            try await backend.recoverPendingCaptures()
            XCTFail("Concurrent recovery must be rejected while a staged commit is in flight")
        } catch {
            XCTAssertEqual(error as? NativeCaptureError, .busy)
        }

        let cancel = Task {
            try await backend.cancelForPrivacy()
            await cancelState.markFinished()
        }
        try await Task.sleep(for: .milliseconds(50))
        let finishedWhileCommitHeld = await cancelState.finished
        XCTAssertFalse(finishedWhileCommitHeld, "Privacy cancellation must not acknowledge before the in-flight recovery resolves")

        await committer.release()
        try await recovery.value
        try await cancel.value

        let events = await committer.events
        XCTAssertEqual(events, [.photoSaved(savedPhoto)])
        XCTAssertTrue(try files.pendingRecords().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedPhoto.path))
        let retryEvents = try await CapturedMediaFiles(directory: staging).recoveryEvents()
        XCTAssertTrue(retryEvents.isEmpty)
    }

    private func temporaryRoot() -> URL {
        URL.documentsDirectory.appendingPathComponent("CaptureBackendRecovery-\(UUID())")
    }

    private func fixturePhoto(at root: URL) async throws -> URL {
        let manifest = try await RenderFixtureGenerator.writeFixtures(
            outputDirectory: root.appendingPathComponent("Fixtures"),
            settings: RenderFixtureSettings(
                photoWidth: 64, photoHeight: 64, movieWidth: 64, movieHeight: 64,
                movieFrameRate: 24, movieDurationSeconds: 0.5, movieOrientation: .landscape
            )
        )
        return root.appendingPathComponent("Fixtures").appendingPathComponent(manifest.photo.relativePath)
    }
}

private actor RecordingCaptureCommitter: CaptureSaveCommitting {
    private(set) var events: [CaptureSaveEvent] = []
    private let holdCommits: Bool
    private var entered = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(holdCommits: Bool = false) {
        self.holdCommits = holdCommits
    }

    func commit(_ event: CaptureSaveEvent) async throws {
        events.append(event)
        entered = true
        if holdCommits {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
    }

    func waitForEntry() async throws {
        let deadline = Date().addingTimeInterval(5)
        while !entered {
            guard Date() < deadline else { throw CocoaError(.executableRuntimeMismatch) }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor CompletionState {
    private(set) var finished = false
    func markFinished() { finished = true }
}
