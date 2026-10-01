import FilmDomain
import SwiftUI

@MainActor @Observable final class ExportHarnessModel {
    var scenario: ExportScenario?
    var runID = UUID().uuidString
    var camera: CameraID = .disposable1990s
    var boundary: ExportBoundary = .beforeReply
    var phase = "idle"
    var status = "No scenario"
    var inventory = "No inventory"

    init() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--export-run") else { return }
        func value(_ key: String) -> String? {
            guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
            return args[index + 1]
        }
        guard let id = value("--export-run"), UUID(uuidString: id) != nil,
              let camera = value("--camera").flatMap(CameraID.init(rawValue:)),
              let boundary = value("--boundary").flatMap(ExportBoundary.init(rawValue:)), boundary != .none else {
            status = "Invalid launch configuration"; return
        }
        runID = id; self.camera = camera; self.boundary = boundary
        open()
    }
    func open() {
        guard scenario == nil, let id = UUID(uuidString: runID) else { status = "Invalid scenario"; return }
        do {
            scenario = try ExportScenario(id: id, camera: camera,
                count: CameraCatalog.package(for: camera).medium == .movie ? 2 : 1, label: "process-\(boundary.rawValue)")
            status = "opened"
        } catch { status = "open-error: \(error)" }
    }
    func perform(_ name: String, _ action: @escaping @Sendable (ExportScenario) async throws -> Void) {
        guard let scenario else { return }
        status = "\(name)-running"
        Task {
            do {
                try await action(scenario)
                if let snapshot = try? await scenario.inventory(name) { inventory = snapshot.summary }
                status = "\(name)-ok"
            } catch {
                scenario.evidence.record("command-error", ["command": name, "error": String(describing: error)])
                status = "\(name)-error: \(error)"
            }
        }
    }
}

@main struct ExportPrivacyApp: App {
    @State private var model = ExportHarnessModel()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Form {
                    if model.scenario == nil {
                        TextField("Run UUID", text: $model.runID).textInputAutocapitalization(.never)
                        Picker("Camera", selection: $model.camera) {
                            ForEach(CameraCatalog.all) { Text($0.displayName).tag($0.id) }
                        }
                        Picker("Writer boundary", selection: $model.boundary) {
                            Text("Before copy").tag(ExportBoundary.beforeCopy)
                            Text("Before reply").tag(ExportBoundary.beforeReply)
                        }
                        Button("Open scenario", systemImage: "folder") { model.open() }
                    }
                    Section {
                        Text("Injected private writer")
                        Text(model.phase).accessibilityIdentifier("phase")
                        Text(model.status).accessibilityIdentifier("status")
                        Text(model.inventory).font(.caption).accessibilityIdentifier("inventory")
                    }
                    if model.scenario != nil {
                        Section {
                            action("Prepare", "prepare", "doc.badge.plus") { try await $0.prepare() }
                            Button("Start export", systemImage: "square.and.arrow.up") {
                                let boundary = model.boundary
                                model.perform("start") { scenario in
                                    let writer = try await scenario.makeWriter(.init(boundary: boundary))
                                    try await scenario.export(writer: writer)
                                }
                            }.accessibilityIdentifier("start")
                            action("Inspect", "inspect", "list.bullet.rectangle") { _ = try await $0.inventory("inspect-explicit") }
                            action("End process", "terminate", "stop.circle") { try await $0.terminateAtWriterBoundary() }
                            action("Recover", "recover", "arrow.clockwise") { try await $0.recover() }
                            action("Retry export", "retry", "square.and.arrow.up") { scenario in
                                let writer = try await scenario.makeWriter()
                                try await scenario.export(writer: writer)
                            }
                        }
                    }
                }
                .navigationTitle("Export Scenarios")
                .task {
                    while !Task.isCancelled {
                        if let scenario = model.scenario { model.phase = await scenario.phase() }
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
            }
        }
    }
    private func action(_ title: String, _ id: String, _ image: String,
                        _ work: @escaping @Sendable (ExportScenario) async throws -> Void) -> some View {
        Button(title, systemImage: image) { model.perform(id, work) }.accessibilityIdentifier(id)
    }
}
