import FilmDomain
@testable import FilmPersistence
import FilmRuntime
import Foundation
import ImageIO
import RenderCore
import RenderFixtures
import XCTest

/// PRD 2.1 slice 4 through the production processor: a Film keeps the treatment version its Camera package recorded at
/// Load Film. A Film loaded before each Camera had its own look, still unfinished when the app was updated, develops
/// with version 2; an Instant pack loaded under version 3 keeps the contrast it had before the study of preserved
/// 1970s prints; an Instant pack loaded under version 4 develops its flash-lit prints with no flash look; a Film loaded
/// today develops with version 5 (ADR 0013, CAM-01, RK-11).
final class TreatmentVersionDevelopmentTests: XCTestCase {
    private var root: URL!
    private var fixtures: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TreatmentVersionDevelopmentTests-\(UUID())")
        fixtures = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 160; settings.photoHeight = 120
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.2
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private var photo: URL { fixtures.appendingPathComponent("synthetic-developed-photo.jpg") }
    private var clip: URL { fixtures.appendingPathComponent("synthetic-developed-movie.mov") }

    /// A package as the version 2 build locked it into a Film: everything today's has, without a treatment version.
    private func locked(_ camera: CameraPackage) -> CameraPackage {
        CameraPackage(id: camera.id, displayName: camera.displayName, medium: camera.medium, capacity: camera.capacity,
                      revealRule: camera.revealRule, supportsBuiltInSoundtrack: camera.supportsBuiltInSoundtrack)
    }

    /// A package as the version 3 build locked it into a Film: today's, recording version 3.
    private func lockedUnderVersionThree(_ camera: CameraPackage) -> CameraPackage {
        lockedUnder("film-look-3", camera)
    }

    private func lockedUnder(_ version: String, _ camera: CameraPackage) -> CameraPackage {
        CameraPackage(id: camera.id, displayName: camera.displayName, medium: camera.medium, capacity: camera.capacity,
                      revealRule: camera.revealRule, supportsBuiltInSoundtrack: camera.supportsBuiltInSoundtrack,
                      treatmentVersion: version)
    }

    /// The fixture photo encoded again with its Exif Flash value: 1 where the flash fired, 16 where it was off. Both are
    /// encoded the same way, so they differ only in that value.
    private func photo(flashFired: Bool) throws -> Data {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(photo as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifFlash as String: flashFired ? 1 : 16]
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func testAnUnfinishedRollFromBeforeTheUpdateDevelopsWithVersionTwoAndANewRollWithTodaysVersion() async throws {
        let repository = try FilmRepository(rootURL: root)
        let earlier = try repository.createFilm(camera: locked(CameraCatalog.disposable1990s), title: "Earlier")
        let today = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Today")
        let source = try Data(contentsOf: photo)
        for film in [earlier, today] {
            for _ in 0..<2 { try repository.savePhotoCapture(filmID: film.id, sourceData: source) }
            try repository.completeEarly(filmID: film.id)
        }
        // Reopened as the updated app would: the earlier Film's stored package still has no treatment version.
        let reopened = try FilmRepository(rootURL: root)
        XCTAssertNil(try reopened.film(id: earlier.id).camera.treatmentVersion)
        XCTAssertEqual(try reopened.film(id: today.id).camera.treatmentVersion, "film-look-5")
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: earlier.id)
        try await processor.develop(filmID: today.id)

        for (film, version) in [(earlier, "film-look-2-provisional"), (today, "film-look-5")] {
            let run = try XCTUnwrap(reopened.developmentRun(filmID: film.id))
            XCTAssertEqual(run.treatmentVersion, version)
            for sequence in [1, 2] {
                let assignment = try XCTUnwrap(run.assignments[sequence])
                XCTAssertEqual(assignment.treatmentVersion, version)
                let master = try Data(contentsOf: reopened.revealedAsset(filmID: film.id, sequenceNumber: sequence, kind: .master).url)
                XCTAssertEqual(master, try NativePhotoRenderer.develop(source: photo, camera: film.camera, seed: assignment.seed,
                                                                       treatmentVersion: version), "\(film.title) \(sequence)")
                XCTAssertNotEqual(master, try NativePhotoRenderer.develop(source: photo, camera: film.camera, seed: assignment.seed,
                    treatmentVersion: version == "film-look-5" ? "film-look-2-provisional" : "film-look-5"))
            }
        }
    }

