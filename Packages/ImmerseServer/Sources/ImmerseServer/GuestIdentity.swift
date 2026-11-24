import Foundation
import Security
import Synchronization

/// The phone's guest identity (v2 PRD V2-FR-23, section 9.2): a random id and a secret made on the phone at its first
/// join, never a device identifier. The server keeps only a verifier of the secret. It is what lets a guest with no
/// Account shoot, upload, withdraw and see the album, on this phone only, until the guest claims it into an Account.
public struct GuestIdentity: Codable, Equatable, Sendable {
    public let publicId: String
    public let secret: String

    public init(publicId: String, secret: String) {
        self.publicId = publicId
        self.secret = secret
    }

    /// A new identity: 18 random bytes of id and 32 of secret, base64url without padding.
    public static func make() -> GuestIdentity {
        GuestIdentity(publicId: randomToken(bytes: 18), secret: randomToken(bytes: 32))
    }

    static func randomToken(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        precondition(SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess, "No secure random bytes")
        return Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    /// The credentials as the server's functions take them.
    var json: JSONValue { ["publicId": .string(publicId), "secret": .string(secret)] }
}

/// Where the phone keeps its guest identity.
public protocol GuestIdentityStoring: Sendable {
    func read() throws -> GuestIdentity?
    func write(_ identity: GuestIdentity) throws
    func delete() throws
}

extension GuestIdentityStoring {
    /// The phone's identity, made and kept the first time it is needed.
    public func identity() throws -> GuestIdentity {
        if let existing = try read() { return existing }
        let made = GuestIdentity.make()
        try write(made)
        return made
    }
}

public enum GuestIdentityStoreError: Error, Equatable {
    case keychain(OSStatus)
    case unreadable
}

/// The full app's guest identity in the Keychain, on this iPhone only and never synced, as v1's Trial record is: it
/// survives a reinstall where the Keychain does (V2-FR-23), and it never leaves the phone in a backup to another one.
public struct KeychainGuestIdentityStore: GuestIdentityStoring {
    private let service: String

    public init(service: String = "com.immerse.FilmJournal.guest-identity") {
        self.service = service
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "guest-identity", kSecAttrSynchronizable as String: false]
    }

    public func read() throws -> GuestIdentity? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw GuestIdentityStoreError.keychain(status) }
        guard let data = result as? Data, let identity = try? JSONDecoder().decode(GuestIdentity.self, from: data) else {
            throw GuestIdentityStoreError.unreadable
        }
        return identity
    }

    public func write(_ identity: GuestIdentity) throws {
        let data = try JSONEncoder().encode(identity)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
            let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            guard updated == errSecSuccess else { throw GuestIdentityStoreError.keychain(updated) }
        } else if status != errSecSuccess {
            throw GuestIdentityStoreError.keychain(status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw GuestIdentityStoreError.keychain(status) }
    }
}

/// A guest identity held in memory, for tests and screen tests.
public final class MemoryGuestIdentityStore: GuestIdentityStoring {
    private let stored: Mutex<GuestIdentity?>

    public init(_ identity: GuestIdentity? = nil) {
        stored = Mutex(identity)
    }

    public func read() throws -> GuestIdentity? { stored.withLock { $0 } }
    public func write(_ identity: GuestIdentity) throws { stored.withLock { $0 = identity } }
    public func delete() throws { stored.withLock { $0 = nil } }
}
