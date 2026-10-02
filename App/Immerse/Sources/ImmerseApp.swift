import SwiftUI

@main
struct ImmerseApp: App {
    @State private var launcher = JournalLauncher()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let model = launcher.model {
                    JournalView().environment(model)
                } else if let failure = launcher.failure {
                    ContentUnavailableView {
                        Label("Journal unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(failure)
                    } actions: {
                        Button("Try Again", systemImage: "arrow.clockwise") { Task { await launcher.open() } }
                            .disabled(launcher.opening)
                        if launcher.opening { ProgressView() }
                    }
                } else {
                    ProgressView().task { await launcher.open() }
                }
            }
            // A concrete color: inside iOS 26 bottom toolbars `Color.accentColor` resolves to system blue.
            .tint(Color("AccentColor"))
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    launcher.model?.refresh()
                case .background:
                    launcher.model?.capture.suspend()
                    Task { await launcher.model?.processor.suspendProcessing() }
                default:
                    // Control Center, a call or a permission prompt only pauses the camera.
                    launcher.model?.capture.suspend()
                }
            }
        }
    }
}

/// Opens the Journal at most once at a time, so its single Trial owner is never duplicated.
@MainActor @Observable
final class JournalLauncher {
    private(set) var model: JournalModel?
    private(set) var failure: String?
    private(set) var opening = false
    private let makeModel: @MainActor () throws -> JournalModel

    init(makeModel: @escaping @MainActor () throws -> JournalModel = JournalLauncher.makeJournal) {
        self.makeModel = makeModel
    }

    func open() async {
        guard !opening, model == nil else { return }
        opening = true
        defer { opening = false }
        do {
            let opened = try makeModel()
            await opened.recoverAtLaunch()
            model = opened
            failure = nil
        } catch {
            failure = ["Your Films have not been removed. Free space in iPhone Settings and try again.",
                       FailureCopy.systemDetail(for: error)].compactMap { $0 }.joined(separator: " ")
        }
    }

    static func makeJournal() throws -> JournalModel {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("FilmJournal", isDirectory: true)
        return try JournalModel(root: root)
    }
}
