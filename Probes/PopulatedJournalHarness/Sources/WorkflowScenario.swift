import CryptoKit
import EntitlementCore
import FilmDomain
@testable import FilmPersistence
import Foundation
import Observation
import RenderCore
import RenderFixtures

private enum WorkflowError: Error { case invalidArguments, cannotReseedHistory, missingHistory, unexpectedTrialWrite, configuredBilling }

private struct FixtureTrialStore: DeviceTrialStoring {
    let record = DeviceTrialRecord()
    func read() throws -> DeviceTrialRecord? { record }
    func ensureDeviceRecord() throws -> DeviceTrialRecord { throw WorkflowError.unexpectedTrialWrite }
    func consume(filmID: UUID, captureID: String?, savedAt: Date) throws { throw WorkflowError.unexpectedTrialWrite }
}

@MainActor @Observable final class WorkflowScenario {
    let model: JournalModel
    let directory: URL
    private(set) var inspectionCount: Int
    private(set) var inspecting = false

    private struct Seed: Codable { let mode: String; let filmID: UUID }
    private struct Snapshot: Codable {
        let reason: String
        let utc: String
        let process: Int32
        let films: [FilmState]
        let privateFiles: [String]
    }
    private struct FilmState: Codable {
        let film: Film
        let development: DevelopmentRun?
        let captures: [CaptureState]
        let movieSHA256: String?
    }
    private struct CaptureState: Codable {
        let sequence: Int
        let originalDisposition: OriginalDisposition?
        let sourceSHA256: String?
        let masterSHA256: String?
        let clipSHA256: String?
        let printSHA256: String?
        let recipe: DarkroomRecipe?
    }

    private init(directory: URL) throws {
        self.directory = directory
        let evidence = directory.appendingPathComponent("Evidence")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        inspectionCount = try FileManager.default.contentsOfDirectory(atPath: evidence.path).filter { $0.hasSuffix(".json") }.count
        #if DEBUG
        // `-ImmerseDebugFreeSpace <bytes>` sets the free-space reading, as in the app's own Debug build.
        model = try JournalModel(root: directory.appendingPathComponent("App"), trialStore: FixtureTrialStore(),
                                 freeSpace: DebugFreeSpace(defaults: .standard))
        #else
        model = try JournalModel(root: directory.appendingPathComponent("App"), trialStore: FixtureTrialStore())
        #endif
        guard !model.billing.configured else { throw WorkflowError.configuredBilling }
    }

