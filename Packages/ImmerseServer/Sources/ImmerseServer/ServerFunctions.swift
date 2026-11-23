import Foundation

/// The kinds of server function Convex runs.
public enum FunctionKind: String, Sendable {
    case query, mutation, action
}

/// Why the server refused a request: the code every server refusal carries (`Backend/convex/lib/errors.ts`).
public enum RefusalCode: Equatable, Sendable {
    case unauthenticated, noAccount, accountDeleted, invalid, guestTokenRefused, notAMember, eventGone, afterEndTime
    case sealed, exposureTaken, pictureRemoved
    // Group Films (Stage 2).
    case notTheHost, unknownCode, codeReplaced, notYetOpen, joiningPaused, rollsTaken, shootingEnded, removedFromEvent
    case rollLimit, balanceTooLow, notRevealed, alreadyRevealed, identityClaimed
    case other(String)

    private static let named: [String: RefusalCode] = [
        "unauthenticated": .unauthenticated, "noAccount": .noAccount, "accountDeleted": .accountDeleted,
        "invalid": .invalid, "guestTokenRefused": .guestTokenRefused, "notAMember": .notAMember,
        "eventGone": .eventGone, "afterEndTime": .afterEndTime, "sealed": .sealed, "exposureTaken": .exposureTaken,
        "pictureRemoved": .pictureRemoved, "notTheHost": .notTheHost, "unknownCode": .unknownCode,
        "codeReplaced": .codeReplaced, "notYetOpen": .notYetOpen, "joiningPaused": .joiningPaused,
        "rollsTaken": .rollsTaken, "shootingEnded": .shootingEnded, "removedFromEvent": .removedFromEvent,
        "rollLimit": .rollLimit, "balanceTooLow": .balanceTooLow, "notRevealed": .notRevealed,
        "alreadyRevealed": .alreadyRevealed, "identityClaimed": .identityClaimed,
    ]

    init(_ code: String) {
        self = Self.named[code] ?? .other(code)
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

extension JSONValue {
    /// Decodes a reply into a model, through its JSON encoding.
    public func decoded<T: Decodable>(as type: T.Type = T.self) throws(ServerError) -> T {
        do {
            return try JSONDecoder().decode(T.self, from: JSONEncoder().encode(self))
        } catch {
            throw .failed("The server's reply could not be read")
        }
    }
}
