import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import RenderFixtures
import XCTest

final class FilmProcessorTests: XCTestCase {
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

    func testRealMovieDiscardReassemblesOnlyRetainedDevelopedClipThenKeepsEmptyPlaceholders() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.16
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixture, settings: settings)
        let source = try Data(contentsOf: fixture.appendingPathComponent("synthetic-developed-movie.mov"))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Synthetic", movieOrientation: .portrait)
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
        XCTAssertEqual(empty.consumedMovieSeconds, manifest.movie.durationSeconds * 2)
        XCTAssertThrowsError(try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie))
        try await processor.deleteFilm(filmID: film.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Work/\(film.id)").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id)").path))
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("FilmProcessorTests-\(UUID())")
    }
}
