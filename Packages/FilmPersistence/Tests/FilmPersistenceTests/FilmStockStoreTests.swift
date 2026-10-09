import FilmDomain
@testable import FilmPersistence
import RenderCore
import XCTest

/// Film Stock at the store (ADR 0014, PRD 2.1 slice 3): a Film keeps the Film Stock it was loaded with across every
/// operation and reopening, the Darkroom follows it, and a store written before Film Stock existed stays readable.
final class FilmStockStoreTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("FilmStockStoreTests-\(UUID())", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    /// The Film record is JSON in the store, and a record without "filmStock" decodes with none, so the store needs no
    /// table change: this opens a store as the previous build left it and uses its Films.
    func testAStoreWrittenBeforeFilmStockOpensWithItsFilmsHavingNone() async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let earlier = try SQLiteDatabase(url: root.appendingPathComponent("film-store.sqlite"))
        try earlier.execute("CREATE TABLE films (id TEXT PRIMARY KEY NOT NULL, data BLOB NOT NULL, updated_at REAL NOT NULL);")
        try earlier.execute("""
            CREATE TABLE film_values (film_id TEXT NOT NULL, key TEXT NOT NULL, data BLOB NOT NULL,
            PRIMARY KEY (film_id, key), FOREIGN KEY (film_id) REFERENCES films(id) ON DELETE CASCADE);
            """)
        let rollID = UUID(uuidString: "0F6D1E2A-6C1B-4B8E-9C11-5A0E7E2B9D41")!
        let reelID = UUID(uuidString: "7A1C3F00-2B4D-4E6F-8A9B-0C1D2E3F4A5B")!
        // Exactly as the previous build encoded them, with the decade names and 165 seconds it locked.
        let roll = #"{"camera":{"capacity":{"exposures":{"_0":12}},"displayName":"1960s 6x6 Medium Format","id":"mediumFormat6x6","medium":"photo","revealRule":"rollLevelDevelopment","supportsBuiltInSoundtrack":false},"captures":[],"completionState":{"open":{}},"developmentState":"notStarted","id":"0F6D1E2A-6C1B-4B8E-9C11-5A0E7E2B9D41","isArchived":false,"loadedAt":811692800,"title":"6x6 - Roll #01"}"#
        let reel = #"{"camera":{"capacity":{"seconds":{"_0":165}},"displayName":"1960s 16mm Cinema","id":"cinema16mm","medium":"movie","revealRule":"movieDevelopment","supportsBuiltInSoundtrack":true},"captures":[],"completionState":{"open":{}},"developmentState":"notStarted","id":"7A1C3F00-2B4D-4E6F-8A9B-0C1D2E3F4A5B","isArchived":false,"loadedAt":811692700,"movieOrientation":"portrait","title":"16mm - Roll #01"}"#
        for (id, json) in [(rollID, roll), (reelID, reel)] {
            try earlier.upsertFilm(id: id.uuidString, data: Data(json.utf8))
            try earlier.setValue(filmID: id, key: "access", data: JSONEncoder().encode(FilmAccess.subscription))
        }

        let repository = try FilmRepository(rootURL: root)
        XCTAssertEqual(try repository.allFilms().map(\.id), [rollID, reelID])
        XCTAssertEqual(try repository.allFilms().map(\.filmStock), [nil, nil])
        let movie = try repository.film(id: reelID)
        XCTAssertEqual(movie.camera.capacity, .seconds(165))
        XCTAssertEqual(movie.movieOrientation, .portrait)

        // The earlier 6×6 Film keeps working as color: capture, Development and a color Darkroom.
        try repository.savePhotoCapture(filmID: rollID, sourceData: Data("source".utf8))
        try repository.completeEarly(filmID: rollID)
        try await developTestFilm(repository, filmID: rollID)
        let reopened = try FilmRepository(rootURL: root)
        XCTAssertNil(try reopened.film(id: rollID).filmStock)
        XCTAssertEqual(try reopened.film(id: rollID).developmentState, .developed)
        XCTAssertEqual(try reopened.photoPrintProcess(filmID: rollID), .color)
        XCTAssertNoThrow(try reopened.saveDarkroomRecipe(filmID: rollID, sequence: 1,
            recipe: DarkroomRecipe(contrastGrade: 4, colorFiltration: ColorFiltration(cyan: 5))))
        XCTAssertThrowsError(try reopened.saveDarkroomRecipe(filmID: rollID, sequence: 1,
            recipe: DarkroomRecipe(chemicalToning: ChemicalToning(chemistry: .selenium, amount: 0.5))))
        // Saving it again writes no Film Stock into the earlier record.
        let stored = try XCTUnwrap(reopened.database.filmData(id: rollID.uuidString))
        XCTAssertFalse(String(decoding: stored, as: UTF8.self).contains("filmStock"))
    }

    func testEachFilmKeepsItsFilmStockAcrossOperationsAndReopening() async throws {
        let repository = try FilmRepository(rootURL: root)
        let mono = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Harbour", filmStock: .blackAndWhite)
        let color = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Garden", filmStock: .color)
        let reel = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Reel", movieOrientation: .landscape,
                                             filmStock: .blackAndWhite)
        for film in [mono, color] {
            try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source".utf8))
            try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source".utf8))
            try repository.rename(filmID: film.id, title: "Renamed")
            try repository.setArchived(filmID: film.id, archived: true)
            try repository.completeEarly(filmID: film.id)
            try await developTestFilm(repository, filmID: film.id)
            try repository.setArchived(filmID: film.id, archived: false)
        }
        _ = try repository.saveMovieClip(filmID: reel.id, sourceData: Data("clip".utf8), durationSeconds: 2, orientation: .portrait)
        try repository.completeEarly(filmID: reel.id)

        let reopened = try FilmRepository(rootURL: root)
        XCTAssertEqual(try reopened.film(id: mono.id).filmStock, .blackAndWhite)
        XCTAssertEqual(try reopened.film(id: mono.id).developmentState, .developed)
        XCTAssertEqual(try reopened.film(id: color.id).filmStock, .color)
        XCTAssertEqual(try reopened.film(id: reel.id).filmStock, .blackAndWhite)
        XCTAssertEqual(try reopened.film(id: mono.id).camera, CameraCatalog.mediumFormat6x6)
    }

    /// PRD 2.1 FR-07 at the store: a black-and-white 6×6 Film's prints take chemical toning and contrast grades 0 to 5
    /// and no color filtration; its crop stays square. The color Film keeps filtration and never takes toning.
    func testTheDarkroomFollowsTheFilmStock() async throws {
        let repository = try FilmRepository(rootURL: root)
        let mono = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Harbour", filmStock: .blackAndWhite)
        let color = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Garden", filmStock: .color)
        for film in [mono, color] {
            try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source".utf8))
            try repository.completeEarly(filmID: film.id)
            try await developTestFilm(repository, filmID: film.id)
        }
        XCTAssertEqual(try repository.photoPrintProcess(filmID: mono.id), .silverGelatin)
        XCTAssertEqual(try repository.photoPrintProcess(filmID: color.id), .color)
        for chemistry in ChemicalToning.Chemistry.allCases {
            let toned = DarkroomRecipe(chemicalToning: ChemicalToning(chemistry: chemistry, amount: 0.6))
            XCTAssertNoThrow(try repository.saveDarkroomRecipe(filmID: mono.id, sequence: 1, recipe: toned), "\(chemistry)")
            XCTAssertEqual(try repository.darkroomRecipe(filmID: mono.id, sequence: 1), toned)
            XCTAssertThrowsError(try repository.saveDarkroomRecipe(filmID: color.id, sequence: 1, recipe: toned)) {
                XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
            }
        }
        for grade in 0...5 {
            for film in [mono, color] {
                XCTAssertNoThrow(try repository.saveDarkroomRecipe(filmID: film.id, sequence: 1, recipe: DarkroomRecipe(contrastGrade: grade)))
            }
        }
        let filtration = DarkroomRecipe(colorFiltration: ColorFiltration(magenta: 10))
        XCTAssertThrowsError(try repository.saveDarkroomRecipe(filmID: mono.id, sequence: 1, recipe: filtration))
        XCTAssertNoThrow(try repository.saveDarkroomRecipe(filmID: color.id, sequence: 1, recipe: filtration))
        XCTAssertNoThrow(try repository.saveDarkroomRecipe(filmID: mono.id, sequence: 1,
            recipe: DarkroomRecipe(crop: Crop(x: 0.1, y: 0.1, width: 0.5, height: 0.5))))
        XCTAssertThrowsError(try repository.saveDarkroomRecipe(filmID: mono.id, sequence: 1,
            recipe: DarkroomRecipe(crop: Crop(x: 0.1, y: 0.1, width: 0.5, height: 0.4))))
    }

    /// A Film Stock is confirmed at Load Film or the Film is not loaded at all: a refused Film writes nothing.
    func testAFilmWithoutItsFilmStockOrWithAnUnofferedOneIsNeverStored() throws {
        let repository = try FilmRepository(rootURL: root)
        XCTAssertThrowsError(try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Roll")) {
            XCTAssertEqual($0 as? FilmDomainError, .filmStockRequired)
        }
        XCTAssertThrowsError(try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Reel", movieOrientation: .portrait)) {
            XCTAssertEqual($0 as? FilmDomainError, .filmStockRequired)
        }
        XCTAssertThrowsError(try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Roll", filmStock: .blackAndWhite)) {
            XCTAssertEqual($0 as? FilmDomainError, .filmStockNotOffered)
        }
        XCTAssertTrue(try repository.allFilms().isEmpty)
    }
}
