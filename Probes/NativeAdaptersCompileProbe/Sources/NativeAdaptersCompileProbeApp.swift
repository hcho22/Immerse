import NativeAdapters
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

    var body: some Scene {
        WindowGroup {
            Text(plan.recordsAudio ? "Unexpected audio" : "Silent native adapters")
        }
    }
}
