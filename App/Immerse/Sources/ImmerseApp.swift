import SwiftUI

@main
struct ImmerseApp: App {
    @State private var model: JournalModel?
    @State private var failure: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let model {
                    JournalView().environment(model)
                } else if let failure {
                    ContentUnavailableView {
                        Label("Journal unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(failure)
                    } actions: {
                        Button("Try Again", systemImage: "arrow.clockwise") { openJournal() }
                    }
                } else {
                    ProgressView().task { openJournal() }
                }
            }
            .tint(.accentColor)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    model?.capture.suspend()
                    Task { await model?.processor.suspendProcessing() }
                }
                else { model?.refresh() }
            }
        }
    }

    private func openJournal() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("FilmJournal", isDirectory: true)
            model = try JournalModel(root: root)
            failure = nil
        } catch {
            failure = "Your Films have not been removed. Free space in iPhone Settings and try again. \(error.localizedDescription)"
        }
    }
}
