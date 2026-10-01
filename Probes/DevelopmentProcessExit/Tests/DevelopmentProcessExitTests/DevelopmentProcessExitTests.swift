import DevelopmentExitEvidence
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import RenderFixtures
import XCTest

@MainActor final class DevelopmentProcessExitTests: XCTestCase {
    func testEveryCameraAtEveryExistingDevelopmentBoundary() async throws {
        for camera in CameraID.allCases {
            for boundary in ExitBoundary.allCases {
                let fixture = try await Fixture(camera: camera, label: boundary.rawValue)
                let original = try await fixture.snapshot("prepared")
                let stopped = try exit(fixture, boundary: boundary)
                XCTAssertEqual(stopped.film.savedCaptureCount, 1)
                XCTAssertNotNil(stopped.assets["source-1"])
                if boundary == .beforeBegin { XCTAssertNil(stopped.run) }
                else { XCTAssertNotNil(stopped.run?.assignments[1]) }
                let persisted = [.afterPersistence, .beforeReveal, .beforeCleanup].contains(boundary)
                XCTAssertEqual(stopped.assets[fixture.developedKey] != nil, persisted)
                XCTAssertEqual(stopped.film.captures.first?.revealState, boundary == .beforeCleanup ? .revealed : .sealed)
                try fixture.repository.recover()
                let recovered = try await fixture.snapshot("recovered-before-resume")
                XCTAssertFalse(recovered.privateFiles.contains { $0.hasPrefix("Work/") })
                XCTAssertEqual(recovered.film, stopped.film)
                XCTAssertEqual(recovered.assets, stopped.assets)
                try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
                let resumed = try await fixture.snapshot("resumed")
                assertPreserved(stopped, resumed)
                XCTAssertEqual(resumed.film.captures.map(\.id), original.film.captures.map(\.id))
                XCTAssertEqual(resumed.film.captures.map(\.savedAt), original.film.captures.map(\.savedAt))
                XCTAssertEqual(resumed.film.completionState, original.film.completionState)
                XCTAssertTrue(resumed.film.captures.allSatisfy { $0.revealState == .revealed })
                XCTAssertNil(resumed.assets["source-1"])
                XCTAssertNotNil(resumed.assets[fixture.developedKey])
                if camera == .instant1970s { XCTAssertEqual(resumed.film.completionState, .open) }
                if fixture.film.camera.medium == .movie { XCTAssertNotNil(resumed.assets["movie-0"]) }
                XCTAssertFalse(resumed.privateFiles.contains { $0.hasPrefix("Work/") })
                try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
                let repeated = try await fixture.snapshot("repeated")
                XCTAssertEqual(repeated.film, resumed.film)
                XCTAssertEqual(repeated.run, resumed.run)
                XCTAssertEqual(repeated.assets.filter { !$0.key.hasPrefix("movie-") },
                               resumed.assets.filter { !$0.key.hasPrefix("movie-") })
                print("DEVELOPMENT_EXIT camera=\(camera) boundary=\(boundary) exit=81 recovered=1 evidence=\(fixture.directory.path)")
            }
        }
    }

    func testInstantSecondPrintExitPreservesFirstPrintAndOpenCapacity() async throws {
        let fixture = try await Fixture(camera: .instant1970s, label: "second-print")
        try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
        let first = try await fixture.snapshot("first-revealed")
        try fixture.repository.savePhotoCapture(filmID: fixture.film.id, sourceData: fixture.photo)
        try fixture.repository.chooseOriginalExport(filmID: fixture.film.id, sequenceNumber: 2, export: false)
        let stopped = try exit(fixture, boundary: .beforeReveal, sequence: 2)
        XCTAssertEqual(stopped.film.captures.map(\.revealState), [.revealed, .sealed])
        XCTAssertEqual(stopped.assets["master-1"], first.assets["master-1"])
        try fixture.repository.recover()
        try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
        let resumed = try await fixture.snapshot("resumed")
        assertPreserved(stopped, resumed)
        XCTAssertEqual(resumed.film.captures.map(\.revealState), [.revealed, .revealed])
        XCTAssertEqual(resumed.film.remainingExposures, 8)
        XCTAssertEqual(resumed.film.completionState, .open)
        XCTAssertFalse(resumed.assets.keys.contains { $0.hasPrefix("source-") })
        print("DEVELOPMENT_EXIT instant-second exit=81 evidence=\(fixture.directory.path)")
    }

