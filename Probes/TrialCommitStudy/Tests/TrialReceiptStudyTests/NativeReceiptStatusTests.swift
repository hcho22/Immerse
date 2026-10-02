import Foundation
import Security
import Synchronization
import XCTest
@testable import TrialReceiptStudy

final class NativeReceiptStatusTests: XCTestCase {
    func testMissingProtectedMalformedLegacyOrForeignRecordNeverMeansUnused() throws {
        let device = UUID()
        let valid = try encoded(device: device)
        let legacy = Data("{\"deviceID\":\"\(device)\",\"consumedFilmID\":\"\(UUID())\",\"consumedAt\":1}".utf8)
        let unknownVersion = Data("{\"version\":2,\"record\":{\"deviceID\":\"\(device)\"}}".utf8)
        let inputs: [NativeReceiptRead] = [
            .init(status: errSecItemNotFound, data: nil),
            .init(status: errSecInteractionNotAllowed, data: valid),
            .init(status: errSecNotAvailable, data: nil),
            .init(status: errSecSuccess, data: nil),
            .init(status: errSecSuccess, data: Data("invalid".utf8)),
            .init(status: errSecSuccess, data: legacy),
            .init(status: errSecSuccess, data: unknownVersion),
            .init(status: errSecSuccess, data: try encoded(device: UUID()))
        ]
        for value in inputs {
            let calls = StatusCalls(bytes: valid)
            calls.overrideRead = value
            let store = NativeReceiptStatusAdapter(calls: calls, expectedDeviceID: device)
            XCTAssertThrowsError(try store.read()) { XCTAssertEqual($0 as? ReceiptFailure, .unavailable) }
            XCTAssertThrowsError(try store.publish(receipt()))
            XCTAssertEqual(calls.updateCount, 0)
        }
    }

    func testEveryUpdateStatusRequiresMatchingReadBeforeAcknowledgement() throws {
        for status in [errSecSuccess, errSecNotAvailable, errSecInteractionNotAllowed, errSecAuthFailed,
                       errSecParam, errSecItemNotFound, errSecAllocate, errSecDecode] {
            for applied in [false, true] {
                let device = UUID()
                let calls = StatusCalls(bytes: try encoded(device: device))
                calls.updateStatus = status; calls.appliesUpdate = applied
                let store = NativeReceiptStatusAdapter(calls: calls, expectedDeviceID: device)
                let receipt = receipt()
                if applied {
                    try store.publish(receipt)
                    XCTAssertEqual(try store.read().receipt, receipt)
                    try store.publish(receipt)
                    XCTAssertEqual(calls.updateCount, 1)
                } else {
                    XCTAssertThrowsError(try store.publish(receipt)) { XCTAssertEqual($0 as? ReceiptFailure, .unknown) }
                    XCTAssertNil(try store.read().receipt)
                    calls.appliesUpdate = true; calls.updateStatus = errSecSuccess
                    try store.publish(receipt)
                    XCTAssertEqual(try store.read().receipt, receipt)
                    XCTAssertEqual(calls.updateCount, 2)
                }
                print("RECEIPT_STATUS status=\(status) applied=\(applied) resolvedByRead=true")
            }
        }
    }

    func testUnreadableReplyDoesNotLoseReceiptAndRetryDoesNotRewriteIt() throws {
        let device = UUID()
        let calls = StatusCalls(bytes: try encoded(device: device))
        let store = NativeReceiptStatusAdapter(calls: calls, expectedDeviceID: device)
        let receipt = receipt()
        calls.readAfterUpdate = .init(status: errSecNotAvailable, data: nil)
        XCTAssertThrowsError(try store.publish(receipt)) { XCTAssertEqual($0 as? ReceiptFailure, .unknown) }
        XCTAssertThrowsError(try store.read())
        calls.overrideRead = nil
        XCTAssertEqual(try store.read().receipt, receipt)
        try store.publish(receipt)
        XCTAssertEqual(calls.updateCount, 1)
    }

    func testAnotherReceiptIsNeverOverwrittenOrAcceptedAsThisCapture() throws {
        let device = UUID()
        let first = receipt()
        let calls = StatusCalls(bytes: try encoded(device: device, receipt: first))
        let store = NativeReceiptStatusAdapter(calls: calls, expectedDeviceID: device)
        XCTAssertThrowsError(try store.publish(receipt())) { XCTAssertEqual($0 as? ReceiptFailure, .conflict) }
        XCTAssertEqual(calls.updateCount, 0)
        XCTAssertEqual(try store.read().receipt, first)
    }

    private func receipt() -> Receipt {
        Receipt(filmID: UUID(), captureID: UUID(), savedAt: Date(timeIntervalSince1970: 1_790_870_000))
    }
    private func encoded(device: UUID, receipt: Receipt? = nil) throws -> Data {
        try JSONEncoder().encode(NativeReceiptEnvelope(record: ReceiptRecord(deviceID: device, receipt: receipt)))
    }
}

final class StatusCalls: NativeReceiptCalls, Sendable {
    private struct State {
        var bytes: Data
        var updateStatus = errSecSuccess
        var appliesUpdate = true
        var overrideRead: NativeReceiptRead?
        var readAfterUpdate: NativeReceiptRead?
        var updateCount = 0
    }
    private let state: Mutex<State>
    init(bytes: Data) { state = Mutex(State(bytes: bytes)) }
    var updateStatus: OSStatus {
        get { state.withLock { $0.updateStatus } }
        set { state.withLock { $0.updateStatus = newValue } }
    }
    var appliesUpdate: Bool {
        get { state.withLock { $0.appliesUpdate } }
        set { state.withLock { $0.appliesUpdate = newValue } }
    }
    var overrideRead: NativeReceiptRead? {
        get { state.withLock { $0.overrideRead } }
        set { state.withLock { $0.overrideRead = newValue } }
    }
    var readAfterUpdate: NativeReceiptRead? {
        get { state.withLock { $0.readAfterUpdate } }
        set { state.withLock { $0.readAfterUpdate = newValue } }
    }
    var updateCount: Int { state.withLock { $0.updateCount } }
    func copyMatching() -> NativeReceiptRead {
        state.withLock { $0.overrideRead ?? .init(status: errSecSuccess, data: $0.bytes) }
    }
    func update(value: Data) -> OSStatus {
        state.withLock { state in
            state.updateCount += 1
            if state.appliesUpdate { state.bytes = value }
            state.overrideRead = state.readAfterUpdate
            return state.updateStatus
        }
    }
}
