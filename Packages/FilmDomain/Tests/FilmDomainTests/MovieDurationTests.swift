import FilmDomain
import Foundation
import XCTest

final class MovieDurationTests: XCTestCase {
    func testSubsecondClipsConsumeOnlyTheirSavedFramesAcrossPersistenceAndEarlyCompletion() throws {
        var film = try Film(camera: CameraCatalog.super8HomeMovie, title: "Synthetic", movieOrientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: 0.4, orientation: .portrait)
        _ = try film.recordSavedMovieClip(durationSeconds: 1.1, orientation: .landscape)
        film = try JSONDecoder().decode(Film.self, from: JSONEncoder().encode(film))
        XCTAssertEqual(film.consumedMovieFrames, 45)
        XCTAssertEqual(film.consumedMovieSeconds, 1.5)
        XCTAssertEqual(film.remainingMovieSeconds, 198.5)
        XCTAssertEqual(film.captures.first?.kind, .movieClip(seconds: 0.4, orientation: .portrait))
        XCTAssertEqual(film.movieOrientation, .landscape)
        XCTAssertEqual(try film.completeEarly(), .seconds(198.5))
    }

    func testFinalFrameCompletesBudgetAndNonfiniteDurationsNeverDebit() throws {
        var film = try Film(camera: CameraCatalog.cinema16mm, title: "Synthetic", movieOrientation: .portrait)
        for duration in [Double.nan, .infinity, -.infinity, 0, -0.1] {
            XCTAssertThrowsError(try film.recordSavedMovieClip(durationSeconds: duration, orientation: .landscape))
        }
        XCTAssertEqual(film.savedCaptureCount, 0)
        _ = try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(5_002), orientation: .landscape)
        XCTAssertThrowsError(try film.recordSavedMovieClip(durationSeconds: 0.5, orientation: .landscape))
        XCTAssertEqual(film.remainingMovieFrames, 8)
        _ = try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(8), orientation: .portrait)
        XCTAssertEqual(film.completionState, .capacityFull)
        XCTAssertEqual(film.remainingMovieSeconds, 0)
        XCTAssertEqual(film.developmentState, .notStarted)
    }

    func testClipsThatRecordTheWholeReelCompleteItAlthoughTheirSecondsDoNotSumExactly() throws {
        let frames = [2_578, 2_965, 457]
        XCTAssertNotEqual(frames.map(MovieFrames.seconds).reduce(0, +), 200, "Summed seconds drift below the reel")
        var film = try Film(camera: CameraCatalog.super8HomeMovie, title: "Synthetic", movieOrientation: .landscape)
        for count in frames {
            XCTAssertEqual(film.completionState, .open)
            _ = try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(count), orientation: .landscape)
        }
        XCTAssertEqual(film.consumedMovieFrames, 6_000)
        XCTAssertEqual(film.remainingMovieFrames, 0)
        XCTAssertEqual(film.completionState, .capacityFull)
        XCTAssertTrue(film.canStartDevelopment)
    }

    func testFinalClipThatUsesExactlyTheRemainingFramesIsAccepted() throws {
        XCTAssertGreaterThan(MovieFrames.seconds(5_513), 200 - MovieFrames.seconds(487),
                             "The final clip's seconds exceed the seconds left after the first clip")
        var film = try Film(camera: CameraCatalog.super8HomeMovie, title: "Synthetic", movieOrientation: .portrait)
        _ = try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(487), orientation: .portrait)
        XCTAssertEqual(film.remainingMovieFrames, 5_513)
        let final = try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(5_513), orientation: .landscape)
        XCTAssertEqual(final.sequenceNumber, 2)
        XCTAssertEqual(film.completionState, .capacityFull)
        XCTAssertEqual(film.remainingMovieFrames, 0)
    }

    func testRemainderSmallerThanOneFrameCompletesTheFilm() throws {
        var film = try Film(camera: CameraCatalog.cinema16mm, title: "Synthetic", movieOrientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: 83.504, orientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: 83.49, orientation: .landscape)
        XCTAssertLessThan(film.captures.reduce(0) { total, capture in
            guard case let .movieClip(seconds, _) = capture.kind else { return total }
            return total + seconds
        }, 167)
        XCTAssertEqual(film.remainingMovieFrames, 0)
        XCTAssertEqual(film.completionState, .capacityFull)
        XCTAssertThrowsError(try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(1), orientation: .landscape)) {
            XCTAssertEqual($0 as? FilmDomainError, .captureAlreadyComplete)
        }
    }
}
