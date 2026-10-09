import FilmDomain
@testable import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import RenderFixtures
import XCTest

final class FilmProcessorTests: XCTestCase {
    func testFullPhotoRollCapacitiesStaySealedUntilExplicitDevelopment() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 96; settings.photoHeight = 72
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture, settings: settings)
        let source = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-photo.jpg"))
        let cases: [(CameraPackage, Int)] = [
            (CameraCatalog.disposable1990s, 27),
            (CameraCatalog.mediumFormat6x6, 12)
        ]

        for (camera, capacity) in cases {
            let repository = try FilmRepository(rootURL: root.appendingPathComponent(camera.id.rawValue))
            let film = try repository.createFilm(camera: camera, title: camera.displayName, filmStock: camera.defaultFilmStock)
            for expected in 1...capacity {
                let saved = try repository.savePhotoCapture(filmID: film.id, sourceData: source)
                XCTAssertEqual(saved.savedCaptureCount, expected)
                XCTAssertEqual(saved.remainingExposures, capacity - expected)
                XCTAssertEqual(saved.captures.map(\.revealState), Array(repeating: .sealed, count: expected))
            }
            let full = try repository.film(id: film.id)
            XCTAssertEqual(full.completionState, .capacityFull)
            XCTAssertTrue(full.canStartDevelopment)
            XCTAssertThrowsError(try repository.savePhotoCapture(filmID: film.id, sourceData: source)) {
                XCTAssertEqual($0 as? FilmDomainError, .captureAlreadyComplete)
            }
            let processor = try FilmProcessor(root: root.appendingPathComponent(camera.id.rawValue))
            try await processor.develop(filmID: film.id)
            let developed = try repository.film(id: film.id)
            XCTAssertEqual(developed.developmentState, .developed)
            XCTAssertEqual(developed.captures.map(\.revealState), Array(repeating: .revealed, count: capacity))
            XCTAssertNotNil(try repository.mediaAsset(filmID: film.id, sequenceNumber: capacity, kind: .master))
        }
    }

    func testFullInstantPackRevealsFinalPrintIndividuallyAndRejectsEleventhExposure() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 96; settings.photoHeight = 72
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture, settings: settings)
        let source = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-photo.jpg"))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Instant")
        let processor = try FilmProcessor(root: root)
        var firstPrint: Data?

        for sequence in 1...10 {
            try repository.savePhotoCapture(filmID: film.id, sourceData: source)
            XCTAssertEqual(try repository.film(id: film.id).captures.filter { $0.revealState == .sealed }.map(\.sequenceNumber), [sequence])
            try await processor.develop(filmID: film.id)
            let current = try repository.film(id: film.id)
            XCTAssertEqual(current.captures.filter { $0.revealState == .revealed }.map(\.sequenceNumber), Array(1...sequence))
            XCTAssertFalse(current.canStartDevelopment)
            let print = try await processor.photo(filmID: film.id, sequence: sequence)
            XCTAssertFalse(print.isEmpty)
            if sequence == 1 { firstPrint = print }
            else {
                let firstAgain = try await processor.photo(filmID: film.id, sequence: 1)
                XCTAssertEqual(firstAgain, firstPrint)
            }
        }

        let full = try repository.film(id: film.id)
        XCTAssertEqual(full.completionState, .capacityFull)
        XCTAssertEqual(full.remainingExposures, 0)
        XCTAssertEqual(full.captures.map(\.revealState), Array(repeating: .revealed, count: 10))
        XCTAssertThrowsError(try repository.savePhotoCapture(filmID: film.id, sourceData: source)) {
            XCTAssertEqual($0 as? FilmDomainError, .captureAlreadyComplete)
        }
    }

    func testFullMovieCapacitiesAreDurableAndRejectOverBudgetClips() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 96; settings.movieHeight = 72; settings.movieDurationSeconds = 0.12
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture, settings: settings)
        let source = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-movie.mov"))
        let cases: [(CameraPackage, TimeInterval)] = [
            (CameraCatalog.super8HomeMovie, 200),
            (CameraCatalog.cinema16mm, 167)
        ]

        for (camera, capacity) in cases {
            let repository = try FilmRepository(rootURL: root.appendingPathComponent(camera.id.rawValue))
            let film = try repository.createFilm(camera: camera, title: camera.displayName, movieOrientation: .landscape, filmStock: camera.defaultFilmStock)
            let first = try repository.saveMovieClip(filmID: film.id, sourceData: source,
                durationSeconds: capacity - MovieFrames.seconds(8), orientation: .landscape)
            XCTAssertEqual(first.remainingMovieFrames, 8)
            XCTAssertEqual(first.completionState, .open)
            XCTAssertThrowsError(try repository.saveMovieClip(filmID: film.id, sourceData: source,
                durationSeconds: MovieFrames.seconds(9), orientation: .portrait)) { error in
                XCTAssertEqual(error as? FilmDomainError, .insufficientRemainingCapacity(remainingSeconds: MovieFrames.seconds(8)))
            }
            let full = try repository.saveMovieClip(filmID: film.id, sourceData: source, durationSeconds: MovieFrames.seconds(8), orientation: .portrait)
            XCTAssertEqual(full.completionState, .capacityFull)
            XCTAssertEqual(full.consumedMovieSeconds, capacity, accuracy: 0.0001)
            XCTAssertEqual(try XCTUnwrap(full.remainingMovieSeconds), 0, accuracy: 0.0001)
            XCTAssertEqual(full.captures.map(\.revealState), [.sealed, .sealed])
            XCTAssertThrowsError(try repository.saveMovieClip(filmID: film.id, sourceData: source, durationSeconds: 0.001, orientation: .landscape)) { error in
                XCTAssertEqual(error as? FilmDomainError, .captureAlreadyComplete)
            }
        }
    }

    func testInterruptedRealDevelopmentResumesSameMasterAndRecipeResetIsExact() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture)
        let source = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-photo.jpg"))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic")
        for _ in 0..<2 { try repository.savePhotoCapture(filmID: film.id, sourceData: source) }
        try repository.completeEarly(filmID: film.id)
        let secondSource = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 2, kind: .source))
        try Data("damaged source".utf8).write(to: secondSource.url)
        let interrupted = try FilmProcessor(root: root)
        do { try await interrupted.develop(filmID: film.id); XCTFail("Damaged second source should fail") }
        catch { }
        XCTAssertEqual(try repository.film(id: film.id).developmentState, .developing)
        XCTAssertTrue(try repository.film(id: film.id).captures.allSatisfy { $0.revealState == .sealed })
        let run = try XCTUnwrap(repository.developmentRun(filmID: film.id))
        let firstMaster = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .master))
        let preserved = try Data(contentsOf: firstMaster.url)
        try source.write(to: secondSource.url)
        for sequence in 1...2 { try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: sequence, export: false) }
        let resumed = try FilmProcessor(root: root)
        try await resumed.develop(filmID: film.id)
        XCTAssertEqual(try repository.film(id: film.id).developmentState, .developed)
        XCTAssertEqual(try repository.developmentRun(filmID: film.id)?.assignments, run.assignments)
        XCTAssertEqual(try Data(contentsOf: firstMaster.url), preserved)
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 2, kind: .source))
        let secondOriginal = try await resumed.photo(filmID: film.id, sequence: 2)
        let edited = try await resumed.saveRecipe(filmID: film.id, sequence: 1, recipe: DarkroomRecipe(printExposureStops: 0.5))
        XCTAssertNotEqual(edited, preserved)
        let reset = try await resumed.saveRecipe(filmID: film.id, sequence: 1, recipe: .original)
        let secondAfter = try await resumed.photo(filmID: film.id, sequence: 2)
        XCTAssertEqual(reset, preserved)
        XCTAssertEqual(secondAfter, secondOriginal)
        XCTAssertThrowsError(try repository.writeDevelopedMaster(filmID: film.id, sequenceNumber: 1, data: Data("reroll".utf8)))
    }

    func testInstantWaitsForVerifiedPrintAndNeverRerendersEarlierPrints() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture)
        let source = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-photo.jpg"))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        try repository.savePhotoCapture(filmID: film.id, sourceData: source)
        XCTAssertThrowsError(try repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: film.id)
        let first = try await processor.photo(filmID: film.id, sequence: 1)
        try repository.savePhotoCapture(filmID: film.id, sourceData: source)
        XCTAssertEqual(try repository.film(id: film.id).captures.map(\.revealState), [.revealed, .sealed])
        let relaunched = try FilmProcessor(root: root)
        try await relaunched.develop(filmID: film.id)
        let firstAfter = try await relaunched.photo(filmID: film.id, sequence: 1)
        XCTAssertEqual(firstAfter, first)
        XCTAssertEqual(try repository.film(id: film.id).captures.map(\.revealState), [.revealed, .revealed])
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        try await relaunched.discard(filmID: film.id, sequence: 1)
        try await relaunched.develop(filmID: film.id)
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .master))
        XCTAssertEqual(try repository.film(id: film.id).remainingExposures, 8)
    }

    func testRendererUpdateKeepsDevelopedMediaUsableAndRendersOnlyNewCaptures() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.16
        let fixture = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture, settings: settings)
        let clip = fixture.appendingPathComponent("synthetic-developed-movie.mov")
        let photo = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-photo.jpg"))
        let repository = try FilmRepository(rootURL: root)
        let processor = try FilmProcessor(root: root)

        let movie = try repository.createFilm(camera: CameraCatalog.super8HomeMovie, title: "Synthetic", movieOrientation: .landscape)
        let seconds = try await VerifiedMedia.movie(at: clip).durationSeconds ?? 0
        for _ in 0..<2 {
            try repository.saveMovieClip(filmID: movie.id, sourceData: Data(contentsOf: clip), durationSeconds: seconds, orientation: .landscape)
        }
        try repository.completeEarly(filmID: movie.id)
        try await processor.develop(filmID: movie.id)
        try storeAsEarlierRenderer(repository, filmID: movie.id)
        try await processor.discard(filmID: movie.id, sequence: 1)
        XCTAssertTrue(try repository.film(id: movie.id).canPlaybackDevelopedMovie)
        XCTAssertTrue(try repository.assembledMovieExists(filmID: movie.id))

        let pack = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic pack")
        try repository.savePhotoCapture(filmID: pack.id, sourceData: photo)
        try await processor.develop(filmID: pack.id)
        try storeAsEarlierRenderer(repository, filmID: pack.id)
        try repository.savePhotoCapture(filmID: pack.id, sourceData: photo)
        try await processor.develop(filmID: pack.id)
        XCTAssertEqual(try repository.film(id: pack.id).captures.map(\.revealState), [.revealed, .revealed])
    }

    /// Stores the Development run as if an earlier renderer had assigned every treatment.
    private func storeAsEarlierRenderer(_ repository: FilmRepository, filmID: UUID) throws {
        let stored = try XCTUnwrap(repository.database.value(filmID: filmID, key: "development"))
        let current = "\"treatmentVersion\":\"\(NativePhotoRenderer.treatmentVersion)\""
        let json = try XCTUnwrap(String(data: stored, encoding: .utf8))
        XCTAssertTrue(json.contains(current))
        let earlier = json.replacingOccurrences(of: current, with: "\"treatmentVersion\":\"film-look-0-earlier\"")
        try repository.database.setValue(filmID: filmID, key: "development", data: Data(earlier.utf8))
    }

    func testRealMovieDiscardReassemblesOnlyRetainedDevelopedClipThenKeepsEmptyPlaceholders() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.16
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture, settings: settings)
        let source = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-movie.mov"))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Synthetic", movieOrientation: .portrait, filmStock: .color)
        for _ in 0..<2 {
            try repository.saveMovieClip(filmID: film.id, sourceData: source, durationSeconds: manifest.movie.durationSeconds, orientation: .landscape)
        }
        try repository.completeEarly(filmID: film.id)
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: film.id)
        let oldMovie = try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)
        let clip = try repository.revealedAsset(filmID: film.id, sequenceNumber: 2, kind: .clip)
        let retainedBytes = try Data(contentsOf: clip.url)
        let assignments = try repository.developmentRun(filmID: film.id)?.assignments
        try await processor.discard(filmID: film.id, sequence: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldMovie.url.path))
        XCTAssertEqual(try Data(contentsOf: clip.url), retainedBytes)
        XCTAssertEqual(try repository.developmentRun(filmID: film.id)?.assignments, assignments)
        let movie = try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)
        let verified = try await VerifiedMedia.movie(at: movie.url)
        XCTAssertEqual(try XCTUnwrap(verified.durationSeconds), manifest.movie.durationSeconds, accuracy: 0.01)
        try await processor.discard(filmID: film.id, sequence: 2)
        let empty = try repository.film(id: film.id)
        XCTAssertEqual(empty.discardedPlaceholderSequenceNumbers, [1, 2])
        XCTAssertFalse(empty.canPlaybackDevelopedMovie)
        XCTAssertEqual(empty.consumedMovieFrames, try XCTUnwrap(MovieFrames.count(seconds: manifest.movie.durationSeconds)) * 2)
        XCTAssertThrowsError(try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie))
        try await processor.deleteFilm(filmID: film.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Work/\(film.id)").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id)").path))
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("FilmProcessorTests-\(UUID())")
    }
}