    /// An Instant pack started before the update keeps developing its prints with version 2, one by one, including
    /// prints exposed after the update.
    func testAnInstantPackStartedBeforeTheUpdateKeepsItsLookForEveryPrint() async throws {
        let repository = try FilmRepository(rootURL: root)
        let pack = try repository.createFilm(camera: locked(CameraCatalog.instant1970s), title: "Pack")
        let processor = try FilmProcessor(root: root)
        let source = try Data(contentsOf: photo)
        for sequence in 1...2 {
            try repository.savePhotoCapture(filmID: pack.id, sourceData: source)
            try await processor.develop(filmID: pack.id)
            let assignment = try XCTUnwrap(repository.developmentRun(filmID: pack.id)?.assignments[sequence])
            XCTAssertEqual(assignment.treatmentVersion, "film-look-2-provisional")
            let print = try Data(contentsOf: repository.revealedAsset(filmID: pack.id, sequenceNumber: sequence, kind: .master).url)
            XCTAssertEqual(print, try NativePhotoRenderer.develop(source: photo, camera: pack.camera, seed: assignment.seed,
                                                                  treatmentVersion: "film-look-2-provisional"))
        }
    }

    /// An Instant pack loaded under version 3, with prints still to expose when the app is updated: every print, the
    /// ones exposed after the update too, develops with version 3's contrast, while a pack loaded today develops
    /// with today's.
    func testAnInstantPackLoadedUnderVersionThreeKeepsItsContrastForEveryPrint() async throws {
        let repository = try FilmRepository(rootURL: root)
        let pack = try repository.createFilm(camera: lockedUnderVersionThree(CameraCatalog.instant1970s), title: "Pack")
        let today = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Today")
        let source = try Data(contentsOf: photo)
        try repository.savePhotoCapture(filmID: pack.id, sourceData: source)
        // Reopened as the updated app would: the stored package still records version 3.
        let reopened = try FilmRepository(rootURL: root)
        XCTAssertEqual(try reopened.film(id: pack.id).camera.treatmentVersion, "film-look-3")
        XCTAssertEqual(try reopened.film(id: today.id).camera.treatmentVersion, "film-look-5")
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: pack.id)
        try reopened.savePhotoCapture(filmID: pack.id, sourceData: source)
        try await processor.develop(filmID: pack.id)
        try reopened.savePhotoCapture(filmID: today.id, sourceData: source)
        try await processor.develop(filmID: today.id)

