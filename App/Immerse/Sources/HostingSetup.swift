import ImmerseServer
import UIKit

@MainActor
enum HostingSetup {
    /// The hosting session, where the app has a server configuration; nil otherwise, which is every build made from the
    /// repository alone. A Debug build launched with `-ImmerseDebugHosting signedOut` or `signedIn` uses a stand-in
    /// server and sign-in instead, for screen tests.
    static func make() -> HostingSession? {
        #if DEBUG
        if let stub = DebugHosting.session(arguments: ProcessInfo.processInfo.arguments) { return stub }
        #endif
        guard let configuration = ServerConfiguration.main else { return nil }
        let signIn = ClerkHostSignIn(publishableKey: configuration.clerkPublishableKey)
        let client = ConvexHTTPClient(deploymentURL: configuration.convexURL) { await signIn.sessionToken() }
        return HostingSession(signIn: signIn, functions: client)
    }
}

/// This installation's push token, for the push test (open check OC-7). iOS hands the token to the app delegate.
@MainActor
final class PushRegistration {
    static let shared = PushRegistration()
    private var waiting: [CheckedContinuation<Data, Error>] = []

    /// Registers with Apple's push service and returns the device token.
    func register() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            waiting.append(continuation)
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func registered(_ token: Data) {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(returning: token) }
    }

    func failed(_ error: Error) {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(throwing: error) }
    }

    /// Sandbox for a build Xcode installs, production for TestFlight and the App Store; `aps-environment` decides it.
    static var environment: PushEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }
}
