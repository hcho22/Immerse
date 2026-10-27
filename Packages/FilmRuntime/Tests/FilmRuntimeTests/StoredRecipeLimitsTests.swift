@testable import FilmPersistence
import FilmDomain
import FilmRuntime
import Foundation
import ImageIO
import NativeAdapters
import RenderCore
import RenderFixtures
import XCTest

/// Stored Darkroom recipes against the limits of 2026-10-13 (DEC-11), through the production repository and processor.
/// A recipe the build before them stored opens and prints. A stored value outside the limits, which only a build with
/// wider limits or a damaged store can leave, is refused wherever the print would be made and nowhere clamped; the
/// developed master is untouched and Reset to Original prints it again. The same holds for a recipe at today's limits
/// meeting the earlier build after a revert, whose narrower limits refuse it the same way.
final class StoredRecipeLimitsTests: XCTestCase {
    private var root: URL!
    private var repository: FilmRepository!
    private var processor: FilmProcessor!
    private var film: Film!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("StoredRecipeLimitsTests-\(UUID())")
        let fixtures = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        let source = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        repository = try FilmRepository(rootURL: root)
        film = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Roll")
        for _ in 0..<3 { try repository.savePhotoCapture(filmID: film.id, sourceData: source) }
        try repository.completeEarly(filmID: film.id)
        processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: film.id)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testARecipeStoredByTheEarlierBuildOpensAndPrints() async throws {
        // The stored form the build before the wider limits wrote, at its own limits: 2 stops and a 1 stop stroke.
        let stored = #"{"printExposureStops":-2,"contrastGrade":5,"colorFiltration":{"cyan":30,"magenta":-30,"yellow":4},"dodgeBurnMasks":[{"kind":"dodge","points":[{"x":0.25,"y":0.5}],"exposureStops":1},{"kind":"burn","points":[{"x":0.75,"y":0.5}],"exposureStops":0.4}]}"#
        try repository.database.setValue(filmID: film.id, key: "recipe-1", data: Data(stored.utf8))
        let recipe = DarkroomRecipe(printExposureStops: -2, contrastGrade: 5,
            colorFiltration: ColorFiltration(cyan: 30, magenta: -30, yellow: 4),
            dodgeBurnMasks: [LocalMask(kind: .dodge, points: [MaskPoint(x: 0.25, y: 0.5)], exposureStops: 1),
                             LocalMask(kind: .burn, points: [MaskPoint(x: 0.75, y: 0.5)], exposureStops: 0.4)])
        XCTAssertEqual(try repository.darkroomRecipe(filmID: film.id, sequence: 1), recipe)
        let master = try Data(contentsOf: repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .master).url)
        let printed = try await processor.photo(filmID: film.id, sequence: 1)
        XCTAssertEqual(printed, try NativePhotoRenderer.print(master: master, recipe: recipe, camera: film.camera))
        XCTAssertNotEqual(printed, master)
        // Saving it again, unchanged, is accepted.
        let saved = try await processor.saveRecipe(filmID: film.id, sequence: 1, recipe: recipe)
        XCTAssertEqual(saved, printed)
    }

    func testARecipeAtTheLimitsIsSavedReadBackAndExported() async throws {
        let recipe = DarkroomRecipe(printExposureStops: 3, contrastGrade: 5,
            colorFiltration: ColorFiltration(cyan: 30, magenta: -30, yellow: 30),
            dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 3),
                             LocalMask(kind: .dodge, points: [MaskPoint(x: 0.1, y: 0.1)], exposureStops: 3)])
        let printed = try await processor.saveRecipe(filmID: film.id, sequence: 2, recipe: recipe)
        XCTAssertEqual(try repository.darkroomRecipe(filmID: film.id, sequence: 2), recipe)
        let writer = RecordingWriter()
        try await processor.export(filmID: film.id, sequences: [2], originals: false,
                                   coordinator: PhotoExportCoordinator(authorizer: Authorized(), writer: writer))
        let exported = await writer.saved
        XCTAssertEqual(exported, [printed])
    }

    func testQuarterTurnRecipeExportsThePrintInItsTurnedShape() async throws {
        let master = try Data(contentsOf: repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .master).url)
        let masterSize = try imageSize(master)
        let turned = try await processor.saveRecipe(
            filmID: film.id, sequence: 1, recipe: DarkroomRecipe(rotationQuarterTurns: 1)
        )
        XCTAssertEqual(try imageSize(turned), [masterSize[1], masterSize[0]])

        let writer = RecordingWriter()
        try await processor.export(filmID: film.id, sequences: [1], originals: false,
                                   coordinator: PhotoExportCoordinator(authorizer: Authorized(), writer: writer))
        let exported = await writer.saved
        XCTAssertEqual(exported, [turned])
        XCTAssertEqual(try imageSize(try XCTUnwrap(exported.first)), [masterSize[1], masterSize[0]])
    }

    private func imageSize(_ data: Data) throws -> [Int] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return [image.width, image.height]
    }

    func testAStoredValueOutsideTheLimitsIsRefusedNotClampedAndResetPrintsTheMasterAgain() async throws {
        let master = try Data(contentsOf: repository.revealedAsset(filmID: film.id, sequenceNumber: 2, kind: .master).url)
        for stored in [#"{"printExposureStops":3.5,"dodgeBurnMasks":[]}"#,
                       #"{"printExposureStops":-3.1,"dodgeBurnMasks":[]}"#,
                       #"{"printExposureStops":0,"dodgeBurnMasks":[{"kind":"dodge","points":[{"x":0.5,"y":0.5}],"exposureStops":4}]}"#,
                       #"{"printExposureStops":0,"colorFiltration":{"cyan":31,"magenta":0,"yellow":0},"dodgeBurnMasks":[]}"#,
                       #"{"printExposureStops":0,"contrastGrade":6,"dodgeBurnMasks":[]}"#] {
            try repository.database.setValue(filmID: film.id, key: "recipe-2", data: Data(stored.utf8))
            // The stored recipe is read as it is, so the Darkroom opens on it.
            let recipe = try repository.darkroomRecipe(filmID: film.id, sequence: 2)
            XCTAssertNotEqual(recipe, .original, stored)
            // The print is refused wherever it would be made: on screen, on saving the recipe again, and in Photos.
            do { _ = try await processor.photo(filmID: film.id, sequence: 2); XCTFail("Printed \(stored)") }
            catch { XCTAssertEqual(error as? NativeRenderError, .invalidRecipe, stored) }
            do { _ = try await processor.saveRecipe(filmID: film.id, sequence: 2, recipe: recipe); XCTFail("Saved \(stored)") }
            catch { XCTAssertEqual(error as? NativeRenderError, .invalidRecipe, stored) }
            // Save Developed to Photos stops before it writes anything, though the print is second of three.
            let writer = RecordingWriter()
            do {
                try await processor.export(filmID: film.id, sequences: [1, 2, 3], originals: false,
                                           coordinator: PhotoExportCoordinator(authorizer: Authorized(), writer: writer))
                XCTFail("Exported \(stored)")
            } catch { XCTAssertEqual(error as? NativeRenderError, .invalidRecipe, stored) }
            let written = await writer.saved
            XCTAssertTrue(written.isEmpty, stored)
            // Nothing was changed: the recipe is still as stored, the master is whole and the other prints print.
            XCTAssertEqual(try repository.database.value(filmID: film.id, key: "recipe-2"), Data(stored.utf8))
            XCTAssertEqual(try Data(contentsOf: repository.revealedAsset(filmID: film.id, sequenceNumber: 2, kind: .master).url), master)
            _ = try await processor.photo(filmID: film.id, sequence: 1)
            _ = try await processor.photo(filmID: film.id, sequence: 3)
        }
        // Reset to Original, saved, prints the developed master again, and the Film saves to Photos.
        let reset = try await processor.saveRecipe(filmID: film.id, sequence: 2, recipe: .original)
        XCTAssertEqual(reset, master)
        let again = try await processor.photo(filmID: film.id, sequence: 2)
        XCTAssertEqual(again, master)
        let writer = RecordingWriter()
        try await processor.export(filmID: film.id, sequences: [1, 2, 3], originals: false,
                                   coordinator: PhotoExportCoordinator(authorizer: Authorized(), writer: writer))
        let written = await writer.saved
        XCTAssertEqual(written.count, 3)
        XCTAssertEqual(written[1], master)
    }
}

private struct Authorized: PhotoLibraryAuthorizing {
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus { .authorized }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus { .authorized }
}

private actor RecordingWriter: PhotoLibraryWriting {
    private(set) var saved: [Data] = []
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        saved.append(try Data(contentsOf: request.fileURL))
        return PhotoExportReceipt(localIdentifier: "synthetic-\(saved.count)")
    }
}
