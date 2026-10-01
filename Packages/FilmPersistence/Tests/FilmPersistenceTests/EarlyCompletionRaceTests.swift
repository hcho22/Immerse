import FilmDomain
import FilmPersistence
import XCTest

final class EarlyCompletionRaceTests: XCTestCase {
    func testLateSavedCaptureRequiresNewWasteConfirmation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EarlyCompletion-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try FilmRepository(rootURL: root)
        let second = try FilmRepository(rootURL: root)
        let film = try first.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        try first.savePhotoCapture(filmID: film.id, sourceData: Data([1]))
        let confirmed = try first.film(id: film.id)
        try second.savePhotoCapture(filmID: film.id, sourceData: Data([2]))
        XCTAssertThrowsError(try first.completeEarly(filmID: film.id, confirmedCaptureCount: confirmed.savedCaptureCount)) {
            XCTAssertEqual($0 as? PersistenceError, .capacityChangedSinceConfirmation)
        }
        XCTAssertEqual(try first.film(id: film.id).completionState, .open)
        let completed = try first.completeEarly(filmID: film.id, confirmedCaptureCount: 2)
        XCTAssertEqual(completed.completionState, .completedEarly(wasted: .exposures(25)))
        XCTAssertEqual(completed.captures.map(\.revealState), [.sealed, .sealed])
    }
}
