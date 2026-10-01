import CapturePipeline
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
        let receiver = try CapturePipelineReceiver(filmID: film.id, repositoryURL: root)
        try await receiver.commit(.photoSaved(photo))
        // Simulate termination after DB commit, before the native staging acknowledgement.
        let reopened = try CapturePipelineReceiver(filmID: film.id, repositoryURL: root)
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
}
