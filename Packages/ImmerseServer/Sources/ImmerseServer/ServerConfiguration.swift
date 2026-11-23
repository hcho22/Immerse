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

    public static let convexURLKey = "ImmerseConvexURL"
    public static let clerkPublishableKeyKey = "ImmerseClerkPublishableKey"

    public init(convexURL: URL, clerkPublishableKey: String) {
        self.convexURL = convexURL
        self.clerkPublishableKey = clerkPublishableKey
    }

    /// The configuration in an Info.plist, or nil when either value is missing, empty or malformed. Only an https address
    /// is accepted, except a loopback address for a local backend.
    public init?(infoDictionary: [String: Any]) {
        guard let address = (infoDictionary[Self.convexURLKey] as? String)?.trimmingCharacters(in: .whitespaces),
              let key = (infoDictionary[Self.clerkPublishableKeyKey] as? String)?.trimmingCharacters(in: .whitespaces),
              key.hasPrefix("pk_"), let url = URL(string: address), let host = url.host(), !host.isEmpty
        else { return nil }
        let loopback = host == "127.0.0.1" || host == "localhost"
        guard url.scheme == "https" || (url.scheme == "http" && loopback) else { return nil }
        self.init(convexURL: url, clerkPublishableKey: key)
    }

    /// The running app's configuration.
    public static var main: ServerConfiguration? {
        ServerConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }
}
