import FilmDomain
@testable import FilmPersistence
import RenderCore
import XCTest

/// PRD 2.1 slice 1 at the store: a Film keeps the whole Camera package it locked, and the Darkroom gates a saved
/// recipe by the Film's print process.
final class PRD2Slice1Tests: XCTestCase {
    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PRD2Slice1Tests-\(UUID())", isDirectory: true)
    }

    func testNewCamerasCarryNoDecadeAndNewSixteenMillimeterFilmsGetOneHundredSixtySevenSeconds() throws {
        XCTAssertEqual(CameraCatalog.mediumFormat6x6.displayName, "6×6 Medium Format")
        XCTAssertEqual(CameraCatalog.cinema16mm.displayName, "16mm Cinema")
        for camera in CameraCatalog.all where camera.id == .mediumFormat6x6 || camera.id == .cinema16mm {
            XCTAssertFalse(camera.displayName.contains("19"), camera.displayName)
        }
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "New reel", movieOrientation: .landscape)
        XCTAssertEqual(film.camera.capacity, .seconds(167))
        XCTAssertEqual(film.remainingMovieFrames, 167 * MovieFrames.perSecond)
    }

    func testAFilmLoadedBeforeTheChangeKeepsItsLockedNameAndCapacity() throws {
        // The package as the previous build locked it into a Film.
        let locked = CameraPackage(id: .cinema16mm, displayName: "1960s 16mm Cinema", medium: .movie, capacity: .seconds(165),
                                   revealRule: .movieDevelopment, supportsBuiltInSoundtrack: true)
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let old = try FilmRepository(rootURL: root).createFilm(camera: locked, title: "Old reel", movieOrientation: .landscape)
        let new = try FilmRepository(rootURL: root).createFilm(camera: CameraCatalog.cinema16mm, title: "New reel", movieOrientation: .landscape)

        let reopened = try FilmRepository(rootURL: root)
        let restoredOld = try reopened.film(id: old.id)
        XCTAssertEqual(restoredOld.camera, locked)
        XCTAssertEqual(restoredOld.camera.displayName, "1960s 16mm Cinema")
        XCTAssertEqual(restoredOld.camera.capacity, .seconds(165))
        XCTAssertEqual(restoredOld.remainingMovieFrames, 165 * MovieFrames.perSecond)
        XCTAssertEqual(try reopened.film(id: new.id).camera.capacity, .seconds(167))
        // The old Film still fills at its own capacity, not the new one.
        let clip = Data("native-clip".utf8)
        let full = try reopened.saveMovieClip(filmID: old.id, sourceData: clip, durationSeconds: 165, orientation: .landscape)
        XCTAssertEqual(full.completionState, .capacityFull)
        XCTAssertEqual(try reopened.film(id: new.id).completionState, .open)
    }

    func testSavedRecipesAllowContrastGradesOnEveryColorFilmAndNeverToning() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        for camera in CameraCatalog.all where camera.medium == .photo {
            let film = try repository.createFilm(camera: camera, title: "\(camera.id)")
            try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source".utf8))
            if camera.revealRule == .instantPerExposure { try revealTestInstant(repository, filmID: film.id) }
            else {
                try repository.completeEarly(filmID: film.id)
                try await developTestFilm(repository, filmID: film.id)
            }
            XCTAssertEqual(try repository.photoPrintProcess(filmID: film.id), .color, "\(camera.id)")
            for grade in 0...5 {
                XCTAssertNoThrow(try repository.saveDarkroomRecipe(filmID: film.id, sequence: 1, recipe: DarkroomRecipe(contrastGrade: grade)),
                                 "\(camera.id) grade \(grade)")
            }
            XCTAssertEqual(try repository.darkroomRecipe(filmID: film.id, sequence: 1).contrastGrade, 5)
            for chemistry in ChemicalToning.Chemistry.allCases {
                XCTAssertThrowsError(try repository.saveDarkroomRecipe(filmID: film.id, sequence: 1,
                    recipe: DarkroomRecipe(chemicalToning: ChemicalToning(chemistry: chemistry, amount: 0.5))), "\(camera.id)") {
                    XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
                }
            }
            // The rejected toning left the saved recipe as it was.
            XCTAssertEqual(try repository.darkroomRecipe(filmID: film.id, sequence: 1).contrastGrade, 5)
            XCTAssertNil(try repository.darkroomRecipe(filmID: film.id, sequence: 1).chemicalToning)
        }
    }

    func testAnInstantRecipeWithACropIsNeverSaved() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Pack")
        try repository.savePhotoCapture(filmID: film.id, sourceData: Data("source".utf8))
        try revealTestInstant(repository, filmID: film.id)
        XCTAssertThrowsError(try repository.saveDarkroomRecipe(filmID: film.id, sequence: 1,
            recipe: DarkroomRecipe(printExposureStops: 0.5, crop: Crop(x: 0, y: 0, width: 1, height: 1)))) {
            XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
        }
        XCTAssertEqual(try repository.darkroomRecipe(filmID: film.id, sequence: 1), .original)
        XCTAssertNoThrow(try repository.saveDarkroomRecipe(filmID: film.id, sequence: 1, recipe: DarkroomRecipe(printExposureStops: 0.5)))
    }
}
