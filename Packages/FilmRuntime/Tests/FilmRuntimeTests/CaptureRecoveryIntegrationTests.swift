import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderFixtures
import XCTest

final class CaptureRecoveryIntegrationTests: XCTestCase {
    func testNativeJournalReopenPreservesDateAndLostAcknowledgementDoesNotDebitTwice() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureRecoveryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        let data = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        let staging = try repository.captureStagingDirectory(filmID: film.id)
        let files = try CapturedMediaFiles(directory: staging)
        let id = UUID(), date = Date(timeIntervalSince1970: 5_000)
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: .photo, createdAt: date))
        let photo = try files.savePhoto(data, id: id)
        let store = MemoryDeviceStore()
        let receiver = try await TrialCoordinator(root: root, store: store).receiver(filmID: film.id)
        try await receiver.commit(.photoSaved(photo))
        // Simulate termination after DB commit, before the native staging acknowledgement.
        let reopened = try await TrialCoordinator(root: root, store: store).receiver(filmID: film.id)
        for event in try await CapturedMediaFiles(directory: staging).recoveryEvents() { try await reopened.commit(event) }
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
        XCTAssertEqual(try repository.film(id: film.id).captures.first?.savedAt, date)
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: film.id)
        try await processor.discard(filmID: film.id, sequence: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photo.path))
        XCTAssertTrue(try files.pendingRecords().isEmpty)
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        try await processor.deleteFilm(filmID: film.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
    }

    func testFinalClipRecordingExactlyTheRemainingFramesCompletesTheFilmInsteadOfBlockingIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureRecoveryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await RenderFixtureGenerator.writeFixtures(
            outputDirectory: root.appendingPathComponent("Fixtures"),
            settings: RenderFixtureSettings(photoWidth: 64, photoHeight: 48, movieWidth: 64, movieHeight: 48,
                movieFrameRate: MovieFrames.perSecond, movieDurationSeconds: MovieFrames.seconds(17),
                movieOrientation: .landscape))
        let clip = root.appendingPathComponent("Fixtures").appendingPathComponent(manifest.movie.relativePath)
        let finalFrames = try XCTUnwrap(MovieFrames.count(seconds: manifest.movie.durationSeconds))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.super8HomeMovie, title: "Synthetic reel",
                                             movieOrientation: .landscape)
        try repository.saveMovieClip(filmID: film.id, sourceData: Data(contentsOf: clip),
                                     durationSeconds: MovieFrames.seconds(6_000 - finalFrames), orientation: .landscape)
        let budget = try XCTUnwrap(repository.film(id: film.id).remainingMovieFrames)
        XCTAssertEqual(budget, finalFrames)
        XCTAssertGreaterThan(manifest.movie.durationSeconds, 200 - MovieFrames.seconds(6_000 - finalFrames),
                             "The final clip's seconds exceed the seconds left, as summed durations once required")

        // Stage the final clip exactly as the capture backend leaves it before its commit.
        let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
        let id = UUID()
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: .movie, orientation: .portrait, remainingFrames: budget))
        try FileManager.default.copyItem(at: clip, to: files.movieDestination(id: id))
        try await TrialCoordinator(root: root, store: MemoryDeviceStore()).recoverSavedCaptures(filmID: film.id)

        let full = try repository.film(id: film.id)
        XCTAssertEqual(full.savedCaptureCount, 2)
        XCTAssertEqual(full.remainingMovieFrames, 0)
        XCTAssertEqual(full.completionState, .capacityFull)
        XCTAssertTrue(full.canStartDevelopment)
        XCTAssertTrue(try files.pendingRecords().isEmpty)
        XCTAssertFalse(try repository.hasPendingCapture(filmID: film.id))
    }
}
