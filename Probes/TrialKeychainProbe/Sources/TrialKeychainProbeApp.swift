import SwiftUI

@main
struct TrialKeychainProbeApp: App {
    var body: some Scene {
        WindowGroup {
            KeychainProbeView(store: KeychainProbeStore())
        }
    }
}
