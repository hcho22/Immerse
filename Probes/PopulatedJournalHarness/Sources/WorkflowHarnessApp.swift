import FilmDomain
import RenderFixtures
import SwiftUI

@main
struct WorkflowHarnessApp: App {
    @State private var scenario: WorkflowScenario?
    @State private var failure: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let scenario {
                    journal(scenario)
                }
                else if let failure { Text(failure).accessibilityIdentifier("fixture-failed") }
                else { ProgressView("Preparing private fixtures").task { await prepare() } }
            }.tint(.accentColor)
        }
    }

    private var hidesInspectionBar: Bool {
        ProcessInfo.processInfo.arguments.contains("--hide-inspection-bar")
    }

    @ViewBuilder private func journal(_ scenario: WorkflowScenario) -> some View {
        let content = JournalView().environment(scenario.model)
            .overlay(alignment: .top) {
                if let failure { Text(failure).accessibilityIdentifier("fixture-failed") }
            }
        if hidesInspectionBar {
            content
        } else {
            content.safeAreaInset(edge: .bottom) {
                HStack {
                    Button("Inspect synthetic state", systemImage: "doc.text.magnifyingglass") {
                        Task {
                            do { try await scenario.inspect(reason: "explicit") }
                            catch { failure = error.localizedDescription }
                        }
                    }.accessibilityIdentifier("inspect-state")
                        .disabled(scenario.inspecting)
                    Text(String(scenario.inspectionCount)).monospacedDigit()
                        .accessibilityIdentifier("inspection-count")
                }.font(.caption).padding(8).background(.bar)
            }
        }
    }

    @MainActor private func prepare() async {
        do {
            scenario = try await WorkflowScenario.prepare(arguments: ProcessInfo.processInfo.arguments)
        } catch { failure = error.localizedDescription }
    }
}
