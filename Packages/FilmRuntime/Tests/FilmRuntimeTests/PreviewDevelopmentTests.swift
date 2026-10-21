#if DEBUG
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import RenderFixtures
import XCTest

/// The Debug-only preview of a saved capture (`PreviewDevelopment`): it is what the roll's Development makes of that
/// capture, it leaves the roll sealed and its store unchanged, and the roll then develops exactly as a copy of it that
/// was never previewed.
final class PreviewDevelopmentTests: XCTestCase {
    private var root: URL!
    private var fixtures: URL!
    private var previews: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewDevelopmentTests-\(UUID())")
        fixtures = root.deletingLastPathComponent().appendingPathComponent("\(root.lastPathComponent)-Fixtures")
        previews = root.deletingLastPathComponent().appendingPathComponent("\(root.lastPathComponent)-Previews")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.2
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
    }

    override func tearDown() {
        for url in [root, fixtures, previews] { try? FileManager.default.removeItem(at: url!) }
        try? FileManager.default.removeItem(at: copyRoot)
    }

    private var photo: Data { get throws { try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg")) } }
    private var clip: URL { fixtures.appendingPathComponent("synthetic-developed-movie.mov") }
    private var copyRoot: URL { root.deletingLastPathComponent().appendingPathComponent("\(root.lastPathComponent)-Unpreviewed") }

    func testEachCamerasPreviewIsItsDevelopmentAndTheRollDevelopsAsIfNeverPreviewed() async throws {
        let repository = try FilmRepository(rootURL: root)
        let readsTables = NativePhotoRenderer.readsFilmTables
        var films: [Film] = [
            try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Disposable"),
            try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "6×6 mono", filmStock: .blackAndWhite),
            try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "16mm mono", movieOrientation: .landscape,
                                      filmStock: .blackAndWhite),
            try repository.createFilm(camera: CameraCatalog.super8HomeMovie, title: "Super 8", movieOrientation: .landscape),
        ]
        // The color stocks of the 6×6 and the 16mm develop only through the table reader.
        if readsTables {
            films.append(try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "6×6 color", filmStock: .color))
            films.append(try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "16mm color",
                                                   movieOrientation: .landscape, filmStock: .color))
        }
        let seconds = try await VerifiedMedia.movie(at: clip).durationSeconds ?? 0
        for film in films {
            for _ in 0..<2 {
                if film.camera.medium == .photo { try repository.savePhotoCapture(filmID: film.id, sourceData: photo) }
                else { _ = try repository.saveMovieClip(filmID: film.id, sourceData: Data(contentsOf: clip),
                                                        durationSeconds: seconds, orientation: .landscape) }
            }
        }
        // A copy of the whole store, taken before any preview, develops as the same rolls never previewed.
        try FileManager.default.copyItem(at: root, to: copyRoot)
        let before = try snapshot(repository, films)

        var previewed: [UUID: [Int: URL]] = [:]
        for film in films {
            for sequence in [1, 2] {
                let url = try await PreviewDevelopment.render(root: root, filmID: film.id, sequenceNumber: sequence,
                                                              directory: previews)
                XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, previews.standardizedFileURL)
                XCTAssertEqual(url.pathExtension, film.camera.medium == .photo ? "jpg" : "mov", film.title)
                previewed[film.id, default: [:]][sequence] = url
            }
        }
        XCTAssertEqual(try snapshot(repository, films), before, "Previews leave every roll and its store as they were")
        XCTAssertEqual(try previews.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertEqual(try storeFiles(root).filter { $0.contains("Preview") }, [], "No preview is written into the store")

        let unpreviewed = try FilmRepository(rootURL: copyRoot)
        for film in films {
            try repository.completeEarly(filmID: film.id)
            try unpreviewed.completeEarly(filmID: film.id)
            try await FilmProcessor(root: root).develop(filmID: film.id)
            try await FilmProcessor(root: copyRoot).develop(filmID: film.id)
            for sequence in [1, 2] {
                let preview = try XCTUnwrap(previewed[film.id]?[sequence])
                let label = "\(film.title) capture \(sequence)"
                if film.camera.medium == .photo {
                    let master = try Data(contentsOf: repository.revealedAsset(filmID: film.id, sequenceNumber: sequence, kind: .master).url)
                    XCTAssertEqual(try Data(contentsOf: preview), master, "\(label): the preview is the developed master")
                    XCTAssertEqual(try Data(contentsOf: unpreviewed.revealedAsset(filmID: film.id, sequenceNumber: sequence,
                                                                                    kind: .master).url), master,
                                   "\(label): develops as the roll never previewed")
                } else {
                    let developed = try repository.revealedAsset(filmID: film.id, sequenceNumber: sequence, kind: .clip).url
                    let expected = try await frameDigests(developed)
                    let previewFrames = try await frameDigests(preview)
                    XCTAssertEqual(previewFrames, expected, "\(label): the preview is the Developed Clip")
                    let unpreviewedFrames = try await frameDigests(unpreviewed.revealedAsset(
                        filmID: film.id, sequenceNumber: sequence, kind: .clip).url)
                    XCTAssertEqual(unpreviewedFrames, expected, "\(label): develops as the roll never previewed")
                }
            }
            if film.camera.medium == .movie {
                let movie = try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie).url
                let unpreviewedMovie = try unpreviewed.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie).url
                let movieFrames = try await frameDigests(movie)
                let unpreviewedMovieFrames = try await frameDigests(unpreviewedMovie)
                XCTAssertEqual(movieFrames, unpreviewedMovieFrames, "\(film.title): the Developed Movie is the never-previewed roll's")
            }
        }
    }

    func testAnInstantPrintAndACaptureThatIsNotSavedHaveNoPreview() async throws {
        let repository = try FilmRepository(rootURL: root)
        let pack = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Pack")
        try repository.savePhotoCapture(filmID: pack.id, sourceData: photo)
        do {
            _ = try await PreviewDevelopment.render(root: root, filmID: pack.id, sequenceNumber: 1, directory: previews)
            XCTFail("An Instant print develops by itself")
        } catch FilmDomainError.wrongCameraMedium { }
        let roll = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Roll")
        do {
            _ = try await PreviewDevelopment.render(root: root, filmID: roll.id, sequenceNumber: 1, directory: previews)
            XCTFail("Nothing is saved yet")
        } catch PersistenceError.captureNotFound { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: previews.path), "A refused preview writes nothing")
        XCTAssertEqual(try repository.film(id: pack.id).captures.map(\.revealState), [.sealed])
    }

    /// What a preview must not change: each Film as stored, its Development record (none) and every file of the store
    /// apart from the database, which opening a repository may touch, with its bytes.
    private func snapshot(_ repository: FilmRepository, _ films: [Film]) throws -> [String] {
        var lines: [String] = []
        for film in films {
            let stored = try repository.film(id: film.id)
            lines.append("\(film.title): \(stored.captures.map { "\($0.sequenceNumber) \($0.revealState)" }) "
                + "saved \(stored.savedCaptureCount) state \(stored.completionState) \(stored.developmentState) "
                + "run \(try repository.developmentRun(filmID: film.id) == nil ? "none" : "present")")
        }
        for path in try storeFiles(root) where !path.hasPrefix("film-store.sqlite") {
            lines.append("\(path) \(sha256Hex(try Data(contentsOf: root.appendingPathComponent(path))))")
        }
        return lines
    }

    private func storeFiles(_ directory: URL) throws -> [String] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
        var paths: [String] = []
        for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            paths.append(String(url.standardizedFileURL.path.dropFirst(directory.standardizedFileURL.path.count + 1)))
        }
        return paths.sorted()
    }
}
#endif
