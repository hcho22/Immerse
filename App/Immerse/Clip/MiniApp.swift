import ImmerseServer
import Observation
import SwiftUI

/// The mini-app's own state: the Group Films it runs on, the link that opened it, and whether the full app has since
/// taken over (v2 PRD V2-FR-19).
///
/// A guest's place, Roll, pictures and upload queue are kept in the folder the mini-app shares with the full app
/// (`GroupFilmsFolder`), and the guest identity in the mini-app's own Keychain item, which the full app can read. So
/// installing the full app needs no step here: the full app opens the same folder. From then on iOS gives every link to
/// the full app. A mini-app that is still open finds the full app's mark in the folder, stops, and sends the guest on.
@MainActor @Observable
final class MiniApp {
    private(set) var groupFilms: GroupFilms?
    /// The full app has taken the shared folder over; the mini-app writes nothing more.
    private(set) var handedOver = false
    /// The link that last opened the mini-app, which also opens the full app once it is installed.
    private(set) var lastLink: URL?
    private let joinHost: String?
    private static let lastLinkKey = "ImmerseMiniAppLastLink"

    init(groupFilms: GroupFilms?, joinHost: String?, handedOver: Bool = false) {
        self.groupFilms = groupFilms
        self.joinHost = joinHost
        self.handedOver = handedOver
        lastLink = UserDefaults.standard.url(forKey: Self.lastLinkKey)
    }

    static func make() -> MiniApp {
        #if DEBUG
        // Screen tests run the mini-app against the Debug stand-in for the event functions, with no server.
        if let hosting = DebugHosting.session(arguments: ProcessInfo.processInfo.arguments),
           let debug = DebugGroupFilms.make(hosting: hosting) {
            return MiniApp(groupFilms: debug, joinHost: DebugGroupFilms.joinHost)
        }
        #endif
        // A mini-app built without the server configuration, as from the repository alone, can open no event.
        guard let configuration = MiniAppConfiguration.main else { return MiniApp(groupFilms: nil, joinHost: nil) }
        do {
            let folder = try GroupFilmsFolder.locate(appGroup: ServerConfiguration.appGroup(in: Bundle.main.infoDictionary ?? [:]))
            guard !folder.fullAppTookOver else {
                return MiniApp(groupFilms: nil, joinHost: configuration.joinHost, handedOver: true)
            }
            // No session token: a guest never signs in (V2-FR-21), and the mini-app has no sign-in in it.
            let functions = ConvexHTTPClient(deploymentURL: configuration.convexURL) { nil }
            let hosting = HostingSession(signIn: NoSignIn(), functions: functions)
            let groupFilms = try GroupFilmsSetup.make(hosting: hosting, folder: folder, identities: KeychainGuestIdentityStore.miniApp,
                                                      joinHost: configuration.joinHost,
                                                      supportAddress: configuration.supportAddress)
            return MiniApp(groupFilms: groupFilms, joinHost: configuration.joinHost)
        } catch {
            return MiniApp(groupFilms: nil, joinHost: configuration.joinHost)
        }
    }

    /// A link or QR code opened the mini-app. Anything that is not an event's link is ignored (Apple: "guard against
    /// faulty data").
    func open(_ url: URL?) {
        guard let url, let joinHost, JoinLink.code(in: url, host: joinHost) != nil else { return }
        lastLink = url
        UserDefaults.standard.set(url, forKey: Self.lastLinkKey)
        _ = groupFilms?.handle(url: url)
    }

    func sceneChanged(to phase: ScenePhase) {
        if phase == .active { yieldIfTheFullAppTookOver() }
        guard let groupFilms else { return }
        groupFilms.rolls.sceneChanged(to: phase)
        switch phase {
        case .active: groupFilms.becameActive()
        case .background: groupFilms.enteredBackground()
        default: break
        }
    }

    /// The full app ran while the mini-app was away: the folder is the full app's now, so the mini-app lets go of it.
    private func yieldIfTheFullAppTookOver() {
        guard let groupFilms, groupFilms.folder.isShared, groupFilms.folder.fullAppTookOver else { return }
        groupFilms.enteredBackground()
        self.groupFilms = nil
        handedOver = true
    }
}

/// The mini-app has no sign-in: nobody is ever signed in here, and nothing asks (V2-FR-21). Signing in to keep a place
/// across phones is in the full app (V2-FR-04).
@MainActor
private final class NoSignIn: HostSignIn {
    private static let unavailable = HostSignInError(words: "Signing in is in the Immerse app.")
    var hasSession: Bool { false }
    var sessionIsKnown: Bool { true }
    var suggestedDisplayName: String? { nil }
    func sessionToken() async -> String? { nil }
    func signInWithApple(identityToken: String, givenName: String?, familyName: String?) async throws { throw Self.unavailable }
    func signInWithGoogle() async throws { throw Self.unavailable }
    func sendEmailCode(to address: String) async throws { throw Self.unavailable }
    func verifyEmailCode(_ code: String) async throws { throw Self.unavailable }
    func signOut() async throws {}
}
