import Foundation

/// The kinds of server function Convex runs.
public enum FunctionKind: String, Sendable {
    case query, mutation, action
}

/// Why the server refused a request: the code every server refusal carries (`Backend/convex/lib/errors.ts`).
public enum RefusalCode: Equatable, Sendable {
    case unauthenticated, noAccount, accountDeleted, invalid, guestTokenRefused, notAMember, eventGone, afterEndTime
    case sealed, exposureTaken, pictureRemoved
    case other(String)

    init(_ code: String) {
        switch code {
        case "unauthenticated": self = .unauthenticated
        case "noAccount": self = .noAccount
        case "accountDeleted": self = .accountDeleted
        case "invalid": self = .invalid
        case "guestTokenRefused": self = .guestTokenRefused
        case "notAMember": self = .notAMember
        case "eventGone": self = .eventGone
        case "afterEndTime": self = .afterEndTime
        case "sealed": self = .sealed
        case "exposureTaken": self = .exposureTaken
        case "pictureRemoved": self = .pictureRemoved
        default: self = .other(code)
        }
    }
}

/// What can go wrong talking to the server.
public enum ServerError: Error, Equatable, Sendable {
    /// The server refused the request, for a reason it named.
    case refused(RefusalCode)
    /// The server could not be reached: no network, a timeout. Nothing changed, and the request can be sent again.
    case unreachable
    /// The server answered with an error of its own, or an answer that could not be read.
    case failed(String)
}

/// The one way the app calls server functions. Convex's HTTP API stands behind it today (`ConvexHTTPClient`); a client
/// with live subscriptions, such as Convex's Swift client, can stand behind it later without changing its callers.
public protocol ServerFunctions: Sendable {
    func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue
}
