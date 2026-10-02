import Foundation
import Security

struct NativeReceiptRead: Sendable {
    let status: OSStatus
    let data: Data?
}

// Only the status/value boundary is studied here. There is deliberately no
// implementation that calls SecItemUpdate, adds items or touches system Keychain.
protocol NativeReceiptCalls: Sendable {
    func copyMatching() -> NativeReceiptRead
    func update(value: Data) -> OSStatus
}

struct NativeReceiptEnvelope: Codable {
    let version: Int
    let record: ReceiptRecord
    init(record: ReceiptRecord) { version = 1; self.record = record }
}

struct NativeReceiptStatusAdapter: ReceiptStoring {
    let calls: any NativeReceiptCalls
    let expectedDeviceID: UUID

    func read() throws -> ReceiptRecord {
        let result = calls.copyMatching()
        guard result.status == errSecSuccess, let bytes = result.data,
              let value = try? JSONDecoder().decode(NativeReceiptEnvelope.self, from: bytes),
              value.version == 1, value.record.deviceID == expectedDeviceID else {
            // This adapter handles an already initialized record only. Missing,
            // malformed, legacy or different-device data cannot imply unused.
            throw ReceiptFailure.unavailable
        }
        return value.record
    }

    func publish(_ receipt: Receipt) throws {
        let before = try read()
        if let existing = before.receipt {
            guard existing == receipt else { throw ReceiptFailure.conflict }
            return
        }
        let desired = ReceiptRecord(deviceID: expectedDeviceID, receipt: receipt)
        let bytes = try JSONEncoder().encode(NativeReceiptEnvelope(record: desired))
        _ = calls.update(value: bytes)
        // Neither success status alone nor any failure code establishes a
        // refundable rejection. Resolve only a matching authoritative read.
        guard let after = try? read(), after.receipt == receipt else {
            throw ReceiptFailure.unknown
        }
    }
}
