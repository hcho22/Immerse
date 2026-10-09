import XCTest
@testable import FilmDomain

/// Film Stock (ADR 0014, PRD 2.1 FR-01 and FR-03): the 6×6 Medium Format and the 16mm Cinema offer color or
/// black-and-white at Load Film, the Film records it and keeps it, and no other Camera offers one.
final class FilmStockTests: XCTestCase {
    private let offering = [CameraCatalog.mediumFormat6x6, CameraCatalog.cinema16mm]

    func testOnlyTheSixBySixAndSixteenMillimeterOfferAFilmStock() {
        for camera in CameraCatalog.all {
            let expected: [FilmStock] = offering.contains(camera) ? [.color, .blackAndWhite] : []
            XCTAssertEqual(camera.filmStocks, expected, camera.displayName)
        }
    }

    func testLoadFilmRecordsEitherFilmStockOnBothCameras() throws {
        for camera in offering {
            for stock in FilmStock.allCases {
                let film = try Film(camera: camera, title: "Roll", movieOrientation: camera.medium == .movie ? .landscape : nil,
                                    filmStock: stock)
                XCTAssertEqual(film.filmStock, stock, "\(camera.displayName) \(stock)")
                let decoded = try JSONDecoder().decode(Film.self, from: JSONEncoder().encode(film))
                XCTAssertEqual(decoded.filmStock, stock, "\(camera.displayName) \(stock) survives storage")
            }
        }
    }

    /// Load Film always confirms a Film Stock on the two Cameras, so a new Film there never lacks one.
    func testANewFilmOnEitherCameraNeedsAFilmStock() {
        for camera in offering {
            XCTAssertThrowsError(try Film(camera: camera, title: "Roll", movieOrientation: camera.medium == .movie ? .portrait : nil)) {
                XCTAssertEqual($0 as? FilmDomainError, .filmStockRequired, camera.displayName)
            }
        }
    }

    func testNoOtherCameraTakesAFilmStock() throws {
        for camera in CameraCatalog.all where !offering.contains(camera) {
            let orientation: MovieOrientation? = camera.medium == .movie ? .portrait : nil
            for stock in FilmStock.allCases {
                XCTAssertThrowsError(try Film(camera: camera, title: "Roll", movieOrientation: orientation, filmStock: stock)) {
                    XCTAssertEqual($0 as? FilmDomainError, .filmStockNotOffered, camera.displayName)
                }
            }
            XCTAssertNil(try Film(camera: camera, title: "Roll", movieOrientation: orientation).filmStock, camera.displayName)
        }
    }

    /// Nothing a Film goes through changes its Film Stock: captures, renaming, archiving, completing early, Development
    /// and discarding a revealed capture. `filmStock` is a constant, so no mutation can reach it; this walks the whole
    /// life of a Film to show none of them replaces it either.
    func testTheFilmStockIsFixedFromLoadThroughDevelopment() throws {
        var roll = try Film(camera: CameraCatalog.mediumFormat6x6, title: "Roll", filmStock: .blackAndWhite)
        _ = try roll.recordSavedPhoto()
        _ = try roll.recordSavedPhoto()
        try roll.rename(to: "Harbour")
        roll.setArchived(true)
        try roll.completeEarly()
        try roll.startDevelopment()
        XCTAssertEqual(roll.filmStock, .blackAndWhite)
        try roll.finishDevelopment()
        try roll.discardRevealedCapture(sequenceNumber: 1)
        roll.setArchived(false)
        XCTAssertEqual(roll.filmStock, .blackAndWhite)
        XCTAssertEqual(try JSONDecoder().decode(Film.self, from: JSONEncoder().encode(roll)).filmStock, .blackAndWhite)

        var reel = try Film(camera: CameraCatalog.cinema16mm, title: "Reel", movieOrientation: .portrait, filmStock: .blackAndWhite)
        _ = try reel.recordSavedMovieClip(durationSeconds: 167, orientation: .landscape)
        XCTAssertEqual(reel.completionState, .capacityFull)
        try reel.startDevelopment()
        try reel.finishDevelopment()
        XCTAssertEqual(reel.filmStock, .blackAndWhite)
    }

    /// Films stored before Film Stock existed have no "filmStock" key. They stay readable, with no Film Stock, and keep
    /// everything else they locked, including a 16mm Film's earlier name and 165 seconds.
    func testFilmsStoredBeforeFilmStockDecodeWithNone() throws {
        let sixBySix = #"{"camera":{"capacity":{"exposures":{"_0":12}},"displayName":"1960s 6x6 Medium Format","id":"mediumFormat6x6","medium":"photo","revealRule":"rollLevelDevelopment","supportsBuiltInSoundtrack":false},"captures":[{"kind":{"photo":{}},"revealState":"sealed","savedAt":811692900,"sequenceNumber":1}],"completionState":{"open":{}},"developmentState":"notStarted","id":"0F6D1E2A-6C1B-4B8E-9C11-5A0E7E2B9D41","isArchived":false,"loadedAt":811692800,"title":"6x6 - Roll #01"}"#
        let reel = #"{"camera":{"capacity":{"seconds":{"_0":165}},"displayName":"1960s 16mm Cinema","id":"cinema16mm","medium":"movie","revealRule":"movieDevelopment","supportsBuiltInSoundtrack":true},"captures":[{"kind":{"movieClip":{"orientation":"landscape","seconds":2}},"revealState":"sealed","savedAt":811692900,"sequenceNumber":1}],"completionState":{"open":{}},"developmentState":"notStarted","id":"7A1C3F00-2B4D-4E6F-8A9B-0C1D2E3F4A5B","isArchived":false,"loadedAt":811692800,"movieOrientation":"landscape","title":"16mm - Roll #01"}"#
        var photo = try JSONDecoder().decode(Film.self, from: Data(sixBySix.utf8))
        XCTAssertNil(photo.filmStock)
        XCTAssertEqual(photo.camera.displayName, "1960s 6x6 Medium Format")
        XCTAssertEqual(photo.remainingExposures, 11)
        _ = try photo.recordSavedPhoto()
        XCTAssertNil(photo.filmStock, "An earlier Film never gains a Film Stock")
        XCTAssertFalse(String(data: try JSONEncoder().encode(photo), encoding: .utf8)!.contains("filmStock"))
        let movie = try JSONDecoder().decode(Film.self, from: Data(reel.utf8))
        XCTAssertNil(movie.filmStock)
        XCTAssertEqual(movie.camera.capacity, .seconds(165))
        XCTAssertEqual(movie.movieOrientation, .landscape)
    }
}
