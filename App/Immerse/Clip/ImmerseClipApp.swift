import ImmerseServer
import SwiftUI

/// Immerse's mini-app (v2 PRD V2-FR-19): the App Clip a Group Film's link or QR code opens on an iPhone with nothing
/// installed. It holds what a guest needs and no more: the Join Confirmation, the shooting screen of the event's Camera,
/// Development of their pictures, the upload queue, and the album after the reveal with the invitation to install the
/// full app. It is the full app's own Group Film code (`GroupFilms`, `JoinConfirmationView`, `GroupFilmEventView`,
/// `CaptureView`), built into a second target, so everything it does the full app does too (App Store guideline
/// 2.5.16). It has no sign-in, no hosting, no purchases, no alert and no Photos access in it.
@main
struct ImmerseClipApp: App {
    @UIApplicationDelegateAdaptor(ImmerseAppDelegate.self) private var appDelegate
    @State private var miniApp = MiniApp.make()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MiniAppRoot(miniApp: miniApp)
                .orbitRoot()
                .environment(\.groupFilms, miniApp.groupFilms)
                // The link or QR code that opened the mini-app, and any opened while it runs (Apple: "Responding to
                // invocations"). Xcode and screen tests give it as `_XCAppClipURL`.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in miniApp.open(activity.webpageURL) }
                .onOpenURL { miniApp.open($0) }
                .onChange(of: scenePhase, initial: true) { _, phase in miniApp.sceneChanged(to: phase) }
        }
    }
}
