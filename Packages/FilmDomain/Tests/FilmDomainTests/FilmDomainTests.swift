import XCTest
@testable import FilmDomain

final class FilmDomainTests: XCTestCase {
    func testCameraCatalogDefinesSettledCapacitiesAndRevealRules() {
        XCTAssertEqual(CameraCatalog.all.count, 5)
        XCTAssertEqual(CameraCatalog.disposable1990s.capacity, .exposures(27))
        XCTAssertEqual(CameraCatalog.disposable1990s.revealRule, .rollLevelDevelopment)
        XCTAssertEqual(CameraCatalog.instant1970s.capacity, .exposures(10))
        XCTAssertEqual(CameraCatalog.instant1970s.revealRule, .instantPerExposure)
        XCTAssertEqual(CameraCatalog.mediumFormat6x6.capacity, .exposures(12))
        XCTAssertEqual(CameraCatalog.super8HomeMovie.capacity, .seconds(200))
        XCTAssertEqual(CameraCatalog.super8HomeMovie.revealRule, .movieDevelopment)
        XCTAssertEqual(CameraCatalog.cinema16mm.capacity, .seconds(165))
        XCTAssertTrue(CameraCatalog.super8HomeMovie.supportsBuiltInSoundtrack)
        XCTAssertTrue(CameraCatalog.cinema16mm.supportsBuiltInSoundtrack)
    }

    func testLoadedCameraDoesNotChangeWhenTitleOrArchiveChanges() throws {
        var film = try Film(camera: CameraCatalog.mediumFormat6x6, title: "6x6 - Roll #01")
        _ = try film.recordSavedPhoto()

        film.rename(to: "Kyoto alleys")
        film.setArchived(true)

        XCTAssertEqual(film.camera, CameraCatalog.mediumFormat6x6)
        XCTAssertEqual(film.title, "Kyoto alleys")
        XCTAssertTrue(film.isArchived)
        XCTAssertEqual(film.remainingExposures, 11)
        XCTAssertEqual(film.captures.map(\.sequenceNumber), [1])
    }

    func testDurablePhotoDebitHappensOnlyForSavedCaptures() throws {
        var film = try Film(camera: CameraCatalog.disposable1990s, title: "Disposable - Roll #01")

        try film.recordFailedPhotoSave()
        XCTAssertEqual(film.savedCaptureCount, 0)
        XCTAssertEqual(film.remainingExposures, 27)

        _ = try film.recordSavedPhoto()
        XCTAssertEqual(film.savedCaptureCount, 1)
        XCTAssertEqual(film.remainingExposures, 26)
    }

    func testRollCompletionAndDevelopmentAreDistinct() throws {
        var film = try Film(camera: CameraCatalog.disposable1990s, title: "Disposable - Roll #01")

        for _ in 0..<27 {
            _ = try film.recordSavedPhoto()
        }

        XCTAssertEqual(film.completionState, .capacityFull)
        XCTAssertEqual(Set(film.captures.map(\.revealState)), [.sealed])
        XCTAssertEqual(film.developmentState, .notStarted)
        XCTAssertTrue(film.canStartDevelopment)

        try film.startDevelopment()
        XCTAssertEqual(film.developmentState, .developing)
        XCTAssertEqual(Set(film.captures.map(\.revealState)), [.sealed])

        try film.finishDevelopment()
        XCTAssertEqual(film.developmentState, .developed)
        XCTAssertEqual(Set(film.captures.map(\.revealState)), [.revealed])
    }

    func testEarlyCompletionRequiresSavedCaptureAndReportsExactWaste() throws {
        var film = try Film(camera: CameraCatalog.disposable1990s, title: "Disposable - Roll #01")

        XCTAssertThrowsError(try film.completeEarly()) { error in
            XCTAssertEqual(error as? FilmDomainError, .noSavedCapturesForEarlyCompletion)
        }
        XCTAssertEqual(film.completionState, .open)

        _ = try film.recordSavedPhoto()
        let wasted = try film.completeEarly()

        XCTAssertEqual(wasted, .exposures(26))
        XCTAssertEqual(film.completionState, .completedEarly(wasted: .exposures(26)))
        XCTAssertTrue(film.canStartDevelopment)
    }

