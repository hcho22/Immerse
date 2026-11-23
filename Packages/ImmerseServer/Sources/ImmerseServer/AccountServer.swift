import Foundation

/// The signed-in person's Account as the server holds it (v2 PRD section 8).
public struct Account: Equatable, Sendable {
    public let displayName: String
    public let ageConfirmedAt: Date

    public init(displayName: String, ageConfirmedAt: Date) {
        self.displayName = displayName
        self.ageConfirmedAt = ageConfirmedAt
    }
}

/// Where a signed-in person stands with the server (`accounts:me`).
public enum AccountState: Equatable, Sendable {
    /// No valid Clerk session reached the server.
    case signedOut
    /// Signed in with Clerk, with no Account yet: the age confirmation and `createAccount` come next (V2-FR-03).
    case noAccount
    /// The Account was deleted, or is being deleted (V2-FR-05).
    case accountDeleted
    case signedIn(Account)
}

/// How the age 13-or-over confirmation was made (open check OC-9).
public enum AgeConfirmationMethod: String, Sendable {
    /// Apple's Declared Age Range, where iOS says the person's region requires it.
    case declaredAgeRange
    /// The person's own birth month and year, checked on the iPhone and never sent.
    case birthMonthAndYear
}

/// The environment of Apple's push service a device token belongs to: sandbox for Xcode's Debug builds, production for
/// TestFlight and the App Store.
public enum PushEnvironment: String, Sendable {
    case sandbox, production
}

/// The Account operations (V2-FR-01 to V2-FR-05), and the push token of this installation (V2-FR-70).
public struct AccountServer: Sendable {
    private let functions: any ServerFunctions

    public init(functions: any ServerFunctions) {
        self.functions = functions
    }

    public func state() async throws(ServerError) -> AccountState {
        let reply = try await functions.call(.query, "accounts:me", [:])
        switch reply["state"]?.string {
        case "signedOut": return .signedOut
        case "noAccount": return .noAccount
        case "accountDeleted": return .accountDeleted
        case "signedIn":
            guard let account = reply["account"], let name = account["displayName"]?.string,
                  let confirmed = account["ageConfirmedAt"]?.number
            else { throw .failed("The Account could not be read") }
            return .signedIn(Account(displayName: name, ageConfirmedAt: Date(timeIntervalSince1970: confirmed / 1000)))
        default: throw .failed("The Account could not be read")
        }
    }

    /// Creates the Account once the person has confirmed they are 13 or over. Safe to repeat.
    public func createAccount(displayName: String, confirmedBy method: AgeConfirmationMethod) async throws(ServerError) {
        _ = try await functions.call(.mutation, "accounts:createAccount", [
            "displayName": .string(displayName), "ageConfirmed": true, "ageConfirmation": .string(method.rawValue),
        ])
    }

    public func setDisplayName(_ displayName: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "accounts:setDisplayName", ["displayName": .string(displayName)])
    }

    /// Deletes the Account on the server, which also deletes its Clerk user. Safe to repeat.
    public func deleteAccount() async throws(ServerError) {
        _ = try await functions.call(.action, "deletion:deleteAccount", [:])
    }

    public func registerPushToken(_ token: Data, installationID: String, environment: PushEnvironment) async throws(ServerError) {
        _ = try await functions.call(.mutation, "pushTokens:register", [
            "installationId": .string(installationID),
            "token": .string(token.map { String(format: "%02x", $0) }.joined()),
            "environment": .string(environment.rawValue),
        ])
    }

    public func unregisterPushToken(installationID: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "pushTokens:unregister", ["installationId": .string(installationID)])
    }
}
