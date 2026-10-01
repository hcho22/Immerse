import Foundation
import NativeAdapters
import RenderFixtures
import XCTest

final class CapturedMediaFileTests: XCTestCase {
    func testReopenedJournalRecoversPhotoAndMovieInCaptureOrderUntilAcknowledged() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let staging = root.appendingPathComponent("staging")
        let files = try CapturedMediaFiles(directory: staging)
        let photoID = UUID(), movieID = UUID(), unusedID = UUID()
        let date = Date(timeIntervalSince1970: 1_000)
        try files.prepare(PendingCaptureRecord(id: photoID, mediaKind: .photo, createdAt: date))
        let data = try Data(contentsOf: root.appendingPathComponent(manifest.photo.relativePath))
        let photo = try files.savePhoto(data, id: photoID)
        try files.prepare(PendingCaptureRecord(id: movieID, mediaKind: .movie, createdAt: date.addingTimeInterval(1),
            orientation: .portrait, remainingSeconds: 10))
        try FileManager.default.copyItem(at: root.appendingPathComponent(manifest.movie.relativePath), to: files.movieDestination(id: movieID))
        try files.prepare(PendingCaptureRecord(id: unusedID, mediaKind: .photo, createdAt: date.addingTimeInterval(2)))
        let reopened = try CapturedMediaFiles(directory: staging)
        let recovered = try await reopened.recoveryEvents()
        XCTAssertEqual(recovered.count, 2)
        XCTAssertEqual(recovered.first, .photoSaved(photo))
        if case let .movieClipSaved(_, seconds, orientation) = recovered.last {
            XCTAssertEqual(seconds, manifest.movie.durationSeconds)
            XCTAssertEqual(orientation, .portrait)
        } else { XCTFail("Expected recovered Movie") }
        XCTAssertEqual(try CapturedMediaFiles.metadata(for: photo)?.createdAt, date)
        XCTAssertEqual(try reopened.pendingRecords().count, 2)
        XCTAssertEqual(try Data(contentsOf: photo), data)
        for event in recovered { try reopened.removeCommittedFile(for: event) }
        XCTAssertTrue(try reopened.pendingRecords().isEmpty)
        let retry = try await reopened.recoveryEvents()
        XCTAssertTrue(retry.isEmpty)
    }

    func testInvalidPendingMovieIsRetainedAndBlocksSuccessfulRecovery() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try CapturedMediaFiles(directory: root)
        let id = UUID()
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: .movie, orientation: .landscape, remainingSeconds: 200))
        let data = Data("unfinished movie".utf8)
        try data.write(to: files.movieDestination(id: id))
        do { _ = try await files.recoveryEvents(); XCTFail("Must not acknowledge undecodable media") }
        catch { }
        XCTAssertEqual(try files.pendingRecords().count, 1)
        XCTAssertEqual(try Data(contentsOf: files.movieDestination(id: id)), data)
    }

    func testRealPhotoBytesAreRetainedUnchangedUntilCommitCleanup() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let data = try Data(contentsOf: root.appendingPathComponent(manifest.photo.relativePath))
        let staging = root.appendingPathComponent("staging")
        let files = try CapturedMediaFiles(directory: staging)
        let id = UUID()
        let saved = try files.savePhoto(data, id: id)
        XCTAssertEqual(try Data(contentsOf: saved), data)
        XCTAssertThrowsError(try files.savePhoto(data, id: id))
        XCTAssertEqual(try Data(contentsOf: saved), data)
        XCTAssertEqual(try staging.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, false)
        try files.removeCommittedFile(for: .photoSaved(saved))
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))
    }

    func testMalformedPhotoCannotBecomeASavedCapture() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try CapturedMediaFiles(directory: root)
        XCTAssertThrowsError(try files.savePhoto(Data("not-an-image".utf8), id: UUID()))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testMissingStagingDirectoryBehavesAsAlreadyEmptyDuringPrivacyCleanup() async throws {
        let root = makeRoot()
        let files = try CapturedMediaFiles(directory: root)
        try FileManager.default.removeItem(at: root)

        XCTAssertTrue(try files.pendingRecords().isEmpty)
        let recovery = try await files.recoveryEvents()
        XCTAssertTrue(recovery.isEmpty)
        try files.removeUncommitted(id: UUID())
        try files.removeCommittedFile(for: .photoSaved(root.appendingPathComponent("missing.photo")))
    }

    func testExistingUninspectableStagingPathStillThrowsInsteadOfPretendingEmpty() throws {
        let root = makeRoot()
        let files = try CapturedMediaFiles(directory: root)
        try FileManager.default.removeItem(at: root)
        try Data("not a staging directory".utf8).write(to: root, options: .withoutOverwriting)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try files.pendingRecords())
    }

    func testCommittedCleanupRejectsOutsideStagingFilesAndLeavesThemUntouched() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = root.appendingPathComponent("staging")
        let files = try CapturedMediaFiles(directory: staging)
        let outside = root.appendingPathComponent("outside.photo")
        let bytes = Data("outside synthetic file".utf8)
        try bytes.write(to: outside)

        XCTAssertThrowsError(try files.removeCommittedFile(for: .photoSaved(outside))) { error in
            XCTAssertEqual(error as? NativeCaptureError, .invalidMedia)
        }
        XCTAssertEqual(try Data(contentsOf: outside), bytes)
    }

    func testDecodedMoviePreservesFractionalDurationAndIndependentPortraitClip() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let files = try CapturedMediaFiles(directory: root.appendingPathComponent("staging"))
        let id = UUID()
        let destination = files.movieDestination(id: id)
        try FileManager.default.copyItem(at: root.appendingPathComponent(manifest.movie.relativePath), to: destination)
        let event = try await files.movieSavedEvent(id: id, orientation: .portrait, remainingSeconds: 10)
        guard case let .movieClipSaved(url, seconds, orientation) = event else {
            return XCTFail("Expected validated Movie file")
        }
        XCTAssertEqual(url, destination)
        XCTAssertEqual(seconds, manifest.movie.durationSeconds, accuracy: 0.000001)
        XCTAssertGreaterThan(seconds, 0)
        XCTAssertLessThan(seconds, 1)
        XCTAssertEqual(orientation, .portrait)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        do {
            _ = try await files.movieSavedEvent(id: id, orientation: .portrait, remainingSeconds: 0.1)
            XCTFail("Over-budget footage must never be committed")
        } catch { XCTAssertEqual(error as? NativeCaptureError, .invalidMedia) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testUnfinishedMovieIsRetainedWithoutReportingSaveSuccess() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try CapturedMediaFiles(directory: root)
        let id = UUID()
        let url = files.movieDestination(id: id)
        let partial = Data("unfinished-movie".utf8)
        try partial.write(to: url)
        do {
            _ = try await files.movieSavedEvent(id: id, orientation: .landscape, remainingSeconds: 200)
            XCTFail("Incomplete file must not become a save event")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: url), partial)
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NativeCaptureFiles-\(UUID())")
    }

    private func fixtures(at root: URL) async throws -> RenderFixtureManifest {
        try await RenderFixtureGenerator.writeFixtures(
            outputDirectory: root,
            settings: RenderFixtureSettings(
                photoWidth: 64, photoHeight: 64, movieWidth: 64, movieHeight: 64,
                movieFrameRate: 24, movieDurationSeconds: 0.5, movieOrientation: .landscape
            )
        )
    }
}
