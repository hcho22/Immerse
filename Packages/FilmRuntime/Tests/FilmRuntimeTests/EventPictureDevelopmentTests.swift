import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import ImageIO
import RenderCore
import RenderFixtures
import XCTest

/// An event Roll's pictures (v2 PRD V2-FR-33, V2-FR-34, V2-FR-36): each develops on the phone, soon after it is saved and
/// unseen, as exactly what the Roll's own Development makes of it; the Instant's print is the one developed at the
/// camera; the viewing copy is small and carries no metadata; and the Roll's originals go only from an event Roll.
final class EventPictureDevelopmentTests: XCTestCase {
    private var root: URL!
    private var fixtures: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("EventPictureDevelopmentTests-\(UUID())")
        fixtures = root.deletingLastPathComponent().appendingPathComponent("\(root.lastPathComponent)-Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.2
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
    }

    override func tearDown() {
        for url in [root, fixtures] { try? FileManager.default.removeItem(at: url!) }
    }

    private var photo: Data { get throws { try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg")) } }

    private func eventRoll(_ repository: FilmRepository, camera: CameraPackage, filmStock: FilmStock? = nil) throws -> Film {
        try repository.createFilm(camera: camera, title: "Ana & Leo", filmStock: filmStock, access: .groupRoll(eventID: "event-1"))
    }

    func testEachPictureIsWhatTheRollsOwnDevelopmentMakesAndTheRollStaysSealed() async throws {
        let repository = try FilmRepository(rootURL: root)
        var rolls = [
            try eventRoll(repository, camera: CameraCatalog.disposable1990s),
            try eventRoll(repository, camera: CameraCatalog.mediumFormat6x6, filmStock: .blackAndWhite),
        ]
        if NativePhotoRenderer.readsFilmTables {
            rolls.append(try eventRoll(repository, camera: CameraCatalog.mediumFormat6x6, filmStock: .color))
        }
        for roll in rolls {
            for _ in 0..<2 { try repository.savePhotoCapture(filmID: roll.id, sourceData: photo) }
        }
        var developed: [UUID: [Int: Data]] = [:]
        for roll in rolls {
            for sequence in [1, 2] {
                developed[roll.id, default: [:]][sequence] = try EventPictureDevelopment.developed(root: root, filmID: roll.id,
                                                                                                   sequenceNumber: sequence)
            }
            let film = try repository.film(id: roll.id)
            XCTAssertEqual(film.captures.map(\.revealState), [.sealed, .sealed], "Developing an event picture shows it to no one")
            XCTAssertNil(try repository.developmentRun(filmID: roll.id))
            XCTAssertNil(try repository.mediaAsset(filmID: roll.id, sequenceNumber: 1, kind: .master))
        }
        // The same Rolls developed by Development itself make the same bytes.
        let processor = try FilmProcessor(root: root)
        for roll in rolls {
            try repository.completeEarly(filmID: roll.id)
            try await processor.develop(filmID: roll.id)
            for sequence in [1, 2] {
                let master = try repository.revealedAsset(filmID: roll.id, sequenceNumber: sequence, kind: .master)
                XCTAssertEqual(try Data(contentsOf: master.url), developed[roll.id]?[sequence], "\(roll.camera.id) \(sequence)")
            }
        }
    }

    func testAnInstantPictureIsThePrintDevelopedAtTheCamera() async throws {
        let repository = try FilmRepository(rootURL: root)
        let roll = try eventRoll(repository, camera: CameraCatalog.instant1970s)
        try repository.savePhotoCapture(filmID: roll.id, sourceData: photo)
        XCTAssertThrowsError(try EventPictureDevelopment.developed(root: root, filmID: roll.id, sequenceNumber: 1))
        try await FilmProcessor(root: root).develop(filmID: roll.id)
        let master = try repository.revealedAsset(filmID: roll.id, sequenceNumber: 1, kind: .master)
        XCTAssertEqual(try EventPictureDevelopment.developed(root: root, filmID: roll.id, sequenceNumber: 1), try Data(contentsOf: master.url))
    }

    func testAPersonalFilmIsNeverAnEventPicture() throws {
        let repository = try FilmRepository(rootURL: root)
        let personal = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Mine")
        try repository.savePhotoCapture(filmID: personal.id, sourceData: photo)
        XCTAssertThrowsError(try EventPictureDevelopment.developed(root: root, filmID: personal.id, sequenceNumber: 1)) {
            XCTAssertEqual($0 as? PersistenceError, .notAnEventRoll)
        }
        XCTAssertThrowsError(try repository.removeEventOriginal(filmID: personal.id, sequenceNumber: 1)) {
            XCTAssertEqual($0 as? PersistenceError, .notAnEventRoll)
        }
        XCTAssertThrowsError(try repository.retireEventCapture(filmID: personal.id, sequenceNumber: 1)) {
            XCTAssertEqual($0 as? PersistenceError, .notAnEventRoll)
        }
        XCTAssertNotNil(try repository.mediaAsset(filmID: personal.id, sequenceNumber: 1, kind: .source))
    }

    func testOriginalsGoOnConfirmationAndRetiredCapturesKeepTheirExposure() throws {
        let repository = try FilmRepository(rootURL: root)
        let roll = try eventRoll(repository, camera: CameraCatalog.disposable1990s)
        for _ in 0..<3 { try repository.savePhotoCapture(filmID: roll.id, sourceData: photo) }
        let sourcePath = try XCTUnwrap(try repository.mediaAsset(filmID: roll.id, sequenceNumber: 1, kind: .source)).url
        try repository.removeEventOriginal(filmID: roll.id, sequenceNumber: 1)
        try repository.removeEventOriginal(filmID: roll.id, sequenceNumber: 1)
        XCTAssertNil(try repository.mediaAsset(filmID: roll.id, sequenceNumber: 1, kind: .source))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourcePath.path))
        try repository.retireEventCapture(filmID: roll.id, sequenceNumber: 2)
        try repository.retireEventCapture(filmID: roll.id, sequenceNumber: 2)
        let film = try repository.film(id: roll.id)
        XCTAssertEqual(film.captures.map(\.revealState), [.sealed, .discardedPlaceholder, .sealed])
        XCTAssertEqual(film.remainingExposures, 24, "No exposure comes back")
        XCTAssertNil(try repository.mediaAsset(filmID: roll.id, sequenceNumber: 2, kind: .source))
    }

