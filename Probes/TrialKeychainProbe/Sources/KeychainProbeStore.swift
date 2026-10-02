import Foundation
import Security

enum KeychainProbeError: Error, LocalizedError {
    case encodeFailed
    case decodeFailed
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodeFailed:
            "Could not encode the probe record."
        case .decodeFailed:
            "Could not decode the probe record."
        case let .unexpectedStatus(status):
            "Keychain returned OSStatus \(status)."
        }
    }
}

struct KeychainProbeStore {
    private let service = "com.immerse.trial-keychain-probe"
    private let account = "trial-record"

    func read() throws -> KeychainProbeRecord? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainProbeError.unexpectedStatus(status)
        }
        guard let data = result as? Data,
              let record = try? JSONDecoder().decode(KeychainProbeRecord.self, from: data) else {
            throw KeychainProbeError.decodeFailed
        }
        return record
    }

    func write(_ record: KeychainProbeRecord) throws {
        guard let data = try? JSONEncoder().encode(record) else {
            throw KeychainProbeError.encodeFailed
        }

        var query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainProbeError.unexpectedStatus(updateStatus)
        }

        query.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainProbeError.unexpectedStatus(addStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainProbeError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
