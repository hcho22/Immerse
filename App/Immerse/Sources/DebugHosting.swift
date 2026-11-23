#if DEBUG
import Foundation
import ImmerseServer
import Synchronization

/// Debug builds only: a stand-in server and sign-in for screen tests, so they can open the hosting screens with no
/// Clerk instance and no Convex deployment. `-ImmerseDebugHosting signedOut` starts signed out, `signedIn` with an
/// Account. Every sign-in method succeeds at once. `Scripts/verify-release-excludes-testing-unlock.sh` holds it out of
/// Release.
@MainActor
enum DebugHosting {
    static func session(arguments: [String]) -> HostingSession? {
        guard let index = arguments.firstIndex(of: "-ImmerseDebugHosting"), index + 1 < arguments.count else { return nil }
        let start = arguments[index + 1]
        let server = DebugHostingServer(accountName: start == "signedIn" ? "Maya" : nil)
        let signIn = DebugHostSignIn(server: server, signedIn: start == "signedIn")
        let defaults = UserDefaults(suiteName: "ImmerseDebugHosting")!
        defaults.removePersistentDomain(forName: "ImmerseDebugHosting")
        return HostingSession(signIn: signIn, functions: server, defaults: defaults)
    }
}

@MainActor
final class DebugHostSignIn: HostSignIn {
    private let server: DebugHostingServer
    private(set) var hasSession: Bool

    init(server: DebugHostingServer, signedIn: Bool) {
        self.server = server
        self.hasSession = signedIn
        server.setSession(signedIn)
    }

    var suggestedDisplayName: String? { "Maya" }
    func sessionToken() async -> String? { hasSession ? "debug-session" : nil }
    func signInWithApple(identityToken: String) async throws { start() }
    func signInWithGoogle() async throws { start() }
    func sendEmailCode(to address: String) async throws {}
    func verifyEmailCode(_ code: String) async throws { start() }
    func signOut() async throws {
        hasSession = false
        server.setSession(false)
    }

    private func start() {
        hasSession = true
        server.setSession(true)
    }
}

/// The server functions the hosting screens call, held in memory.
final class DebugHostingServer: ServerFunctions {
    private let state: Mutex<(session: Bool, accountName: String?)>

    init(accountName: String?) {
        state = Mutex((false, accountName))
    }

    func setSession(_ session: Bool) { state.withLock { $0.session = session } }

    func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue {
        try state.withLock { (state) throws(ServerError) -> JSONValue in
            guard state.session else {
                if path == "accounts:me" { return ["state": "signedOut"] }
                throw .refused(.unauthenticated)
            }
            switch path {
            case "accounts:me":
                guard let name = state.accountName else { return ["state": "noAccount"] }
                return ["state": "signedIn", "account": ["displayName": .string(name), "ageConfirmedAt": 1_795_000_000_000, "createdAt": 1]]
            case "accounts:createAccount":
                if state.accountName == nil { state.accountName = args["displayName"]?.string ?? "Host" }
                return ["created": true]
            case "deletion:deleteAccount":
                state.accountName = nil
                return ["deleted": true]
            case "pushTokens:register", "pushTokens:unregister":
                return [:]
            default:
                throw .failed("The stand-in server has no \(path)")
            }
        }
    }
}
#endif
