import Foundation
import Security

public struct DeviceTrialRecord: Codable, Equatable, Sendable {
    public let deviceID: UUID
    public let consumedFilmID: UUID?
    public let consumedAt: Date?
    public var isConsumed: Bool { consumedFilmID != nil }

    public init(deviceID: UUID = UUID(), consumedFilmID: UUID? = nil, consumedAt: Date? = nil) {
        self.deviceID = deviceID
        self.consumedFilmID = consumedFilmID
        self.consumedAt = consumedAt
    }
}

public protocol DeviceTrialStoring: Sendable {
    func read() throws -> DeviceTrialRecord?
    func ensureDeviceRecord() throws -> DeviceTrialRecord
    func consume(filmID: UUID, savedAt: Date) throws
}

public struct TrialKeychainError: LocalizedError, Equatable, Sendable {
    public let status: OSStatus
    public var errorDescription: String? {
        "The iPhone's secure Trial record could not be read or updated (Keychain \(status)). Trial eligibility has not been reset."
    }
}

/// Baseline D1/D2 only. The random identifier never leaves app storage/Keychain.
public struct KeychainDeviceTrialStore: DeviceTrialStoring {
    private let service: String
    public init(service: String = "com.immerse.device-trial.v1") { self.service = service }

    public func read() throws -> DeviceTrialRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw TrialKeychainError(status: status) }
        let record = try JSONDecoder().decode(DeviceTrialRecord.self, from: data)
        guard (record.consumedFilmID == nil) == (record.consumedAt == nil) else {
            throw TrialKeychainError(status: errSecDecode)
        }
        return record
    }

    public func ensureDeviceRecord() throws -> DeviceTrialRecord {
        if let current = try read() { return current }
        let record = DeviceTrialRecord()
        var item = baseQuery
        item[kSecValueData as String] = try JSONEncoder().encode(record)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem, let existing = try read() { return existing }
        guard status == errSecSuccess else { throw TrialKeychainError(status: status) }
        return record
    }

    public func consume(filmID: UUID, savedAt: Date) throws {
        let record = try ensureDeviceRecord()
        if record.isConsumed { return }
        let consumed = DeviceTrialRecord(deviceID: record.deviceID, consumedFilmID: filmID, consumedAt: savedAt)
        let status = SecItemUpdate(baseQuery as CFDictionary, [
            kSecValueData as String: try JSONEncoder().encode(consumed),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary)
        guard status == errSecSuccess else { throw TrialKeychainError(status: status) }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "device-trial", kSecAttrSynchronizable as String: false]
    }
}
