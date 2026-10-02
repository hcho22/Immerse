import FilmDomain
import SwiftUI

@MainActor @Observable final class ScenarioModel {
    var session: ReceiptScenario?
    var status = "No scenario open"
    var phase = "idle"
    var summary = "No inventory"
    var runID = UUID().uuidString
    var camera: CameraID = .disposable1990s
    var backend: ReceiptBackend = .security
    var fault: ReceiptFault = .none
    var boundary = "prepared"

    init() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let id = value("--receipt-run") {
            runID = id
            camera = CameraID(rawValue: value("--camera") ?? "") ?? .disposable1990s
            backend = ReceiptBackend(rawValue: value("--backend") ?? "") ?? .security
            fault = ReceiptFault(rawValue: value("--fault") ?? "") ?? .none
            boundary = value("--boundary") ?? "prepared"
            open()
        }
    }

    func open() {
        guard session == nil, let id = UUID(uuidString: runID) else { status = "Invalid or already open scenario"; return }
        do {
            session = try ReceiptScenario(configuration: .init(runID: id, cameraID: camera, backend: backend, fault: fault, pauseAt: boundary))
            status = "opened"
        } catch { status = "open-error: \(error)" }
    }

    func perform(_ name: String, _ action: @escaping @Sendable (ReceiptScenario) async throws -> Void) {
        guard let session else { return }
        status = "\(name)-running"
        Task {
            do {
                try await action(session)
                if let inventory = try? await session.inventory() { summary = inventory.summary }
                status = "\(name)-ok"
            } catch {
                session.evidence.record("command-error", ["command": name, "error": String(describing: error)])
                if let inventory = try? await session.inventory() { summary = inventory.summary }
                status = "\(name)-error: \(error)"
            }
        }
    }
}

@main struct ReceiptScenarioApp: App {
    @State private var model = ScenarioModel()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Form {
                    if model.session == nil {
                        TextField("Run UUID", text: $model.runID).textInputAutocapitalization(.never)
                        Picker("Camera", selection: $model.camera) {
                            ForEach(CameraCatalog.all) { Text($0.displayName).tag($0.id) }
                        }
                        Picker("Receipt backend", selection: $model.backend) {
                            ForEach(ReceiptBackend.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Injected fault", selection: $model.fault) {
                            ForEach(ReceiptFault.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Boundary", selection: $model.boundary) {
                            ForEach(["none", "prepared", "receiptResolved", "projected"], id: \.self) { Text($0).tag($0) }
                        }
                        Button("Open scenario", systemImage: "folder") { model.open() }
                    } else {
                        Section {
                            Text(model.backend.rawValue).accessibilityIdentifier("backend")
                            Text(model.phase).accessibilityIdentifier("phase")
                            Text(model.status).accessibilityIdentifier("status")
                            Text(model.summary).font(.caption).accessibilityIdentifier("inventory")
                        }
                        Section {
                            action("Prepare", "prepare", "doc.badge.plus") { try await $0.prepare() }
                            action("Commit", "commit", "tray.and.arrow.down") { try await $0.commit() }
                            action("Inspect", "inspect", "list.bullet.rectangle") { _ = try await $0.inventory() }
                            action("Resume boundary", "release", "play") { try await $0.release() }
                            action("End process", "terminate", "stop.circle") { try await $0.terminateAtBoundary() }
                            action("Recover", "recover", "arrow.clockwise") { try await $0.recover() }
                        }
                        Section {
                            action("Resolve injected fault", "resolve", "checkmark.circle") { try await $0.resolveInjectedFault() }
                            action("Corrupt pending fixture", "corrupt", "exclamationmark.triangle") { try await $0.corruptPending() }
                            action("Delete synthetic Film", "delete", "trash") { try await $0.deleteFilm() }
                            action("Repeat saved callback", "callback", "arrow.uturn.backward") { try await $0.staleCallback() }
                            action("Attempt second load", "second", "camera") { try await $0.attemptSecondLoad() }
                        }
                    }
                }
                .navigationTitle("Receipt Scenarios")
                .task {
                    while !Task.isCancelled {
                        if let session = model.session { model.phase = await session.phase() }
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
            }
        }
    }
    private func action(_ title: String, _ id: String, _ symbol: String,
                        _ work: @escaping @Sendable (ReceiptScenario) async throws -> Void) -> some View {
        Button(title, systemImage: symbol) { model.perform(id, work) }.accessibilityIdentifier(id)
    }
}
