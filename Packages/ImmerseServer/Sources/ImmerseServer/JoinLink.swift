import Foundation

/// The Join Code's link (v2 PRD V2-FR-15): `https://<join host>/j/<code>`, the one link and QR code an event keeps for its
/// whole life unless the Host replaces the code. The join host is configuration (`ServerConfiguration.joinHost`); on an
/// iPhone with Immerse installed it opens the full app through its associated domain (Backend/SETUP.md).
public enum JoinLink {
    /// A code is 22 base64url characters: 128 bits.
    static func isCode(_ text: String) -> Bool {
        text.count == 22 && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    /// The link for a code.
    public static func url(code: String, host: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/j/\(code)"
        return components.url
    }

    /// The code a link carries, when it is a join link for this host; nil for anything else.
    public static func code(in url: URL, host: String) -> String? {
        guard url.scheme == "https", url.host()?.lowercased() == host.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "j", isCode(parts[1]) else { return nil }
        return parts[1]
    }
}
