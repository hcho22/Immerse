import FilmRuntime
import NativeAdapters
import RenderCore
import SwiftUI

@main
struct NativeAdaptersCompileProbeApp: App {
    private let plan = CaptureSessionPlan(
        request: CaptureSessionRequest(
            preferredPosition: .front,
            mediaKind: .movie,
            lockedMovieOrientation: .landscape
        ),
        capabilities: CaptureCapabilities(
            availablePositions: [.front, .rear],
            supportsLensSwitchDuringSession: true
        )
    )
    private let committer = String(describing: TrialCaptureReceiver.self)

    var body: some Scene {
        WindowGroup {
            Text(plan.mediaKind == .movie ? "Silent native adapters" : "Unexpected media")
                .accessibilityLabel(committer)
        }
    }
}
