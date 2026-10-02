import Darwin
import FilmDomain
import FilmPersistence
import FilmRuntime
import SwiftUI

@MainActor @Observable final class DevelopmentExitModel {
    var status = "opening"
    var summary = "No inspection"
    var busy = false
    private var scenario: ExportScenario?
    private var camera: CameraID = .disposable1990s
    private var boundary: ExitBoundary = .afterRendering
    private var discarding = false

    init() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            guard let index = args.firstIndex(of: key), args.indices.contains(index + 1) else { return nil }
            return args[index + 1]
        }
        guard let id = value("--development-run").flatMap(UUID.init(uuidString:)),
              let camera = value("--camera").flatMap(CameraID.init(rawValue:)),
              let boundary = value("--boundary").flatMap(ExitBoundary.init(rawValue:)) else {
            status = "invalid-arguments"; return
        }
        self.camera = camera; self.boundary = boundary
        discarding = args.contains("--discard-first")
        do {
            scenario = try ExportScenario(id: id, camera: camera, count: discarding ? 2 : 1,
                label: "development-exit-\(boundary.rawValue)-discard-\(discarding)")
            status = "opened"
        } catch { status = "open-error: \(error)" }
    }

    func perform(_ command: String) {
        guard !busy, let scenario else { return }
        busy = true; status = "\(command)-running"
        Task {
            defer { busy = false }
            do {
                let repository = try FilmRepository(rootURL: scenario.root)
                if command == "prepare" {
                    try await scenario.prepare(develop: camera == .instant1970s || discarding)
                    guard let film = try repository.allFilms().first else { throw ExportHarnessError.missingPreparation }
                    if camera == .instant1970s {
                        let bytes = try Data(contentsOf: scenario.directory.appendingPathComponent("Fixtures/synthetic-developed-photo.jpg"))
                        try repository.savePhotoCapture(filmID: film.id, sourceData: bytes)
                    }
                    for capture in try repository.film(id: film.id).captures {
                        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: capture.sequenceNumber, export: false)
                    }
                    if discarding { try await FilmProcessor(root: scenario.root).cleanupSources(filmID: film.id) }
                }
                guard let film = try repository.allFilms().first else { throw ExportHarnessError.missingPreparation }
                switch command {
                case "prepare": break
                case "start":
                    let root = scenario.root, directory = scenario.directory, id = film.id
                    let target = boundary.stage(camera: camera, sequence: camera == .instant1970s ? 2 : 1)
                    let processor = try FilmProcessor(root: root, developmentObserver: { observed, stage in
                        guard observed == id, stage == target else { return }
                        let snapshot = try await DevelopmentExitSnapshot.read(root: root, filmID: id)
                        try snapshot.persist(to: directory.appendingPathComponent("at-exit.json"))
                        _exit(81)
                    })
                    if discarding { try await processor.discard(filmID: id, sequence: 1) }
                    else { try await processor.develop(filmID: id) }
                    throw ExportHarnessError.invalidControl
                case "recover": try repository.recover()
                case "resume", "repeat": try await FilmProcessor(root: scenario.root).develop(filmID: film.id)
                default: throw ExportHarnessError.invalidControl
                }
                let state = try await DevelopmentExitSnapshot.read(root: scenario.root, filmID: film.id)
                try state.persist(to: scenario.directory.appendingPathComponent("\(command).json"))
                summary = "saved=\(state.film.savedCaptureCount);revealed=\(state.film.captures.filter { $0.revealState == .revealed && !$0.isDiscarded }.count);sources=\(state.assets.keys.filter { $0.hasPrefix("source-") }.count)"
                status = "\(command)-ok"
            } catch {
                scenario.evidence.record("development-exit-error", ["command": command, "error": String(describing: error)])
                status = "\(command)-error: \(error)"
            }
        }
    }
}

struct DevelopmentExitView: View {
    @State private var model = DevelopmentExitModel()
    var body: some View {
        NavigationStack {
            Form {
                Text(model.status).accessibilityIdentifier("development-status")
                Text(model.summary).accessibilityIdentifier("development-summary")
                Button("Prepare", systemImage: "doc.badge.plus") { model.perform("prepare") }.accessibilityIdentifier("development-prepare")
                Button("Develop to exit", systemImage: "stop.circle") { model.perform("start") }.accessibilityIdentifier("development-start")
                Button("Recover", systemImage: "arrow.clockwise") { model.perform("recover") }.accessibilityIdentifier("development-recover")
                Button("Resume", systemImage: "play") { model.perform("resume") }.accessibilityIdentifier("development-resume")
                Button("Repeat", systemImage: "repeat") { model.perform("repeat") }.accessibilityIdentifier("development-repeat")
            }.disabled(model.busy).navigationTitle("Development Exit")
        }
    }
}
