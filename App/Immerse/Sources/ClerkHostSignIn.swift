import ClerkKit
import Foundation

/// Sign-in through Clerk's iOS SDK (V2-FR-01, ADR 0028), linked to Convex: Convex verifies each session token against
/// the Clerk instance's issuer (`Backend/convex/auth.config.ts`).
///
/// Clerk is configured only when the app has a server configuration, so a build without one never starts Clerk or
/// reaches it. Clerk keeps the session's client credential in the Keychain and refreshes the one-minute session token
/// itself while the app is in use, so a Host stays signed in for as long as the Clerk instance's session lifetime allows
/// (open check OC-8; `Backend/SETUP.md`).
@MainActor
final class ClerkHostSignIn: HostSignIn {
    private var pendingSignIn: SignIn?
    private var pendingSignUp: SignUp?

    init(publishableKey: String) {
        Clerk.configure(publishableKey: publishableKey)
    }

    var hasSession: Bool { Clerk.shared.session != nil }

    var suggestedDisplayName: String? {
        guard let user = Clerk.shared.user else { return nil }
        if let first = user.firstName, !first.isEmpty { return first }
        return user.primaryEmailAddress?.emailAddress.split(separator: "@").first.map(String.init)
    }

    func sessionToken() async -> String? {
        try? await Clerk.shared.session?.getToken()
    }

    func signInWithApple(identityToken: String) async throws {
        try await Clerk.shared.auth.signInWithIdToken(identityToken, provider: .apple)
    }

    func signInWithGoogle() async throws {
        try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    }

    func sendEmailCode(to address: String) async throws {
        pendingSignIn = nil
        pendingSignUp = nil
        do {
            pendingSignIn = try await Clerk.shared.auth.signInWithEmailCode(emailAddress: address)
        } catch let error as ClerkAPIError where error.code == "form_identifier_not_found" {
            // A new address signs up, with the same code step.
            pendingSignUp = try await Clerk.shared.auth.signUp(emailAddress: address).sendEmailCode()
        } catch let error as ClerkAPIError {
            throw HostSignInError(words: error.longMessage ?? error.message ?? "That email address could not be used.")
        }
    }

    func verifyEmailCode(_ code: String) async throws {
        do {
            if let signIn = pendingSignIn {
                _ = try await signIn.verifyCode(code)
            } else if let signUp = pendingSignUp {
                _ = try await signUp.verifyEmailCode(code)
            } else {
                throw HostSignInError(words: "Ask for a new code and try again.")
            }
        } catch let error as ClerkAPIError {
            throw HostSignInError(words: error.longMessage ?? error.message ?? "That code did not work.")
        }
        pendingSignIn = nil
        pendingSignUp = nil
    }

    func signOut() async throws {
        try await Clerk.shared.auth.signOut()
    }
}
