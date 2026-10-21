import FilmDomain
@testable import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import RenderFixtures
import XCTest

/// PRD 2.1 slice 4 through the production processor: a Film keeps the treatment version its Camera package recorded at
/// Load Film. A Film loaded before each Camera had its own look, still unfinished when the app was updated, develops
/// with version 2; an Instant pack loaded under version 3 keeps the contrast it had before the study of preserved
/// 1970s prints; a Film loaded today develops with version 4 (ADR 0013, CAM-01, RK-11).
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
        CameraPackage(id: camera.id, displayName: camera.displayName, medium: camera.medium, capacity: camera.capacity,
                      revealRule: camera.revealRule, supportsBuiltInSoundtrack: camera.supportsBuiltInSoundtrack,
                      treatmentVersion: "film-look-3")
    }

    func testAnUnfinishedRollFromBeforeTheUpdateDevelopsWithVersionTwoAndANewRollWithVersionFour() async throws {
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
        XCTAssertEqual(try reopened.film(id: today.id).camera.treatmentVersion, "film-look-4")
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: earlier.id)
        try await processor.develop(filmID: today.id)

        for (film, version) in [(earlier, "film-look-2-provisional"), (today, "film-look-4")] {
            let run = try XCTUnwrap(reopened.developmentRun(filmID: film.id))
            XCTAssertEqual(run.treatmentVersion, version)
            for sequence in [1, 2] {
                let assignment = try XCTUnwrap(run.assignments[sequence])
                XCTAssertEqual(assignment.treatmentVersion, version)
                let master = try Data(contentsOf: reopened.revealedAsset(filmID: film.id, sequenceNumber: sequence, kind: .master).url)
                XCTAssertEqual(master, try NativePhotoRenderer.develop(source: photo, camera: film.camera, seed: assignment.seed,
                                                                       treatmentVersion: version), "\(film.title) \(sequence)")
                XCTAssertNotEqual(master, try NativePhotoRenderer.develop(source: photo, camera: film.camera, seed: assignment.seed,
                    treatmentVersion: version == "film-look-4" ? "film-look-2-provisional" : "film-look-4"))
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
    /// with version 4's.
    func testAnInstantPackLoadedUnderVersionThreeKeepsItsContrastForEveryPrint() async throws {
        let repository = try FilmRepository(rootURL: root)
        let pack = try repository.createFilm(camera: lockedUnderVersionThree(CameraCatalog.instant1970s), title: "Pack")
        let today = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Today")
        let source = try Data(contentsOf: photo)
        try repository.savePhotoCapture(filmID: pack.id, sourceData: source)
        // Reopened as the updated app would: the stored package still records version 3.
        let reopened = try FilmRepository(rootURL: root)
        XCTAssertEqual(try reopened.film(id: pack.id).camera.treatmentVersion, "film-look-3")
        XCTAssertEqual(try reopened.film(id: today.id).camera.treatmentVersion, "film-look-4")
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
        XCTAssertEqual(assignment.treatmentVersion, "film-look-4")
        let print = try Data(contentsOf: reopened.revealedAsset(filmID: today.id, sequenceNumber: 1, kind: .master).url)
        XCTAssertEqual(print, try NativePhotoRenderer.develop(source: photo, camera: today.camera, seed: assignment.seed,
                                                              treatmentVersion: "film-look-4"))
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
