import Foundation
import NativeAdapters
import RenderFixtures
import XCTest

final class CapturedMediaFileTests: XCTestCase {
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
        XCTAssertEqual(try staging.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
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
