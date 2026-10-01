import FilmDomain
import FilmPersistence
import RenderCore
import UIKit
import XCTest
@testable import Immerse

@MainActor
final class JournalIntegrationTests: XCTestCase {
    func testExistingFilmDevelopEditResetDiscardArchiveAndDeleteWithoutSubscription() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JournalIntegration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        XCTAssertFalse(model.billing.configured)
        let film = try model.repository.createFilm(camera: CameraCatalog.disposable1990s,
                                                   title: "Synthetic existing Film", access: .subscription)
        let source = try syntheticPhoto()
        for _ in 0..<2 { try model.repository.savePhotoCapture(filmID: film.id, sourceData: source) }
        model.refresh()
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.sealed, .sealed])
        do { _ = try await model.processor.photo(filmID: film.id, sequence: 1); XCTFail("Sealed photo leaked") }
        catch { }
        _ = try model.repository.completeEarly(filmID: film.id, confirmedCaptureCount: 2)
        try await model.develop(film.id)
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.revealed, .revealed])
        XCTAssertTrue(try model.repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        let original = try await model.processor.photo(filmID: film.id, sequence: 1)
        let second = try await model.processor.photo(filmID: film.id, sequence: 2)
        XCTAssertNotNil(DisplayPhoto.image(original))
        let edited = try await model.processor.saveRecipe(filmID: film.id, sequence: 1,
            recipe: DarkroomRecipe(printExposureStops: 0.5, dodgeBurnMasks: [
                LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 0.4)
            ]))
        XCTAssertNotEqual(edited, original)
        let reset = try await model.processor.saveRecipe(filmID: film.id, sequence: 1, recipe: .original)
        XCTAssertEqual(reset, original)
        let unchanged = try await model.processor.photo(filmID: film.id, sequence: 2)
        XCTAssertEqual(unchanged, second)
        try model.chooseOriginals(film.id, sequences: [1, 2], export: false)
        try await model.processor.cleanupSources(filmID: film.id)
        XCTAssertFalse(try model.repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))

        let master = try model.repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .master)
        let revision = model.mediaRevision
        try await model.remove(film.id, sequence: 1)
        XCTAssertNotEqual(model.mediaRevision, revision)
        XCTAssertEqual(model.film(film.id)?.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertEqual(model.film(film.id)?.remainingExposures, 25)
        XCTAssertNotEqual(model.film(film.id)?.completionState, .open)
        XCTAssertFalse(FileManager.default.fileExists(atPath: master.url.path))
        XCTAssertThrowsError(try model.repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .master))
        try model.repository.rename(filmID: film.id, title: "Renamed")
        try model.repository.setArchived(filmID: film.id, archived: true)
        let reopened = try JournalModel(root: root)
        XCTAssertEqual(reopened.film(film.id)?.title, "Renamed")
        XCTAssertEqual(reopened.film(film.id)?.isArchived, true)
        let retained = try await reopened.processor.photo(filmID: film.id, sequence: 2)
        XCTAssertEqual(retained, second)
        try await reopened.remove(film.id)
        XCTAssertNil(reopened.film(film.id))
        XCTAssertTrue(try reopened.repository.allFilms().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id)").path))
    }

    func testEmptyFilmCannotDevelopAndCanBeDeleted() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EmptyJournalIntegration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        let film = try model.repository.createFilm(camera: CameraCatalog.super8HomeMovie,
                                                   title: "Empty synthetic Movie", movieOrientation: .portrait)
        model.refresh()
        XCTAssertFalse(try XCTUnwrap(model.film(film.id)).canStartDevelopment)
        XCTAssertThrowsError(try model.repository.completeEarly(filmID: film.id, confirmedCaptureCount: 0))
        try await model.remove(film.id)
        XCTAssertNil(model.film(film.id))
    }

    private func syntheticPhoto() throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 96), format: format).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 96))
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 64, y: 0, width: 64, height: 96))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }
}