    func testInstantPrintsRevealIndividuallyIncludingFinalFrame() throws {
        var film = try Film(camera: CameraCatalog.instant1970s, title: "Instant - Pack #01")

        for expectedSequence in 1...10 {
            let capture = try film.recordSavedPhoto()
            XCTAssertEqual(capture.sequenceNumber, expectedSequence)
            XCTAssertEqual(capture.revealState, .revealed)
        }

        XCTAssertEqual(film.completionState, .capacityFull)
        XCTAssertEqual(Set(film.captures.map(\.revealState)), [.revealed])
        XCTAssertFalse(film.canStartDevelopment)
        XCTAssertThrowsError(try film.startDevelopment()) { error in
            XCTAssertEqual(error as? FilmDomainError, .instantDoesNotUseRollDevelopment)
        }
    }

    func testMovieDebitHappensOnlyForSavedDurationAndPreventsOverrun() throws {
        var film = try Film(
            camera: CameraCatalog.super8HomeMovie,
            title: "Super 8 - Roll #01",
            movieOrientation: .landscape
        )

        try film.recordFailedMovieClipSave(durationSeconds: 18)
        XCTAssertEqual(film.consumedMovieSeconds, 0)
        XCTAssertEqual(film.remainingMovieSeconds, 200)

        _ = try film.recordSavedMovieClip(durationSeconds: 18, orientation: .portrait)
        XCTAssertEqual(film.consumedMovieSeconds, 18)
        XCTAssertEqual(film.remainingMovieSeconds, 182)

        XCTAssertThrowsError(try film.recordSavedMovieClip(durationSeconds: 183, orientation: .landscape)) { error in
            XCTAssertEqual(error as? FilmDomainError, .insufficientRemainingCapacity(remainingSeconds: 182))
        }
        XCTAssertEqual(film.consumedMovieSeconds, 18)

        _ = try film.recordSavedMovieClip(durationSeconds: 182, orientation: .landscape)
        XCTAssertEqual(film.completionState, .capacityFull)
    }

    func testMovieEarlyCompletionReportsExactRemainingTime() throws {
        var film = try Film(
            camera: CameraCatalog.cinema16mm,
            title: "16mm - Roll #01",
            movieOrientation: .portrait
        )

        _ = try film.recordSavedMovieClip(durationSeconds: 64, orientation: .portrait)
        let wasted = try film.completeEarly()

        XCTAssertEqual(wasted, .seconds(101))
        XCTAssertEqual(film.completionState, .completedEarly(wasted: .seconds(101)))
        XCTAssertTrue(film.canStartDevelopment)
    }

    func testDiscardingAllMovieClipsKeepsPlaceholdersAndDisablesPlaybackAndExport() throws {
        var film = try Film(
            camera: CameraCatalog.super8HomeMovie,
            title: "Super 8 - Roll #01",
            movieOrientation: .landscape
        )
        _ = try film.recordSavedMovieClip(durationSeconds: 30, orientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: 45, orientation: .portrait)
        try film.completeEarly()
        try film.startDevelopment()
        try film.finishDevelopment()

        XCTAssertEqual(film.playableMovieClipSequenceNumbers, [1, 2])
        XCTAssertTrue(film.canPlaybackDevelopedMovie)
        XCTAssertTrue(film.canExportDevelopedMovie)

        try film.discardRevealedCapture(sequenceNumber: 1)
        XCTAssertEqual(film.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertEqual(film.playableMovieClipSequenceNumbers, [2])
        XCTAssertEqual(film.consumedMovieSeconds, 75)

        try film.discardRevealedCapture(sequenceNumber: 2)
        XCTAssertEqual(film.discardedPlaceholderSequenceNumbers, [1, 2])
        XCTAssertEqual(film.playableMovieClipSequenceNumbers, [])
        XCTAssertFalse(film.canPlaybackDevelopedMovie)
        XCTAssertFalse(film.canExportDevelopedMovie)
        XCTAssertEqual(film.consumedMovieSeconds, 75)
    }

    func testSealedCapturesCannotBeDiscardedIndividually() throws {
        var film = try Film(camera: CameraCatalog.disposable1990s, title: "Disposable - Roll #01")
        _ = try film.recordSavedPhoto()

        XCTAssertThrowsError(try film.discardRevealedCapture(sequenceNumber: 1)) { error in
            XCTAssertEqual(error as? FilmDomainError, .captureNotRevealed)
        }
        XCTAssertEqual(film.captures.first?.revealState, .sealed)
        XCTAssertEqual(film.remainingExposures, 26)
    }
}
