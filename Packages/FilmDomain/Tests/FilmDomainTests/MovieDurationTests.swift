import FilmDomain
import Foundation
import XCTest

final class MovieDurationTests: XCTestCase {
    func testSubsecondClipsConsumeOnlyTheirSavedDurationAcrossPersistenceAndEarlyCompletion() throws {
        var film = try Film(camera: CameraCatalog.super8HomeMovie, title: "Synthetic", movieOrientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: 0.375, orientation: .portrait)
        _ = try film.recordSavedMovieClip(durationSeconds: 1.125, orientation: .landscape)
        film = try JSONDecoder().decode(Film.self, from: JSONEncoder().encode(film))
        XCTAssertEqual(film.consumedMovieSeconds, 1.5)
        XCTAssertEqual(film.remainingMovieSeconds, 198.5)
        XCTAssertEqual(film.captures.first?.kind, .movieClip(seconds: 0.375, orientation: .portrait))
        XCTAssertEqual(film.movieOrientation, .landscape)
        XCTAssertEqual(try film.completeEarly(), .seconds(198.5))
    }

    func testFinalFractionCompletesBudgetAndNonfiniteDurationsNeverDebit() throws {
        var film = try Film(camera: CameraCatalog.cinema16mm, title: "Synthetic", movieOrientation: .portrait)
        for duration in [Double.nan, .infinity, -.infinity, 0, -0.1] {
            XCTAssertThrowsError(try film.recordSavedMovieClip(durationSeconds: duration, orientation: .landscape))
        }
        XCTAssertEqual(film.savedCaptureCount, 0)
        _ = try film.recordSavedMovieClip(durationSeconds: 164.75, orientation: .landscape)
        XCTAssertThrowsError(try film.recordSavedMovieClip(durationSeconds: 0.5, orientation: .landscape))
        XCTAssertEqual(film.remainingMovieSeconds, 0.25)
        _ = try film.recordSavedMovieClip(durationSeconds: 0.25, orientation: .portrait)
        XCTAssertEqual(film.completionState, .capacityFull)
        XCTAssertEqual(film.developmentState, .notStarted)
    }
}
