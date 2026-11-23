import Foundation
import ImmerseServer
import Synchronization
import XCTest
@testable import Immerse

/// The hosting session's rules (V2-FR-01 to V2-FR-08), with a stand-in server and sign-in: losing the network never
/// signs anyone out, a deleted Account signs the iPhone out, and nothing about it survives sign-out but the Films.
@MainActor
final class HostingSessionTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "HostingSessionTests-\(UUID().uuidString)")
    }

    func testASignedInHostStaysSignedInWithoutANetwork() async {
        let server = ScriptedServer()
        let signIn = StubSignIn(session: true)
        let session = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        server.reply("accounts:me", ["state": "signedIn", "account": ["displayName": "Maya", "ageConfirmedAt": 1, "createdAt": 1]])
        await session.refresh()
        XCTAssertEqual(session.phase, .signedIn(displayName: "Maya"))
        // The network goes; a relaunch and a refresh keep the Host signed in.
        server.failEverything(with: .unreachable)
        let relaunched = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        XCTAssertEqual(relaunched.phase, .signedIn(displayName: "Maya"))
        await relaunched.refresh()
        XCTAssertEqual(relaunched.phase, .signedIn(displayName: "Maya"))
        XCTAssertEqual(signIn.signOuts, 0)
    }

    func testSigningInCreatesTheAccountWithTheAgeConfirmationAndTheSuggestedName() async {
        let server = ScriptedServer()
        let signIn = StubSignIn(session: false)
        let session = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        XCTAssertEqual(session.phase, .signedOut)
        server.reply("accounts:me", ["state": "noAccount"])
        server.reply("accounts:createAccount", ["created": true])
        server.onCall("accounts:createAccount") {
            server.reply("accounts:me", ["state": "signedIn", "account": ["displayName": "Maya", "ageConfirmedAt": 1, "createdAt": 1]])
        }
        await session.signInWithGoogle(confirmedBy: .birthMonthAndYear)
        XCTAssertEqual(session.phase, .signedIn(displayName: "Maya"))
        let create = server.calls.first { $0.path == "accounts:createAccount" }
        XCTAssertEqual(create?.args["ageConfirmation"]?.string, "birthMonthAndYear")
        XCTAssertEqual(create?.args["displayName"]?.string, "Maya")
    }

    func testAnAccountDeletedElsewhereSignsThisIPhoneOut() async {
        let server = ScriptedServer()
        let signIn = StubSignIn(session: true)
        defaults.set("Maya", forKey: "ImmerseHostDisplayName")
        let session = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        server.reply("accounts:me", ["state": "accountDeleted"])
        await session.refresh()
        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertEqual(signIn.signOuts, 1)
    }

    func testDeleteAccountSignsOutOnlyOnceTheServerHasDeletedIt() async {
        let server = ScriptedServer()
        let signIn = StubSignIn(session: true)
        defaults.set("Maya", forKey: "ImmerseHostDisplayName")
        let session = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        server.fail("deletion:deleteAccount", with: .unreachable)
        await session.deleteAccount()
        XCTAssertEqual(session.phase, .signedIn(displayName: "Maya"), "A deletion the server did not confirm signs nobody out")
        XCTAssertNotNil(session.problem)
        server.reply("deletion:deleteAccount", ["deleted": true])
        await session.deleteAccount()
        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertTrue(session.accountDeletedNotice)
        XCTAssertEqual(signIn.signOuts, 1)
        XCTAssertNil(defaults.string(forKey: "ImmerseHostDisplayName"))
    }

    func testSignOutDropsThisInstallationsPushToken() async {
        let server = ScriptedServer()
        let signIn = StubSignIn(session: true)
        let session = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        server.reply("pushTokens:unregister", ["unregistered": true])
        await session.signOut()
        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertEqual(server.calls.map(\.path), ["pushTokens:unregister"])
        XCTAssertEqual(server.calls.first?.args["installationId"]?.string, HostingSession.installationID(defaults: defaults))
    }

    func testAHostIsNotSignedOutBeforeClerkHasAnswered() async {
        let server = ScriptedServer()
        let signIn = StubSignIn(session: false)
        signIn.sessionIsKnown = false
        defaults.set("Maya", forKey: "ImmerseHostDisplayName")
        let session = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        XCTAssertEqual(session.phase, .signedIn(displayName: "Maya"))
        await session.refresh()
        XCTAssertEqual(session.phase, .signedIn(displayName: "Maya"), "Nothing is cleared before Clerk answers")
        XCTAssertEqual(defaults.string(forKey: "ImmerseHostDisplayName"), "Maya")
        // Once Clerk answers that there is no session, the iPhone is signed out.
        signIn.sessionIsKnown = true
        await session.refresh()
        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertNil(defaults.string(forKey: "ImmerseHostDisplayName"))
    }

    func testAMethodThatEndsWithNoSessionSaysSo() async {
        let server = ScriptedServer()
        let signIn = StubSignIn(session: false)
        signIn.endsWithoutSession = true
        let session = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        await session.signInWithGoogle(confirmedBy: .birthMonthAndYear)
        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertEqual(session.problem, "Sign-in did not finish. Try again.")
        XCTAssertTrue(server.calls.isEmpty, "No Account is made without a session")
    }

    func testAgeDeclinesLastADay() {
        let now = Date()
        XCTAssertFalse(AgeDecline.isRecent(defaults: defaults, now: now))
        AgeDecline.record(defaults: defaults, now: now)
        XCTAssertTrue(AgeDecline.isRecent(defaults: defaults, now: now.addingTimeInterval(23 * 3600)))
        XCTAssertFalse(AgeDecline.isRecent(defaults: defaults, now: now.addingTimeInterval(25 * 3600)))
    }

    func testTheDisplayNameStartsFromWhatClerkKnows() {
        XCTAssertEqual(HostingSession.displayName(from: "  Maya "), "Maya")
        XCTAssertEqual(HostingSession.displayName(from: nil), "Host")
        XCTAssertEqual(HostingSession.displayName(from: String(repeating: "x", count: 60)).count, 40)
    }
}

