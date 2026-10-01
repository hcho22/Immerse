import FilmDomain
import FilmPersistence
import Foundation
import XCTest

final class PrivacyRecoveryTests: XCTestCase {
    func testConcurrentCaptureAndRenderCannotOverwriteDiscardedStateAcrossConnections() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("discard-me".utf8))
        try revealTestInstant(repository, filmID: film.id)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let worker = try FilmRepository(rootURL: root)
                try worker.discardRevealedCapture(filmID: film.id, sequenceNumber: 1)
            }
            group.addTask {
                let worker = try FilmRepository(rootURL: root)
                do {
                    try worker.writeDevelopedMaster(filmID: film.id, sequenceNumber: 1, data: Data("render".utf8))
                } catch PersistenceError.captureRemoved { }
                catch PersistenceError.treatmentConflict { }
            }
            for sequence in 2...8 {
                group.addTask {
                    let worker = try FilmRepository(rootURL: root)
                    try worker.savePhotoCapture(filmID: film.id, sourceData: Data("source-\(sequence)".utf8))
                }
            }
            try await group.waitForAll()
        }
        let after = try repository.film(id: film.id)
        XCTAssertEqual(after.savedCaptureCount, 8)
        XCTAssertEqual(after.remainingExposures, 2)
        XCTAssertEqual(after.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .master))
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        for sequence in 2...8 {
            XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: sequence, kind: .source))
        }
    }

    func testPartialDiscardFailureKeepsTombstoneRejectsLateMasterAndResumesAfterReopen() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = FailingRemovalFileManager()
        var repository = try FilmRepository(rootURL: root, fileManager: manager)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("first-source".utf8))
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("surviving-source".utf8))
        try revealTestInstant(repository, filmID: film.id)
        manager.failAtLastPathComponent = "source-1.bin"

        XCTAssertThrowsError(try repository.discardRevealedCapture(filmID: film.id, sequenceNumber: 1))
        XCTAssertEqual(try repository.film(id: film.id).discardedPlaceholderSequenceNumbers, [1])
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        let directory = root.appendingPathComponent("Media/\(film.id.uuidString)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("master-1.bin").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("source-1.bin").path))
        XCTAssertThrowsError(try repository.writeDevelopedMaster(
            filmID: film.id, sequenceNumber: 1, data: Data("late-render".utf8)
        )) { XCTAssertEqual($0 as? PersistenceError, .captureRemoved) }

        repository = try FilmRepository(rootURL: root)
        try repository.recover()
        try repository.recover()
        let retried = try repository.discardRevealedCapture(filmID: film.id, sequenceNumber: 1)
        XCTAssertEqual(retried.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertEqual(retried.remainingExposures, 8)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("source-1.bin").path))
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("source-2.bin")), Data("surviving-source".utf8))
    }

    func testFailedWholeFilmCleanupRemainsDeletedAndRetryFinishesWithoutTouchingAnotherFilm() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = FailingRemovalFileManager()
        var repository = try FilmRepository(rootURL: root, fileManager: manager)
        let film = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic deleted")
        let survivor = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Synthetic survivor")
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("private-source".utf8))
        try repository.savePhotoCapture(filmID: survivor.id, sourceData: Data("survivor".utf8))
        manager.failAtLastPathComponent = film.id.uuidString

        XCTAssertThrowsError(try repository.deleteFilm(filmID: film.id))
        XCTAssertThrowsError(try repository.film(id: film.id)) {
            XCTAssertEqual($0 as? PersistenceError, .filmNotFound)
        }
        XCTAssertThrowsError(try repository.savePhotoCapture(filmID: film.id, sourceData: Data("late-save".utf8)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id.uuidString)").path))

        repository = try FilmRepository(rootURL: root)
        try repository.deleteFilm(filmID: film.id)
        try repository.recover()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id.uuidString)").path))
        XCTAssertEqual(try repository.film(id: survivor.id).savedCaptureCount, 1)
        XCTAssertTrue(try repository.assetExists(filmID: survivor.id, sequenceNumber: 1, kind: .source))
    }

    func testMovieRemovalRetiresAssemblyBeforeFailedCleanupAndRejectsLateClipOrOldPlan() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = FailingRemovalFileManager()
        var repository = try FilmRepository(rootURL: root, fileManager: manager)
        let film = try repository.createFilm(
            camera: CameraCatalog.super8HomeMovie, title: "Synthetic", movieOrientation: .landscape
        )
        for sequence in 1...2 {
            try repository.saveMovieClip(
                filmID: film.id, sourceData: Data("source-\(sequence)".utf8),
                durationSeconds: 0.5, orientation: .portrait
            )
        }
        try repository.completeEarly(filmID: film.id)
        try await developTestFilm(repository, filmID: film.id)
        let surviving = try Data(contentsOf: repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .clip)!.url)
        let retiredURL = try repository.mediaAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)!.url
        let verifiedSurvivor = try await VerifiedMedia.movie(at: repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .clip)!.url)
        manager.failAtLastPathComponent = retiredURL.lastPathComponent
        XCTAssertThrowsError(try repository.discardRevealedCapture(filmID: film.id, sequenceNumber: 2))
        XCTAssertFalse(try repository.assembledMovieExists(filmID: film.id))
        XCTAssertEqual(try repository.film(id: film.id).playableMovieClipSequenceNumbers, [1])
        XCTAssertThrowsError(try repository.writeDevelopedClip(filmID: film.id, sequenceNumber: 2, data: Data("late-clip".utf8))) {
            XCTAssertEqual($0 as? PersistenceError, .captureRemoved)
        }
        XCTAssertThrowsError(try repository.writeAssembledMovie(
            filmID: film.id, data: Data("stale-rebuild".utf8), clipSequenceNumbers: [1, 2]
        ))

        repository = try FilmRepository(rootURL: root)
        try repository.recover()
        let directory = root.appendingPathComponent("Media/\(film.id.uuidString)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: retiredURL.path))
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("clip-1.mov")), surviving)
        try repository.writeAssembledMovie(filmID: film.id, data: surviving, clipSequenceNumbers: [1], verification: verifiedSurvivor)
        XCTAssertTrue(try repository.assembledMovieExists(filmID: film.id))
        XCTAssertEqual(try repository.film(id: film.id).consumedMovieSeconds, 1)
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PrivacyRecoveryTests-\(UUID())")
    }
}

private final class FailingRemovalFileManager: FileManager, @unchecked Sendable {
    var failAtLastPathComponent: String?

    override func removeItem(at url: URL) throws {
        if url.lastPathComponent == failAtLastPathComponent {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.removeItem(at: url)
    }
}
