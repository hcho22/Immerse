import FilmDomain
@testable import FilmPersistence
import XCTest

final class FilmPersistenceTests: XCTestCase {
    private var rootURL: URL!
    private var repository: FilmRepository!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FilmPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        repository = try FilmRepository(rootURL: rootURL)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        repository = nil
    }

    func testSuccessfulPhotoSavePersistsStateAndPrivateSource() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )

        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-1".utf8))
        let reloaded = try repository.film(id: film.id)

        XCTAssertEqual(reloaded.savedCaptureCount, 1)
        XCTAssertEqual(reloaded.remainingExposures, 26)
        XCTAssertEqual(reloaded.captures.first?.revealState, .sealed)
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testFilmStateAndAssetsReloadFromDiskInNewRepositoryInstance() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.mediumFormat6x6,
            title: "6x6 - Roll #01"
        )
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-1".utf8))

        repository = try FilmRepository(rootURL: rootURL)
        let reloaded = try repository.film(id: film.id)

        XCTAssertEqual(reloaded.camera, CameraCatalog.mediumFormat6x6)
        XCTAssertEqual(reloaded.savedCaptureCount, 1)
        XCTAssertEqual(reloaded.remainingExposures, 11)
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testFailureBeforeDurableMoveDoesNotDebitOrLeaveSource() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )

        XCTAssertThrowsError(
            try repository.savePhotoCapture(
                filmID: film.id,
                sourceData: Data("source-1".utf8),
                failureInjection: .beforeDurableMove
            )
        ) { error in
            XCTAssertEqual(error as? PersistenceError, .simulatedFailure(.beforeDurableMove))
        }

        try repository.recover()
        let reloaded = try repository.film(id: film.id)
        XCTAssertEqual(reloaded.savedCaptureCount, 0)
        XCTAssertEqual(reloaded.remainingExposures, 27)
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testFailureAfterDurableMoveBeforeDebitLeavesNoDebitAndRecoveryRemovesOrphan() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )

        XCTAssertThrowsError(
            try repository.savePhotoCapture(
                filmID: film.id,
                sourceData: Data("source-1".utf8),
                failureInjection: .afterDurableMoveBeforeDebit
            )
        ) { error in
            XCTAssertEqual(error as? PersistenceError, .simulatedFailure(.afterDurableMoveBeforeDebit))
        }

        var reloaded = try repository.film(id: film.id)
        XCTAssertEqual(reloaded.savedCaptureCount, 0)
        XCTAssertEqual(reloaded.remainingExposures, 27)

        try repository.recover()
        reloaded = try repository.film(id: film.id)
        XCTAssertEqual(reloaded.savedCaptureCount, 0)
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testSourceCleanupRequiresVerifiedMaster() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-1".utf8))

        XCTAssertThrowsError(
            try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1)
        ) { error in
            XCTAssertEqual(error as? PersistenceError, .missingVerifiedMaster)
        }
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))

        try repository.writeDevelopedMaster(
            filmID: film.id,
            sequenceNumber: 1,
            data: Data("master-1".utf8)
        )
        try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1)

        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .master))
    }

    func testDiscardDeletesAppControlledMediaAndKeepsPlaceholder() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-1".utf8))
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-2".utf8))
        try repository.completeEarly(filmID: film.id)
        try repository.startAndFinishDevelopment(filmID: film.id)
        try repository.writeDevelopedMaster(
            filmID: film.id,
            sequenceNumber: 1,
            data: Data("master-1".utf8)
        )

        let afterDiscard = try repository.discardRevealedCapture(filmID: film.id, sequenceNumber: 1)

        XCTAssertEqual(afterDiscard.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .master))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 2, kind: .source))
    }

    func testDeleteFilmRemovesSealedFilmStateAndAssetsWithoutDevelopment() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-1".utf8))

        try repository.deleteFilm(filmID: film.id)

        XCTAssertThrowsError(try repository.film(id: film.id)) { error in
            XCTAssertEqual(error as? PersistenceError, .filmNotFound)
        }
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testTemporaryFilesAreExcludedFromBackupButFilmMediaIsNot() throws {
        XCTAssertTrue(try repository.temporaryDirectoryIsExcludedFromBackup())
        XCTAssertFalse(try repository.mediaDirectoryIsExcludedFromBackup())
    }
}
