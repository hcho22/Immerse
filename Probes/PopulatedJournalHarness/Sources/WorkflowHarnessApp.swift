import FilmDomain
import RenderFixtures
import AVKit
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
            }.tint(Color("AccentColor")) // Matches ImmerseApp's root tint.
        }
    }

    private var hidesInspectionBar: Bool {
        ProcessInfo.processInfo.arguments.contains("--hide-inspection-bar")
    }

    private var observesMoviePlayer: Bool {
        ProcessInfo.processInfo.arguments.contains("--movie-player-observer")
    }

    @ViewBuilder private func journal(_ scenario: WorkflowScenario) -> some View {
        let content = JournalView().environment(scenario.model)
            .overlay(alignment: .top) {
                if let failure { Text(failure).accessibilityIdentifier("fixture-failed") }
            }
            .overlay(alignment: .bottom) {
                if observesMoviePlayer { MoviePlayerObservationView() }
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

@MainActor
@Observable
private final class MoviePlayerObservationModel {
    var oldState = "waiting-initial"
    var successorState = "waiting-initial"
    var identity = "initial-player none initial-item none current-player none current-item none old-current none"

    private weak var initialPlayer: AVPlayer?
    private weak var initialItem: AVPlayerItem?
    private var initialPlayerID: String?
    private var initialItemID: String?

    func run() async {
        while !Task.isCancelled {
            observe()
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func observe() {
        let visible = Self.visiblePlayer()
        if initialPlayerID == nil, let player = visible?.player, let item = player.currentItem {
            initialPlayer = player
            initialItem = item
            initialPlayerID = Self.identity(of: player)
            initialItemID = Self.identity(of: item)
        }

        guard let initialPlayerID, let initialItemID else {
            oldState = "waiting-initial"
            successorState = "waiting-initial"
            identity = "initial-player none initial-item none current-player none current-item none old-current none"
            return
        }

        let currentPlayer = visible?.player
        let currentItem = currentPlayer?.currentItem
        let currentPlayerID = Self.identity(of: currentPlayer)
        let currentItemID = Self.identity(of: currentItem)
        let oldCurrentItemID = Self.identity(of: initialPlayer?.currentItem)

        oldState = Self.state(initialPlayer: initialPlayer, initialItem: initialItem)
        if currentItem == nil {
            successorState = "no-visible-player"
        } else if currentPlayerID == initialPlayerID, currentItemID == initialItemID {
            successorState = "initial-visible"
        } else {
            successorState = "successor-visible"
        }
        identity = "initial-player \(initialPlayerID) initial-item \(initialItemID) current-player \(currentPlayerID) current-item \(currentItemID) old-current \(oldCurrentItemID)"
    }

    private static func state(initialPlayer: AVPlayer?, initialItem: AVPlayerItem?) -> String {
        guard let player = initialPlayer else {
            return initialItem == nil ? "released" : "player-released"
        }
        guard let currentItem = player.currentItem else { return "detached" }
        guard let initialItem else { return "item-released" }
        return currentItem === initialItem ? "attached" : "replaced"
    }

    private static func visiblePlayer() -> AVPlayerViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .flatMap { playerControllers(in: $0.rootViewController) }
            .first { $0.player != nil }
    }

    private static func playerControllers(in root: UIViewController?) -> [AVPlayerViewController] {
        guard let root else { return [] }
        var result: [AVPlayerViewController] = []
        if let controller = root as? AVPlayerViewController { result.append(controller) }
        result += root.children.flatMap { playerControllers(in: $0) }
        result += playerControllers(in: root.presentedViewController)
        return result
    }

    private static func identity(of object: AnyObject?) -> String {
        guard let object else { return "none" }
        return String(describing: ObjectIdentifier(object))
    }
}

private struct MoviePlayerObservationView: View {
    @State private var model = MoviePlayerObservationModel()

    var body: some View {
        VStack(spacing: 0) {
            Text(model.oldState).accessibilityIdentifier("movie-observer-old-state")
            Text(model.successorState).accessibilityIdentifier("movie-observer-successor-state")
            Text(model.identity).accessibilityIdentifier("movie-observer-identity")
        }
        .font(.caption2.monospaced())
        .frame(width: 1, height: 1)
        .clipped()
        .opacity(0.01)
        .allowsHitTesting(false)
        .task { await model.run() }
    }
}
