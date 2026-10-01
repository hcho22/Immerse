import FilmDomain
import FilmPersistence
import Foundation
import RenderFixtures
import XCTest

final class SourceCleanupTests: XCTestCase {
    func testCompletedRollAcceptsOriginalChoiceBeforeDevelopmentWithoutRevealingSources() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("sealed source".utf8))
        XCTAssertThrowsError(try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false))
        try repository.completeEarly(filmID: film.id)
        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false)

        let reopened = try FilmRepository(rootURL: root)
        XCTAssertEqual(try reopened.originalDisposition(filmID: film.id, sequenceNumber: 1), .declined)
        XCTAssertEqual(try reopened.film(id: film.id).developmentState, .notStarted)
        XCTAssertEqual(try reopened.film(id: film.id).captures.map(\.revealState), [.sealed])
        XCTAssertThrowsError(try reopened.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertThrowsError(try reopened.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1))
        XCTAssertTrue(try reopened.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testNondecodableMasterAndSealedOriginalCannotAuthorizeCleanupOrExport() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("original".utf8))
        XCTAssertThrowsError(try repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertThrowsError(try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false))
        try repository.completeEarly(filmID: film.id)
        _ = try repository.beginDevelopment(filmID: film.id)
        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false)
        try repository.writeDevelopedMaster(filmID: film.id, sequenceNumber: 1, data: Data("not an image".utf8))
        let master = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .master))
        XCTAssertThrowsError(try VerifiedMedia.photo(at: master.url))
        XCTAssertThrowsError(try repository.finishVerifiedDevelopment(filmID: film.id, verifiedMedia: []))
        XCTAssertThrowsError(try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testExportRequestedCannotDeleteSourceUntilMatchingSuccessfulReceiptAndDecode() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        let data = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        try repository.savePhotoCapture(filmID: film.id, sourceData: data)
        try repository.writeDevelopedMaster(filmID: film.id, sequenceNumber: 1, data: data)
        try revealTestInstant(repository, filmID: film.id)
        let master = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .master))
        let verification = try VerifiedMedia.photo(at: master.url)
        XCTAssertThrowsError(try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1, verifiedMedia: [verification]))
        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: true)
        XCTAssertThrowsError(try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1, verifiedMedia: [verification])) {
            XCTAssertEqual($0 as? PersistenceError, .originalExportPending)
        }
        XCTAssertThrowsError(try repository.recordSuccessfulOriginalExport(
            filmID: film.id, sequenceNumber: 1, sourceSHA256: "wrong", photosIdentifier: "synthetic-receipt"
        ))
        XCTAssertThrowsError(try repository.recordSuccessfulOriginalExport(
            filmID: film.id, sequenceNumber: 1, sourceSHA256: verification.sha256, photosIdentifier: ""
        ))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        try repository.recordSuccessfulOriginalExport(
            filmID: film.id, sequenceNumber: 1, sourceSHA256: verification.sha256, photosIdentifier: "synthetic-success"
        )
        let reopened = try FilmRepository(rootURL: root)
        try reopened.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1, verifiedMedia: [verification])
        XCTAssertFalse(try reopened.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertEqual(try Data(contentsOf: master.url), data)
    }

    func testChangedMasterAfterDecodeKeepsSource() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        let data = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        try repository.savePhotoCapture(filmID: film.id, sourceData: data)
        try repository.writeDevelopedMaster(filmID: film.id, sequenceNumber: 1, data: data)
        try revealTestInstant(repository, filmID: film.id)
        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false)
        let master = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .master))
        let verification = try VerifiedMedia.photo(at: master.url)
        try Data("corrupted after decode".utf8).write(to: master.url)
        XCTAssertThrowsError(try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1, verifiedMedia: [verification])) {
            XCTAssertEqual($0 as? PersistenceError, .masterChecksumMismatch)
        }
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testMovieCleanupRequiresDecodableClipAndFullMovieWhileRetainingBoth() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = root.appendingPathComponent("Fixtures")
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.super8HomeMovie, title: "Synthetic", movieOrientation: .landscape)
        let data = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov"))
        try repository.saveMovieClip(filmID: film.id, sourceData: data, durationSeconds: manifest.movie.durationSeconds, orientation: .landscape)
        try repository.completeEarly(filmID: film.id)
        _ = try repository.beginDevelopment(filmID: film.id)
        try repository.writeDevelopedClip(filmID: film.id, sequenceNumber: 1, data: data)
        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false)
        let clip = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .clip))
        let verification = try await VerifiedMedia.movie(at: clip.url)
        XCTAssertGreaterThan(verification.decodedFrameCount, 1)
        XCTAssertThrowsError(try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1, verifiedMedia: [verification]))
        try repository.writeAssembledMovie(filmID: film.id, data: data, clipSequenceNumbers: [1], verification: verification)
        try repository.finishVerifiedDevelopment(filmID: film.id, verifiedMedia: [verification])
        try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1, verifiedMedia: [verification])
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertEqual(try Data(contentsOf: clip.url), data)
        XCTAssertTrue(try repository.assembledMovieExists(filmID: film.id))
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("SourceCleanupTests-\(UUID())")
    }
}