    func testMovieDiscardExitRetiresOldAssemblyAndOnlySurvivingClipReturns() async throws {
        for camera in [CameraID.super8HomeMovie, .cinema16mm] {
            let fixture = try await Fixture(camera: camera, label: "discard-reassembly", count: 2)
            let owner = try FilmProcessor(root: fixture.root)
            try await owner.develop(filmID: fixture.film.id)
            let original = try await fixture.snapshot("original")
            let oldMovie = try fixture.repository.revealedAsset(filmID: fixture.film.id, sequenceNumber: 0, kind: .movie).url
            let stopped = try exit(fixture, boundary: .afterAssignments, operation: "discardFirst")
            XCTAssertFalse(FileManager.default.fileExists(atPath: oldMovie.path))
            XCTAssertEqual(stopped.film.discardedPlaceholderSequenceNumbers, [1])
            XCTAssertNil(stopped.assets["movie-0"])
            XCTAssertNil(stopped.assets["clip-1"])
            XCTAssertEqual(stopped.assets["clip-2"], original.assets["clip-2"])
            try fixture.repository.recover()
            try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
            let resumed = try await fixture.snapshot("resumed")
            assertPreserved(stopped, resumed)
            XCTAssertEqual(resumed.film.discardedPlaceholderSequenceNumbers, [1])
            XCTAssertNil(resumed.assets["clip-1"])
            XCTAssertEqual(resumed.assets["clip-2"], original.assets["clip-2"])
            XCTAssertNotNil(resumed.assets["movie-0"])
            let output = try fixture.repository.revealedAsset(filmID: fixture.film.id, sequenceNumber: 0, kind: .movie)
            let verification = try await VerifiedMedia.movie(at: output.url)
            XCTAssertEqual(try XCTUnwrap(verification.durationSeconds), fixture.duration, accuracy: 0.01)
            XCTAssertEqual(resumed.film.consumedMovieSeconds, original.film.consumedMovieSeconds)
            print("DEVELOPMENT_EXIT discard camera=\(camera) exit=81 evidence=\(fixture.directory.path)")
        }
    }

    private func exit(_ fixture: Fixture, boundary: ExitBoundary, sequence: Int = 1,
                      operation: String = "develop") throws -> DevelopmentExitSnapshot {
        let executable = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("DevelopmentExitWorker")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        let child = Process(); child.executableURL = executable
        child.arguments = [fixture.directory.path, fixture.film.id.uuidString, boundary.rawValue, String(sequence), operation]
        try child.run(); child.waitUntilExit()
        XCTAssertEqual(child.terminationReason, .exit)
        XCTAssertEqual(child.terminationStatus, 81)
        let snapshot = try JSONDecoder().decode(DevelopmentExitSnapshot.self,
            from: Data(contentsOf: fixture.directory.appendingPathComponent("at-exit.json")))
        XCTAssertNotEqual(snapshot.process, ProcessInfo.processInfo.processIdentifier)
        return snapshot
    }

    private func assertPreserved(_ before: DevelopmentExitSnapshot, _ after: DevelopmentExitSnapshot,
                                 file: StaticString = #filePath, line: UInt = #line) {
        if let run = before.run {
            XCTAssertEqual(after.run?.assignments, run.assignments, file: file, line: line)
            XCTAssertEqual(after.run?.treatmentVersion, run.treatmentVersion, file: file, line: line)
            XCTAssertEqual(after.run?.printProcess, run.printProcess, file: file, line: line)
        }
        for (key, hash) in before.assets where key.hasPrefix("master-") || key.hasPrefix("clip-") {
            XCTAssertEqual(after.assets[key], hash, file: file, line: line)
        }
        XCTAssertEqual(after.film.captures.map(\.id), before.film.captures.map(\.id), file: file, line: line)
        XCTAssertEqual(after.film.consumedMovieSeconds, before.film.consumedMovieSeconds, file: file, line: line)
        XCTAssertEqual(after.film.movieOrientation, before.film.movieOrientation, file: file, line: line)
    }

    @MainActor private struct Fixture {
        let directory: URL
        let root: URL
        let repository: FilmRepository
        let film: Film
        let photo: Data
        let duration: Double
        var developedKey: String { film.camera.medium == .photo ? "master-1" : "clip-1" }

        init(camera: CameraID, label: String, count: Int = 1) async throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("DevelopmentProcessExit/\(camera)-\(label)-\(UUID())")
            root = directory.appendingPathComponent("App")
            let fixtures = directory.appendingPathComponent("Fixtures")
            var settings = RenderFixtureSettings.defaultExperimental
            settings.photoWidth = 160; settings.photoHeight = 120
            settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
            let generated = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
            photo = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
            duration = generated.movie.durationSeconds
            repository = try FilmRepository(rootURL: root)
            let camera = CameraCatalog.package(for: camera)
            film = try repository.createFilm(camera: camera, title: "Synthetic process exit", movieOrientation: camera.medium == .movie ? .portrait : nil, access: .subscription)
            for sequence in 1...count {
                let date = Date(timeIntervalSince1970: 1_790_880_000 + Double(sequence))
                if camera.medium == .photo { try repository.savePhotoCapture(filmID: film.id, sourceData: photo, savedAt: date) }
                else {
                    try repository.saveMovieClip(filmID: film.id, sourceData: Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov")),
                        durationSeconds: duration, orientation: .landscape, savedAt: date)
                }
            }
            if camera.revealRule != .instantPerExposure { try repository.completeEarly(filmID: film.id) }
            for sequence in 1...count {
                try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: sequence, export: false)
            }
            print("DEVELOPMENT_EXIT_PREPARED \(directory.path)")
        }

        func snapshot(_ name: String) async throws -> DevelopmentExitSnapshot {
            let value = try await DevelopmentExitSnapshot.read(root: root, filmID: film.id)
            try value.persist(to: directory.appendingPathComponent("\(name).json"))
            return value
        }
    }
}