    func testARollMadeAgainContinuesAfterTheExposuresTheServerCountsAsUsed() throws {
        let repository = try FilmRepository(rootURL: root)
        let roll = try repository.createEventRoll(eventID: "event-1", camera: CameraCatalog.disposable1990s, title: "Ana & Leo",
                                                  filmStock: nil, exposuresUsed: 10)
        XCTAssertEqual(try repository.filmAccess(filmID: roll.id), .groupRoll(eventID: "event-1"))
        XCTAssertEqual(try repository.film(id: roll.id).remainingExposures, 17)
        let next = try repository.savePhotoCapture(filmID: roll.id, sourceData: photo)
        XCTAssertEqual(next.captures.last?.sequenceNumber, 11, "The next picture takes the Roll's next exposure, never one the server holds")
        let film = try repository.film(id: roll.id)
        XCTAssertEqual(film.captures.map(\.revealState), Array(repeating: .discardedPlaceholder, count: 10) + [.sealed])
        XCTAssertEqual(film.remainingExposures, 16)

        let fresh = try repository.createEventRoll(eventID: "event-2", camera: CameraCatalog.instant1970s, title: "Fresh",
                                                   filmStock: nil, exposuresUsed: 0)
        XCTAssertEqual(fresh.captures, [])
        XCTAssertEqual(fresh.completionState, .open)

        let spent = try repository.createEventRoll(eventID: "event-3", camera: CameraCatalog.instant1970s, title: "Spent",
                                                   filmStock: nil, exposuresUsed: 99)
        XCTAssertEqual(spent.captures.count, 10)
        XCTAssertEqual(spent.completionState, .capacityFull)
        XCTAssertThrowsError(try repository.savePhotoCapture(filmID: spent.id, sourceData: photo))
    }

    func testTheViewingCopyIsSmallAndCarriesNoMetadata() throws {
        let developed = try photo
        let copy = try EventPictureDevelopment.viewingCopy(of: developed, longestSide: 320)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(copy as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int)
        XCTAssertEqual(max(width, height), 320)
        XCTAssertLessThan(copy.count, developed.count)
        for key in [kCGImagePropertyGPSDictionary, kCGImagePropertyIPTCDictionary, kCGImagePropertyTIFFDictionary] {
            XCTAssertNil(properties[key], "\(key)")
        }
        // ImageIO writes a JPEG's color space and size as Exif; nothing else, so nothing names a person or a place.
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        XCTAssertTrue(Set(exif.keys.map { $0 as String })
            .isSubset(of: [kCGImagePropertyExifColorSpace, kCGImagePropertyExifPixelXDimension,
                           kCGImagePropertyExifPixelYDimension].map { $0 as String }), "\(exif.keys)")
    }
}
