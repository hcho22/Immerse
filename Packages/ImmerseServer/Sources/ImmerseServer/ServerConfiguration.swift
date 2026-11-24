import Foundation

/// Where Immerse's server is, and the Clerk instance Hosts sign in with (v2 PRD section 9).
///
/// Both come from the app's Info.plist, which takes them from an untracked build configuration file
/// (`App/Immerse/Config/Server.local.xcconfig`; `Backend/SETUP.md`). A build without them, such as every build made from
/// the repository alone and every v1 build, has no configuration: it shows nothing of Group Films and never signs anyone
/// in or reaches a server.
public struct ServerConfiguration: Equatable, Sendable {
    /// The Convex deployment's address, such as `https://<name>.convex.cloud`.
    public let convexURL: URL
    /// The Clerk instance's publishable key, `pk_test_...` or `pk_live_...`.
    public let clerkPublishableKey: String
    /// The host of the Join Code's link, `https://<join host>/j/<code>` (V2-FR-15), such as the join page's domain. Nil
    /// leaves the app without a link to share or open; the QR code then cannot be made.
    public let joinHost: String?
    /// The support address reports go to (V2-FR-54, OQ-12), shown in the app. Configuration, never committed.
    public let supportAddress: String?

    public static let convexURLKey = "ImmerseConvexURL"
    public static let clerkPublishableKeyKey = "ImmerseClerkPublishableKey"
    public static let joinHostKey = "ImmerseJoinHost"
    public static let supportAddressKey = "ImmerseSupportAddress"
    public static let appGroupKey = "ImmerseAppGroup"

    public init(convexURL: URL, clerkPublishableKey: String, joinHost: String? = nil, supportAddress: String? = nil) {
        self.convexURL = convexURL
        self.clerkPublishableKey = clerkPublishableKey
        self.joinHost = joinHost
        self.supportAddress = supportAddress
    }

    /// The configuration in an Info.plist, or nil when either value is missing, empty or malformed. Only an https address
    /// is accepted, except a loopback address for a local backend.
    public init?(infoDictionary: [String: Any]) {
        guard let key = (infoDictionary[Self.clerkPublishableKeyKey] as? String)?.trimmingCharacters(in: .whitespaces),
              key.hasPrefix("pk_"), let url = Self.serverURL(in: infoDictionary)
        else { return nil }
        self.init(convexURL: url, clerkPublishableKey: key, joinHost: Self.joinHost(in: infoDictionary),
                  supportAddress: Self.supportAddress(in: infoDictionary))
    }

    private static func text(_ key: String, in infoDictionary: [String: Any]) -> String? {
        guard let value = (infoDictionary[key] as? String)?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        return value
    }

    /// The server's address: https, or http on a loopback address for a local backend.
    static func serverURL(in infoDictionary: [String: Any]) -> URL? {
        guard let address = text(convexURLKey, in: infoDictionary), let url = URL(string: address), let host = url.host(),
              !host.isEmpty else { return nil }
        let loopback = host == "127.0.0.1" || host == "localhost"
        guard url.scheme == "https" || (url.scheme == "http" && loopback) else { return nil }
        return url
    }

    /// A bare host name: letters, digits, dots and hyphens.
    static func joinHost(in infoDictionary: [String: Any]) -> String? {
        text(joinHostKey, in: infoDictionary).flatMap { $0.wholeMatch(of: /[A-Za-z0-9.-]+/) != nil ? $0.lowercased() : nil }
    }

    static func supportAddress(in infoDictionary: [String: Any]) -> String? {
        text(supportAddressKey, in: infoDictionary).flatMap { $0.contains("@") ? $0 : nil }
    }

    /// The App Group the full app and the mini-app keep Group Films in (`GroupFilmsFolder`), or nil when the build names
    /// none, as every build without the server configuration does.
    public static func appGroup(in infoDictionary: [String: Any]) -> String? {
        text(appGroupKey, in: infoDictionary).flatMap { $0.wholeMatch(of: /group\.[A-Za-z0-9.-]+/) != nil ? $0 : nil }
    }

    /// The running app's configuration.
    public static var main: ServerConfiguration? {
        ServerConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }
}

/// What the mini-app (the App Clip) needs of the server (v2 PRD V2-FR-19): where it is, the join host its links name and
/// the support address. It carries no Clerk key, because a guest never signs in (V2-FR-21) and the mini-app has no
/// sign-in in it. A mini-app built without these, as from the repository alone, can open no event.
public struct MiniAppConfiguration: Equatable, Sendable {
    public let convexURL: URL
    public let joinHost: String
    public let supportAddress: String?

    public init(convexURL: URL, joinHost: String, supportAddress: String? = nil) {
        self.convexURL = convexURL
        self.joinHost = joinHost
        self.supportAddress = supportAddress
    }

    /// The configuration in an Info.plist, or nil when the server's address or the join host is missing or malformed.
    public init?(infoDictionary: [String: Any]) {
        guard let url = ServerConfiguration.serverURL(in: infoDictionary),
              let joinHost = ServerConfiguration.joinHost(in: infoDictionary) else { return nil }
        self.init(convexURL: url, joinHost: joinHost, supportAddress: ServerConfiguration.supportAddress(in: infoDictionary))
    }

    /// The running mini-app's configuration.
    public static var main: MiniAppConfiguration? {
        MiniAppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }
}
