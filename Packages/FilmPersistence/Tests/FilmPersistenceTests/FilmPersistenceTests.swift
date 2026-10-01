import FilmDomain
@testable import FilmPersistence
import XCTest
import RenderFixtures

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

    func testSourceCleanupRequiresVerifiedMaster() async throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-1".utf8))
        try repository.completeEarly(filmID: film.id)
        _ = try repository.beginDevelopment(filmID: film.id)
        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false)

        XCTAssertThrowsError(
            try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1)
        ) { error in
            XCTAssertEqual(error as? PersistenceError, .mediaNotRevealed)
        }
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))

        let fixtures = rootURL.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        try repository.writeDevelopedMaster(
            filmID: film.id,
            sequenceNumber: 1,
            data: Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        )
        let master = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .master))
        let verified = try VerifiedMedia.photo(at: master.url)
        try repository.finishVerifiedDevelopment(filmID: film.id, verifiedMedia: [verified])
        try repository.cleanupSourceAfterVerifiedMaster(filmID: film.id, sequenceNumber: 1, verifiedMedia: [verified])

        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .master))
    }

    func testDiscardDeletesAppControlledMediaAndKeepsPlaceholder() async throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-1".utf8))
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source-2".utf8))
        try repository.completeEarly(filmID: film.id)
        try await developTestFilm(repository, filmID: film.id)

        let afterDiscard = try repository.discardRevealedCapture(filmID: film.id, sequenceNumber: 1)

        XCTAssertEqual(afterDiscard.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .master))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 2, kind: .source))
    }

    func testMovieDiscardRetiresStaleAssemblyAndPreservesSurvivingClips() async throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.super8HomeMovie,
            title: "Super 8 - Reel #01",
            movieOrientation: .landscape
        )
        try repository.saveMovieClip(
            filmID: film.id,
            sourceData: Data("source-1".utf8),
            durationSeconds: 5,
            orientation: .landscape
        )
        try repository.saveMovieClip(
            filmID: film.id,
            sourceData: Data("source-2".utf8),
            durationSeconds: 7,
            orientation: .portrait
        )
        try repository.completeEarly(filmID: film.id)
        try await developTestFilm(repository, filmID: film.id)

        XCTAssertTrue(try repository.assembledMovieExists(filmID: film.id))

        var afterDiscard = try repository.discardRevealedCapture(
            filmID: film.id,
            sequenceNumber: 2
        )

        XCTAssertEqual(afterDiscard.playableMovieClipSequenceNumbers, [1])
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 2, kind: .clip))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .clip))
        XCTAssertFalse(try repository.assembledMovieExists(filmID: film.id))

        let survivor = try repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .clip)!
        let verified = try await VerifiedMedia.movie(at: survivor.url)
        try repository.writeAssembledMovie(
            filmID: film.id,
            data: Data(contentsOf: survivor.url),
            clipSequenceNumbers: [1], verification: verified
        )
        XCTAssertTrue(try repository.assembledMovieExists(filmID: film.id))

        afterDiscard = try repository.discardRevealedCapture(
            filmID: film.id,
            sequenceNumber: 1
        )

        XCTAssertEqual(afterDiscard.discardedPlaceholderSequenceNumbers, [1, 2])
        XCTAssertFalse(afterDiscard.canPlaybackDevelopedMovie)
        XCTAssertFalse(afterDiscard.canExportDevelopedMovie)
        XCTAssertFalse(try repository.assembledMovieExists(filmID: film.id))
        XCTAssertThrowsError(
            try repository.writeAssembledMovie(
                filmID: film.id,
                data: Data("empty-movie".utf8),
                clipSequenceNumbers: []
            )
        ) { error in
            XCTAssertEqual(error as? PersistenceError, .movieNotPlayable)
        }
    }

    func testMovieAssemblyRequiresCurrentPlayableClipPlanAndVerifiedClips() throws {
        let film = try repository.createFilm(
            camera: CameraCatalog.cinema16mm,
            title: "16mm - Reel #01",
            movieOrientation: .portrait
        )
        try repository.saveMovieClip(
            filmID: film.id,
            sourceData: Data("source-1".utf8),
            durationSeconds: 3,
            orientation: .portrait
        )
        try repository.saveMovieClip(
            filmID: film.id,
            sourceData: Data("source-2".utf8),
            durationSeconds: 4,
            orientation: .landscape
        )
        try repository.completeEarly(filmID: film.id)
        _ = try repository.beginDevelopment(filmID: film.id)
        try repository.writeDevelopedClip(
            filmID: film.id,
            sequenceNumber: 1,
            data: Data("clip-1-developed".utf8)
        )

        XCTAssertThrowsError(
            try repository.writeAssembledMovie(
                filmID: film.id,
                data: Data("wrong-plan".utf8),
                clipSequenceNumbers: [1]
            )
        ) { error in
            XCTAssertEqual(
                error as? PersistenceError,
                .assembledMoviePlanMismatch(expected: [1, 2], actual: [1])
            )
        }

        XCTAssertThrowsError(
            try repository.writeAssembledMovie(
                filmID: film.id,
                data: Data("missing-clip".utf8),
                clipSequenceNumbers: [1, 2]
            )
        ) { error in
            XCTAssertEqual(error as? PersistenceError, .missingDevelopedClip(2))
        }
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