    static func prepare(arguments: [String]) async throws -> WorkflowScenario {
        let run: UUID
        if let index = arguments.firstIndex(of: "--workflow-run") {
            guard arguments.indices.contains(index + 1), let id = UUID(uuidString: arguments[index + 1]) else {
                throw WorkflowError.invalidArguments
            }
            run = id
        } else { run = UUID() }
        // `--scratch-history` seeds in the temporary directory instead, outside the histories `run-retained.sh` collects,
        // for the launches a test class makes before its tests.
        let histories = arguments.contains("--scratch-history") ? URL.temporaryDirectory.appendingPathComponent("ScratchHistories")
            : URL.documentsDirectory.appendingPathComponent("WorkflowHistories")
        let directory = histories.appendingPathComponent("\(run)")
        let seedURL = directory.appendingPathComponent("seed.json")
        let reopening = arguments.contains("--reopen")
        guard FileManager.default.fileExists(atPath: seedURL.path) == reopening else {
            throw reopening ? WorkflowError.missingHistory : WorkflowError.cannotReseedHistory
        }
        let scenario = try WorkflowScenario(directory: directory)
        await scenario.model.recoverAtLaunch()
        if reopening {
            _ = try JSONDecoder().decode(Seed.self, from: Data(contentsOf: seedURL))
        } else {
            let mode = arguments.contains("--movie") ? "movie" : arguments.contains("--instant-final") ? "instant-final"
                : arguments.contains("--instant-mixed") ? "instant-mixed"
                : arguments.contains("--instant") ? "instant" : arguments.contains("--empty") ? "empty"
                : arguments.contains("--developed-photo") ? "developed-photo"
                : arguments.contains("--medium-format") ? "medium-format" : "early-photo"
            let movie = mode == "movie", instant = mode.hasPrefix("instant")
            // `--super8` films the Movie on the Super 8 instead of the 16mm.
            let camera = movie ? (arguments.contains("--super8") ? CameraCatalog.super8HomeMovie : CameraCatalog.cinema16mm)
                : instant ? CameraCatalog.instant1970s
                : mode == "medium-format" ? CameraCatalog.mediumFormat6x6 : CameraCatalog.disposable1990s
            let model = scenario.model
            // `--black-and-white` loads the 6×6 or 16mm Film on the black-and-white Film Stock; otherwise a Camera with a
            // Film Stock gets Load Film's default, color.
            let filmStock = arguments.contains("--black-and-white") ? FilmStock.blackAndWhite : camera.defaultFilmStock
            // `--landscape-movie` locks the Movie landscape, as its clips are; otherwise it is portrait.
            let orientation: MovieOrientation = arguments.contains("--landscape-movie") ? .landscape : .portrait
            let film = try model.repository.createFilm(camera: camera, title: "Private synthetic Film",
                movieOrientation: movie ? orientation : nil, filmStock: filmStock, access: .subscription)
            if mode != "empty" {
                let fixtures = directory.appendingPathComponent("Fixtures")
                var settings = RenderFixtureSettings.defaultExperimental
                settings.photoWidth = 320; settings.photoHeight = 240
                settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
                let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
                // `--photo-source PATH` and `--movie-source PATH` capture a still or a silent movie already on disk instead
                // of the generated fixtures, so screenshots can show a natural scene. Both are harness-only evidence aids.
                let source = { (flag: String) -> URL? in
                    arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? URL(fileURLWithPath: arguments[$0 + 1]) : nil }
                }
                if movie {
                    let clip = source("--movie-source") ?? fixtures.appendingPathComponent("synthetic-developed-movie.mov")
                    let data = try Data(contentsOf: clip)
                    let seconds = source("--movie-source") == nil ? manifest.movie.durationSeconds
                        : try await VerifiedMedia.movie(at: clip).durationSeconds ?? 0
                    for _ in 0..<2 {
                        try model.repository.saveMovieClip(filmID: film.id, sourceData: data,
                            durationSeconds: seconds, orientation: .landscape)
                    }
                } else {
                    let data = try Data(contentsOf: source("--photo-source") ?? fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
                    if mode == "instant-final" {
                        for _ in 0..<9 { try model.repository.savePhotoCapture(filmID: film.id, sourceData: data) }
                        model.refresh()
                        try await model.develop(film.id)
                    } else {
                    // `--two-sealed`, with `--instant-mixed`, leaves two sealed Instant prints where there is otherwise one,
                    // so one Development reveals both.
                    let captures = mode == "instant-mixed" && arguments.contains("--two-sealed") ? 3 : 2
                    for index in 1...captures {
                        try model.repository.savePhotoCapture(filmID: film.id, sourceData: data)
                        if mode == "instant-mixed", index == 1 { model.refresh(); try await model.develop(film.id) }
                    }
                    }
                }
                let developsEarly = mode == "developed-photo" || mode == "medium-format"
                if movie || developsEarly { try model.repository.completeEarly(filmID: film.id) }
                if movie || developsEarly || mode == "instant" {
                    model.refresh(); try await model.develop(film.id)
                }
            }
            try persist(Seed(mode: mode, filmID: film.id), to: seedURL)
            // `--reveal-at-camera` saves and develops an Instant print once the shooting screen is open, as the app does
            // when a save lands there. `--instant-final` leaves its tenth exposure for this moment to test the one pack-end
            // Originals question.
            // The simulator has no camera, so nothing is captured.
            if arguments.contains("--reveal-at-camera") {
                Task {
                    while !model.capture.presented { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .seconds(1))
                    if mode == "instant-final",
                       let source = try? Data(contentsOf: directory.appendingPathComponent("Fixtures/synthetic-developed-photo.jpg")) {
                        _ = try? model.repository.savePhotoCapture(filmID: film.id, sourceData: source)
                        model.refresh()
                    }
                    model.developSavedPrint(film.id) { _ in }
                }
            }
        }
        scenario.model.refresh()
        try await scenario.inspect(reason: reopening ? "reopen" : "seeded")
        // `--recipe-outside-limits` leaves print 1 a stored print exposure of 3.5 stops, which only a build with wider
        // limits or a damaged store can: the app's own writers refuse it, so it goes to the store beside them. It is
        // written after the inspection above, which prints every photo, so such a history is never inspected or reopened.
        if !reopening, arguments.contains("--recipe-outside-limits"), let film = scenario.model.films.first {
            try scenario.model.repository.database.setValue(filmID: film.id, key: "recipe-1",
                data: Data(#"{"printExposureStops":3.5,"dodgeBurnMasks":[]}"#.utf8))
        }
        // `--recipe-unreadable` leaves print 1 a stored recipe no build can read, as a damaged store might, so the
        // Darkroom fails to load it; it goes to the store the same way, after the inspection.
        if !reopening, arguments.contains("--recipe-unreadable"), let film = scenario.model.films.first {
            try scenario.model.repository.database.setValue(filmID: film.id, key: "recipe-1", data: Data("unreadable".utf8))
        }
        // A pre-change Film can still have a Dodge/Burn recipe. Seed one after the initial inspection so the harness UI
        // opens that exact stored recipe, while the retained-history check can compare it with the reset result.
        if !reopening, arguments.contains("--recipe-with-strokes"), let film = scenario.model.films.first {
            let stroke = LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 1)
            let recipe = DarkroomRecipe(dodgeBurnMasks: [stroke])
            try scenario.model.repository.database.setValue(filmID: film.id, key: "recipe-1",
                data: JSONEncoder().encode(recipe))
        }
        return scenario
    }

    func inspect(reason: String) async throws {
        guard !inspecting else { return }
        inspecting = true
        defer { inspecting = false }
        var films: [FilmState] = []
        for film in try model.repository.allFilms() {
            var captures: [CaptureState] = []
            for capture in film.captures {
                let sequence = capture.sequenceNumber
                var printHash: String?, recipe: DarkroomRecipe?
                if film.camera.medium == .photo, capture.revealState == .revealed {
                    recipe = try model.repository.darkroomRecipe(filmID: film.id, sequence: sequence)
                    printHash = Self.hash(try await model.processor.photo(filmID: film.id, sequence: sequence))
                }
                captures.append(CaptureState(sequence: sequence,
                    originalDisposition: try model.repository.originalDisposition(filmID: film.id, sequenceNumber: sequence),
                    sourceSHA256: try await assetHash(film: film, sequence: sequence, kind: .source),
                    masterSHA256: try await assetHash(film: film, sequence: sequence, kind: .master),
                    clipSHA256: try await assetHash(film: film, sequence: sequence, kind: .clip),
                    printSHA256: printHash, recipe: recipe))
            }
            films.append(FilmState(film: film, development: try model.repository.developmentRun(filmID: film.id),
                captures: captures, movieSHA256: try await assetHash(film: film, sequence: 0, kind: .movie)))
        }
        let next = inspectionCount + 1
        try Self.persist(Snapshot(reason: reason, utc: ISO8601DateFormatter().string(from: Date()),
            process: ProcessInfo.processInfo.processIdentifier, films: films, privateFiles: privateFiles()),
            to: directory.appendingPathComponent(String(format: "Evidence/%03d.json", next)))
        inspectionCount = next
    }

    private func privateFiles() throws -> [String] {
        let root = directory.appendingPathComponent("App")
        let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
        var paths: [String] = []
        for case let url as URL in entries where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            paths.append(String(url.path.dropFirst(root.path.count + 1)))
        }
        return paths.sorted()
    }

    private func assetHash(film: Film, sequence: Int, kind: StoredAsset.Kind) async throws -> String? {
        guard let asset = try model.repository.mediaAsset(filmID: film.id, sequenceNumber: sequence, kind: kind) else { return nil }
        let verified = film.camera.medium == .photo ? try VerifiedMedia.photo(at: asset.url) : try await VerifiedMedia.movie(at: asset.url)
        guard verified.sha256 == asset.record.sha256 else { throw PersistenceError.mediaChangedDuringVerification }
        return verified.sha256
    }

    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func persist<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }
}
