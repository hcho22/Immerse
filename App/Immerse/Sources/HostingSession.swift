import Foundation
import ImmerseServer
import Observation

/// Signing in with Clerk (V2-FR-01): Sign in with Apple, Google, or an email address and the code Clerk sends to it.
/// `ClerkHostSignIn` is the real one; Debug builds can stand a stub in for screen tests.
@MainActor
protocol HostSignIn: AnyObject, Sendable {
    /// Whether Clerk holds a session on this iPhone. It stays true without a network: losing the network never signs
    /// anyone out (V2-FR-08).
    var hasSession: Bool { get }
    /// A name to start the Host's display name from: the name Apple, Google or the person gave Clerk, or nil.
    var suggestedDisplayName: String? { get }
    /// The current session token for Convex, refreshed by Clerk's SDK, or nil when signed out or unreachable.
    func sessionToken() async -> String?
    /// Signs in with the identity token of a Sign in with Apple authorization.
    func signInWithApple(identityToken: String) async throws
    func signInWithGoogle() async throws
    /// Sends a code to the address, for signing in or, for a new address, signing up.
    func sendEmailCode(to address: String) async throws
    func verifyEmailCode(_ code: String) async throws
    func signOut() async throws
}

/// Whether the person is signed in to host, and the Account operations around it (V2-FR-01 to V2-FR-08).
///
/// It exists only where the app has a server configuration (`ServerConfiguration`), and nothing else in the app reads
/// it: personal Films, the Trial and the subscription never ask for sign-in and never wait on it (V2-FR-02, V2-FR-07).
@MainActor @Observable
final class HostingSession {
    enum Phase: Equatable {
        case signedOut
        /// Signed in with Clerk, with no Account on the server yet.
        case needsAccount
        case signedIn(displayName: String)
    }

    private(set) var phase: Phase
    private(set) var busy = false
    /// What went wrong with the last request, in words for the person.
    var problem: String?
    /// Said once after Delete Account succeeds.
    var accountDeletedNotice = false

    let signIn: HostSignIn
    private let accounts: AccountServer
    let functions: any ServerFunctions
    /// Where this session keeps its small records: the last Account seen, a recent age decline.
    let defaults: UserDefaults
    private static let displayNameKey = "ImmerseHostDisplayName"

    init(signIn: HostSignIn, functions: any ServerFunctions, defaults: UserDefaults = .standard) {
        self.signIn = signIn
        self.functions = functions
        self.accounts = AccountServer(functions: functions)
        self.defaults = defaults
        // The last Account this iPhone saw, so the Host stays signed in without a network (V2-FR-08).
        if signIn.hasSession {
            phase = defaults.string(forKey: Self.displayNameKey).map { .signedIn(displayName: $0) } ?? .needsAccount
        } else {
            phase = .signedOut
        }
    }

    /// The installation's random id for its push token: never a device identifier (section 8).
    static func installationID(defaults: UserDefaults = .standard) -> String {
        let key = "ImmerseInstallationID"
        if let existing = defaults.string(forKey: key) { return existing }
        var bytes = [UInt8](repeating: 0, count: 18)
        for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        let id = Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        defaults.set(id, forKey: key)
        return id
    }

    /// Reads the Account from the server. Without a network it keeps what it knew.
    func refresh() async {
        guard signIn.hasSession else { return settle(.signedOut) }
        do {
            switch try await accounts.state() {
            case .signedIn(let account): settle(.signedIn(displayName: account.displayName))
            case .noAccount: settle(.needsAccount)
            case .signedOut:
                // Clerk holds a session the server could not verify yet, such as one whose token could not be refreshed.
                break
            case .accountDeleted:
                try? await signIn.signOut()
                settle(.signedOut)
            }
        } catch {
            // Unreachable, or refused for a moment: nobody is signed out for it.
        }
    }

    /// Creates the Account once the person signed in and confirmed age 13 or over (V2-FR-03).
    func createAccount(confirmedBy method: AgeConfirmationMethod) async {
        await run {
            let name = HostingSession.displayName(from: self.signIn.suggestedDisplayName)
            try await self.accounts.createAccount(displayName: name, confirmedBy: method)
            await self.refresh()
        }
    }

    func signInWithApple(identityToken: String, confirmedBy method: AgeConfirmationMethod) async {
        await run { try await self.signIn.signInWithApple(identityToken: identityToken) }
        await finishSignIn(confirmedBy: method)
    }

    func signInWithGoogle(confirmedBy method: AgeConfirmationMethod) async {
        await run { try await self.signIn.signInWithGoogle() }
        await finishSignIn(confirmedBy: method)
    }

    func sendEmailCode(to address: String) async -> Bool {
        await run { try await self.signIn.sendEmailCode(to: address) }
    }

    func verifyEmailCode(_ code: String, confirmedBy method: AgeConfirmationMethod) async {
        await run { try await self.signIn.verifyEmailCode(code) }
        await finishSignIn(confirmedBy: method)
    }

    private func finishSignIn(confirmedBy method: AgeConfirmationMethod) async {
        guard signIn.hasSession else { return }
        await refresh()
        if phase == .needsAccount { await createAccount(confirmedBy: method) }
    }

    /// Signs out of Clerk and drops this installation's push token. Personal Films are untouched (V2-FR-02).
    func signOut() async {
        await run {
            try? await self.accounts.unregisterPushToken(installationID: HostingSession.installationID(defaults: self.defaults))
            try await self.signIn.signOut()
            self.settle(.signedOut)
        }
    }

    /// Delete Account (V2-FR-05): the server removes everything that names the person and deletes the Clerk user, then
    /// this iPhone signs out. Personal Films stay.
    func deleteAccount() async {
        let deleted = await run { try await self.accounts.deleteAccount() }
        guard deleted else { return }
        try? await signIn.signOut()
        settle(.signedOut)
        accountDeletedNotice = true
    }

    private func settle(_ next: Phase) {
        phase = next
        if case .signedIn(let name) = next { defaults.set(name, forKey: Self.displayNameKey) }
        else { defaults.removeObject(forKey: Self.displayNameKey) }
    }

    @discardableResult
    private func run(_ work: @escaping @MainActor () async throws -> Void) async -> Bool {
        busy = true
        problem = nil
        defer { busy = false }
        do {
            try await work()
            return true
        } catch is CancellationError {
            return false
        } catch {
            problem = HostingSession.words(for: error)
            return false
        }
    }

    /// A display name of 1 to 40 characters from what Clerk knows, or "Host".
    static func displayName(from suggestion: String?) -> String {
        let trimmed = (suggestion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Host" }
        return String(trimmed.prefix(40))
    }

    static func words(for error: Error) -> String {
        switch error as? ServerError {
        case .unreachable: return "Immerse could not reach its server. Check the connection and try again."
        case .refused(.accountDeleted): return "This Account was deleted. Sign in again to make a new one."
        case .refused, .failed: return "Something went wrong on Immerse's server. Try again."
        case nil:
            if let signInError = error as? HostSignInError { return signInError.words }
            return "Sign-in did not finish. Try again."
        }
    }
}

/// What a sign-in method can say went wrong, in the person's words.
struct HostSignInError: Error {
    let words: String
}
