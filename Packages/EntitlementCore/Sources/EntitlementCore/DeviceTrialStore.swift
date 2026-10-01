import Foundation
import Security

public struct DeviceTrialRecord: Codable, Equatable, Sendable {
    public let schemaVersion: Int?
    public let deviceID: UUID
    public let consumedFilmID: UUID?
    public let consumedAt: Date?
    public let consumedCaptureID: String?
    public var isConsumed: Bool { consumedFilmID != nil }

    public init(deviceID: UUID = UUID(), consumedFilmID: UUID? = nil, consumedAt: Date? = nil,
                consumedCaptureID: String? = nil) {
        self.schemaVersion = 2
        self.deviceID = deviceID
        self.consumedFilmID = consumedFilmID
        self.consumedAt = consumedAt
        self.consumedCaptureID = consumedCaptureID
    }
}

public protocol DeviceTrialStoring: Sendable {
    func read() throws -> DeviceTrialRecord?
    func ensureDeviceRecord() throws -> DeviceTrialRecord
    func consume(filmID: UUID, captureID: String?, savedAt: Date) throws
}

extension DeviceTrialStoring {
    public func consume(filmID: UUID, savedAt: Date) throws {
        try consume(filmID: filmID, captureID: nil, savedAt: savedAt)
    }
}

public struct TrialKeychainRead: Sendable {
    public let status: OSStatus
    public let data: Data?
    public init(status: OSStatus, data: Data?) { self.status = status; self.data = data }
}

/// Synchronous Security calls; runtime ownership invokes them off the main actor.
/// Inject this boundary in tests rather than creating real Keychain items.
public protocol TrialKeychainCalling: Sendable {
    func read(service: String) -> TrialKeychainRead
    func add(service: String, data: Data) -> OSStatus
    func update(service: String, data: Data) -> OSStatus
}

public struct TrialKeychainError: LocalizedError, Equatable, Sendable {
    public let status: OSStatus
    public var errorDescription: String? {
        "The iPhone's secure Trial record could not be read or updated (Keychain \(status)). Trial eligibility has not been reset."
    }
}

/// The existing device ID never leaves app storage/Keychain. One value contains
/// consumption and its capture receipt; old D3 records decode without a receipt.
public struct KeychainDeviceTrialStore: DeviceTrialStoring {
    private let service: String
    private let calls: any TrialKeychainCalling
    public init(service: String = "com.immerse.device-trial.v1",
                calls: any TrialKeychainCalling = SystemTrialKeychainCalls()) {
        self.service = service
        self.calls = calls
    }

    public func read() throws -> DeviceTrialRecord? {
        let result = calls.read(service: service)
        if result.status == errSecItemNotFound { return nil }
        guard result.status == errSecSuccess else { throw TrialKeychainError(status: result.status) }
        guard let data = result.data else { throw TrialKeychainError(status: errSecDecode) }
        let record = try JSONDecoder().decode(DeviceTrialRecord.self, from: data)
        guard record.schemaVersion == nil || record.schemaVersion == 2,
              (record.consumedFilmID == nil) == (record.consumedAt == nil),
              record.consumedCaptureID == nil || (record.isConsumed && record.consumedCaptureID?.isEmpty == false) else {
            throw TrialKeychainError(status: errSecDecode)
        }
        return record
    }

    public func ensureDeviceRecord() throws -> DeviceTrialRecord {
        if let current = try read() { return current }
        let record = DeviceTrialRecord()
        let status = calls.add(service: service, data: try JSONEncoder().encode(record))
        // A lost add response may still have created the item. Never generate a
        // second identity or acknowledge initialization without reading it back.
        if let existing = try read() { return existing }
        throw TrialKeychainError(status: status == errSecSuccess ? errSecNotAvailable : status)
    }

    public func consume(filmID: UUID, captureID: String?, savedAt: Date) throws {
        guard let record = try read() else { throw TrialKeychainError(status: errSecItemNotFound) }
        if record.isConsumed {
            guard record.consumedFilmID == filmID,
                  captureID == nil || record.consumedCaptureID == captureID else {
                throw TrialKeychainError(status: errSecDuplicateItem)
            }
            return
        }
        let consumed = DeviceTrialRecord(deviceID: record.deviceID, consumedFilmID: filmID,
            consumedAt: savedAt, consumedCaptureID: captureID)
        let status = calls.update(service: service, data: try JSONEncoder().encode(consumed))
        // Every non-success is potentially unknown, never a refundable failure.
        // Even success must be resolved by the matching value before projection.
        guard let observed = try read(), observed == consumed else {
            throw TrialKeychainError(status: status == errSecSuccess ? errSecNotAvailable : status)
        }
    }
}

public struct SystemTrialKeychainCalls: TrialKeychainCalling {
    public init() {}

    public func read(service: String) -> TrialKeychainRead {
        var query = baseQuery(service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return TrialKeychainRead(status: status, data: result as? Data)
    }

    public func add(service: String, data: Data) -> OSStatus {
        var item = baseQuery(service)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil)
    }

    public func update(service: String, data: Data) -> OSStatus {
        SecItemUpdate(baseQuery(service) as CFDictionary, [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary)
    }

    private func baseQuery(_ service: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "device-trial", kSecAttrSynchronizable as String: false]
    }
}