        for sequence in 1...2 {
            let assignment = try XCTUnwrap(reopened.developmentRun(filmID: pack.id)?.assignments[sequence])
            XCTAssertEqual(assignment.treatmentVersion, "film-look-3")
            let print = try Data(contentsOf: reopened.revealedAsset(filmID: pack.id, sequenceNumber: sequence, kind: .master).url)
            XCTAssertEqual(print, try NativePhotoRenderer.develop(source: photo, camera: pack.camera, seed: assignment.seed,
                                                                  treatmentVersion: "film-look-3"), "Print \(sequence)")
            XCTAssertNotEqual(print, try NativePhotoRenderer.develop(source: photo, camera: pack.camera, seed: assignment.seed,
                                                                     treatmentVersion: "film-look-4"), "Print \(sequence)")
        }
        let assignment = try XCTUnwrap(reopened.developmentRun(filmID: today.id)?.assignments[1])
        XCTAssertEqual(assignment.treatmentVersion, "film-look-5")
        let print = try Data(contentsOf: reopened.revealedAsset(filmID: today.id, sequenceNumber: 1, kind: .master).url)
        XCTAssertEqual(print, try NativePhotoRenderer.develop(source: photo, camera: today.camera, seed: assignment.seed,
                                                              treatmentVersion: "film-look-5"))
    }

    /// The captain, 2026-10-30: an Instant exposure the flash lit develops with harsh direct flash from version 5. A pack
    /// loaded under version 4 keeps that version, so its flash-lit prints develop as the phone's flash lit them, exactly
    /// as the same picture without flash would; a pack loaded today develops them with the flash look, and the same
    /// picture without flash exactly as version 4 does.
    func testOnlyAnInstantPackLoadedTodayDevelopsAFlashLitPrintWithTheFlashLook() async throws {
        let repository = try FilmRepository(rootURL: root)
        let earlier = try repository.createFilm(camera: lockedUnder("film-look-4", CameraCatalog.instant1970s), title: "Pack")
        let today = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Today")
        let flashLit = try photo(flashFired: true), unlit = try photo(flashFired: false)
        let processor = try FilmProcessor(root: root)
        var prints: [String: Data] = [:]
        for (film, name) in [(earlier, "earlier"), (today, "today")] {
            for (sequence, source) in [(1, flashLit), (2, unlit)] {
                try repository.savePhotoCapture(filmID: film.id, sourceData: source)
                try await processor.develop(filmID: film.id)
                prints["\(name) \(sequence)"] = try Data(contentsOf: repository.revealedAsset(
                    filmID: film.id, sequenceNumber: sequence, kind: .master).url)
            }
        }
        let run = try XCTUnwrap(repository.developmentRun(filmID: earlier.id))
        XCTAssertEqual(run.assignments.values.map(\.treatmentVersion), ["film-look-4", "film-look-4"])
        XCTAssertEqual(try repository.developmentRun(filmID: today.id)?.treatmentVersion, "film-look-5")

        func develop(_ source: Data, seed: UInt64, version: String) throws -> Data {
            let url = root.appendingPathComponent("\(UUID()).jpg")
            try source.write(to: url)
            return try NativePhotoRenderer.develop(source: url, camera: CameraCatalog.instant1970s, seed: seed, treatmentVersion: version)
        }
        for (film, name, version) in [(earlier, "earlier", "film-look-4"), (today, "today", "film-look-5")] {
            let assignments = try XCTUnwrap(repository.developmentRun(filmID: film.id)?.assignments)
            let flashSeed = try XCTUnwrap(assignments[1]).seed, unlitSeed = try XCTUnwrap(assignments[2]).seed
            XCTAssertEqual(prints["\(name) 1"], try develop(flashLit, seed: flashSeed, version: version))
            XCTAssertEqual(prints["\(name) 2"], try develop(unlit, seed: unlitSeed, version: version))
            // The unlit picture develops alike in both versions.
            XCTAssertEqual(try develop(unlit, seed: unlitSeed, version: "film-look-4"),
                           try develop(unlit, seed: unlitSeed, version: "film-look-5"), name)
            let sameSeedUnlit = try develop(unlit, seed: flashSeed, version: version)
            if version == "film-look-4" {
                XCTAssertEqual(prints["\(name) 1"], sameSeedUnlit, "Version 4 has no flash look")
            } else {
                XCTAssertNotEqual(prints["\(name) 1"], sameSeedUnlit, "Version 5 develops the flash look")
            }
        }
    }

    /// A 16mm reel loaded before the update develops its clips with version 2; the black-and-white Film Stock it
    /// confirmed at Load Film still applies.
    func testAMovieFromBeforeTheUpdateDevelopsItsClipsWithVersionTwo() async throws {
        let repository = try FilmRepository(rootURL: root)
        let reel = try repository.createFilm(camera: locked(CameraCatalog.cinema16mm), title: "Reel", movieOrientation: .landscape,
                                             filmStock: .blackAndWhite)
        let seconds = try await VerifiedMedia.movie(at: clip).durationSeconds ?? 0
        _ = try repository.saveMovieClip(filmID: reel.id, sourceData: Data(contentsOf: clip), durationSeconds: seconds,
                                         orientation: .landscape)
        try repository.completeEarly(filmID: reel.id)
        try await FilmProcessor(root: root).develop(filmID: reel.id)
        let assignment = try XCTUnwrap(repository.developmentRun(filmID: reel.id)?.assignments[1])
        XCTAssertEqual(assignment.treatmentVersion, "film-look-2-provisional")
        let developed = try Data(contentsOf: repository.revealedAsset(filmID: reel.id, sequenceNumber: 1, kind: .clip).url)
        let expected = root.appendingPathComponent("expected.mov")
        try await NativeMovieRenderer.developClip(source: clip, destination: expected, camera: reel.camera, filmStock: .blackAndWhite,
            seed: assignment.seed, orientation: .landscape, treatmentVersion: "film-look-2-provisional")
        let expectedFrames = try await frameDigests(expected)
        let developedURL = root.appendingPathComponent("developed.mov")
        try developed.write(to: developedURL)
        let developedFrames = try await frameDigests(developedURL)
        XCTAssertEqual(developedFrames, expectedFrames, "Every frame as version 2 develops it")
    }
}