@MainActor
private final class StubSignIn: HostSignIn {
    var hasSession: Bool
    var sessionIsKnown = true
    var signOuts = 0
    init(session: Bool) { hasSession = session }
    var suggestedDisplayName: String? { "Maya" }
    func sessionToken() async -> String? { hasSession ? "t" : nil }
    func signInWithApple(identityToken: String, givenName: String?, familyName: String?) async throws { hasSession = true }
    var endsWithoutSession = false
    func signInWithGoogle() async throws { hasSession = !endsWithoutSession }
    func sendEmailCode(to address: String) async throws {}
    func verifyEmailCode(_ code: String) async throws { hasSession = true }
    func signOut() async throws {
        signOuts += 1
        hasSession = false
    }
}

/// A server whose replies a test scripts per function path.
private final class ScriptedServer: ServerFunctions, @unchecked Sendable {
    struct Call { let path: String; let args: [String: JSONValue] }
    private let lock = NSLock()
    private var replies: [String: Result<JSONValue, ServerError>] = [:]
    private var hooks: [String: () -> Void] = [:]
    private var everything: ServerError?
    private(set) var calls: [Call] = []

    func reply(_ path: String, _ value: JSONValue) { lock.withLock { replies[path] = .success(value) } }
    func fail(_ path: String, with error: ServerError) { lock.withLock { replies[path] = .failure(error) } }
    func failEverything(with error: ServerError) { lock.withLock { everything = error } }
    func onCall(_ path: String, _ hook: @escaping () -> Void) { lock.withLock { hooks[path] = hook } }

    func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue {
        let (result, hook): (Result<JSONValue, ServerError>, (() -> Void)?) = lock.withLock {
            calls.append(Call(path: path, args: args))
            if let everything { return (.failure(everything), nil) }
            return (replies[path] ?? .failure(.failed("no reply for \(path)")), hooks[path])
        }
        let value = try result.get()
        hook?()
        return value
    }
}
