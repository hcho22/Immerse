import FilmDomain
import FilmPersistence
import Foundation
import XCTest

final class CaptureReceiptTests: XCTestCase {
    func testLostAcknowledgementCanRetryAfterReopenWithoutAnotherDebit() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        let data = Data("retained-native-payload".utf8)
        XCTAssertThrowsError(try repository.savePhotoCapture(
            filmID: film.id, sourceData: data, captureID: "one.photo",
            failureInjection: .afterDatabaseCommitBeforeAcknowledgement
        ))
        repository = try FilmRepository(rootURL: root)
        try repository.recover()
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("next".utf8), captureID: "two.photo")
        let after = try repository.savePhotoCapture(filmID: film.id, sourceData: data, captureID: "one.photo")
        XCTAssertEqual(after.savedCaptureCount, 2)
        XCTAssertEqual(after.remainingExposures, 25)
        XCTAssertEqual(try repository.captureReceipt(filmID: film.id, captureID: "one.photo")?.sequenceNumber, 1)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("Media/\(film.id)/source-1.bin")), data)
        XCTAssertThrowsError(try repository.savePhotoCapture(
            filmID: film.id, sourceData: Data("different".utf8), captureID: "one.photo"
        )) { XCTAssertEqual($0 as? PersistenceError, .conflictingCaptureReceipt) }
    }

    func testMovieRetryChecksDurationAndOrientationEvenAtFullCapacity() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Synthetic", movieOrientation: .landscape, filmStock: .color)
        let data = Data("native-clip".utf8)
        try repository.saveMovieClip(filmID: film.id, sourceData: data, durationSeconds: 167, orientation: .portrait, captureID: "clip")
        repository = try FilmRepository(rootURL: root)
        let after = try repository.saveMovieClip(filmID: film.id, sourceData: data, durationSeconds: 167, orientation: .portrait, captureID: "clip")
        XCTAssertEqual(after.consumedMovieSeconds, 167)
        XCTAssertEqual(after.savedCaptureCount, 1)
        XCTAssertThrowsError(try repository.saveMovieClip(
            filmID: film.id, sourceData: data, durationSeconds: 166, orientation: .portrait, captureID: "clip"
        )) { XCTAssertEqual($0 as? PersistenceError, .conflictingCaptureReceipt) }
        XCTAssertThrowsError(try repository.saveMovieClip(
            filmID: film.id, sourceData: data, durationSeconds: 167, orientation: .landscape, captureID: "clip"
        )) { XCTAssertEqual($0 as? PersistenceError, .conflictingCaptureReceipt) }
    }

    func testRetryAfterDiscardNeverRecreatesMediaAndDeletionRejectsIt() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        let data = Data("native-photo".utf8)
        try repository.savePhotoCapture(filmID: film.id, sourceData: data, captureID: "one")
        try revealTestInstant(repository, filmID: film.id)
        try repository.discardRevealedCapture(filmID: film.id, sequenceNumber: 1)
        repository = try FilmRepository(rootURL: root)
        let after = try repository.savePhotoCapture(filmID: film.id, sourceData: data, captureID: "one")
        XCTAssertEqual(after.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertEqual(after.remainingExposures, 9)
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        try repository.deleteFilm(filmID: film.id)
        XCTAssertThrowsError(try repository.savePhotoCapture(filmID: film.id, sourceData: data, captureID: "one")) {
            XCTAssertEqual($0 as? PersistenceError, .filmNotFound)
        }
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("CaptureReceiptTests-\(UUID())")
    }
}
