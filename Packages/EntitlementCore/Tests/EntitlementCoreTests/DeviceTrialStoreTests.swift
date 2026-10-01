import EntitlementCore
import Foundation
import Security
import Synchronization
import XCTest

final class DeviceTrialStoreTests: XCTestCase {
    func testConsumptionAndReceiptRequireSameItemReadAcrossAllStatusOutcomes() throws {
        for status in [errSecSuccess, errSecNotAvailable, errSecInteractionNotAllowed,
                       errSecAuthFailed, errSecParam, errSecItemNotFound, errSecAllocate, errSecDecode] {
            for applies in [false, true] {
                let record = DeviceTrialRecord()
                let calls = TestKeychainCalls(data: try JSONEncoder().encode(record))
                calls.status = status; calls.applies = applies
                let store = KeychainDeviceTrialStore(service: "private-injected-study", calls: calls)
                let id = UUID(), capture = UUID().uuidString
                let date = Date(timeIntervalSince1970: 1_790_870_000)
                if applies {
                    try store.consume(filmID: id, captureID: capture, savedAt: date)
                    let result = try XCTUnwrap(store.read())
                    XCTAssertEqual(result.deviceID, record.deviceID)
                    XCTAssertEqual(result.consumedFilmID, id)
                    XCTAssertEqual(result.consumedCaptureID, capture)
                    XCTAssertEqual(result.consumedAt, date)
                    try store.consume(filmID: id, captureID: capture, savedAt: date)
                    XCTAssertEqual(calls.updates, 1)
                } else {
                    XCTAssertThrowsError(try store.consume(filmID: id, captureID: capture, savedAt: date))
                    XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
                    calls.status = errSecSuccess; calls.applies = true
                    try store.consume(filmID: id, captureID: capture, savedAt: date)
                    XCTAssertEqual(try store.read()?.consumedCaptureID, capture)
                }
                XCTAssertEqual(calls.services, ["private-injected-study"])
                XCTAssertEqual(calls.adds, 0)
            }
        }
    }

    func testUnavailableReadAfterUpdateNeverResetsAndRetryDoesNotWriteAgain() throws {
        let calls = TestKeychainCalls(data: try JSONEncoder().encode(DeviceTrialRecord()))
        let store = KeychainDeviceTrialStore(calls: calls)
        let id = UUID(), capture = UUID().uuidString, date = Date()
        calls.readFailureAfterWrite = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.consume(filmID: id, captureID: capture, savedAt: date))
        XCTAssertThrowsError(try store.ensureDeviceRecord())
        XCTAssertEqual(calls.adds, 0)
        calls.readFailure = nil
        try store.consume(filmID: id, captureID: capture, savedAt: date)
        XCTAssertEqual(calls.updates, 1)
        XCTAssertEqual(try store.read()?.consumedCaptureID, capture)
    }

    func testLegacyConsumedRecordIsNotUnusedOrOverwritten() throws {
        let device = UUID(), film = UUID()
        let data = Data("{\"deviceID\":\"\(device)\",\"consumedFilmID\":\"\(film)\",\"consumedAt\":1}".utf8)
        let calls = TestKeychainCalls(data: data)
        let store = KeychainDeviceTrialStore(calls: calls)
        let record = try XCTUnwrap(store.read())
        XCTAssertEqual(record.deviceID, device)
        XCTAssertNil(record.schemaVersion)
        XCTAssertTrue(record.isConsumed)
        XCTAssertNil(record.consumedCaptureID)
        try store.consume(filmID: film, savedAt: Date())
        XCTAssertThrowsError(try store.consume(filmID: UUID(), captureID: "other", savedAt: Date()))
        XCTAssertEqual(calls.updates, 0)
        XCTAssertEqual(calls.adds, 0)
    }

    func testMalformedFutureAndPartialRecordsFailClosedWithoutInitialization() throws {
        let device = UUID()
        for text in ["invalid", "{\"deviceID\":\"\(device)\",\"schemaVersion\":3}",
            "{\"deviceID\":\"\(device)\",\"consumedFilmID\":\"\(UUID())\"}",
            "{\"deviceID\":\"\(device)\",\"consumedCaptureID\":\"orphan\"}"] {
            let calls = TestKeychainCalls(data: Data(text.utf8))
            let store = KeychainDeviceTrialStore(calls: calls)
            XCTAssertThrowsError(try store.read())
            XCTAssertThrowsError(try store.ensureDeviceRecord())
            XCTAssertEqual(calls.adds, 0)
            XCTAssertEqual(calls.updates, 0)
        }
    }

    func testMissingItemCannotBeCreatedByConsumptionAndLostAddReplyUsesReadback() throws {
        let calls = TestKeychainCalls(data: nil)
        let store = KeychainDeviceTrialStore(calls: calls)
        XCTAssertThrowsError(try store.consume(filmID: UUID(), captureID: "pending", savedAt: Date()))
        XCTAssertEqual(calls.adds, 0)
        calls.status = errSecNotAvailable
        let initialized = try store.ensureDeviceRecord()
        XCTAssertFalse(initialized.isConsumed)
        XCTAssertEqual(try store.ensureDeviceRecord(), initialized)
        XCTAssertEqual(calls.adds, 1)
    }

    func testSuccessStatusWithMissingMalformedOrMismatchedReceiptIsNotAcknowledged() throws {
        let record = DeviceTrialRecord(), film = UUID(), date = Date(timeIntervalSince1970: 1_790_870_000)
        let mismatches: [TrialKeychainRead] = [
            .init(status: errSecItemNotFound, data: nil),
            .init(status: errSecSuccess, data: nil),
            .init(status: errSecSuccess, data: Data("malformed".utf8)),
            .init(status: errSecSuccess, data: try JSONEncoder().encode(DeviceTrialRecord(
                consumedFilmID: film, consumedAt: date, consumedCaptureID: "capture"))),
            .init(status: errSecSuccess, data: try JSONEncoder().encode(DeviceTrialRecord(deviceID: record.deviceID,
                consumedFilmID: film, consumedAt: date, consumedCaptureID: "different"))),
            .init(status: errSecSuccess, data: try JSONEncoder().encode(DeviceTrialRecord(deviceID: record.deviceID,
                consumedFilmID: film, consumedAt: date.addingTimeInterval(1), consumedCaptureID: "capture")))
        ]
        for result in mismatches {
            let calls = TestKeychainCalls(data: try JSONEncoder().encode(record))
            calls.readOverrideAfterWrite = result
            let store = KeychainDeviceTrialStore(calls: calls)
            XCTAssertThrowsError(try store.consume(filmID: film, captureID: "capture", savedAt: date))
            XCTAssertEqual(calls.updates, 1)
            XCTAssertEqual(calls.adds, 0)
        }
    }
}

private final class TestKeychainCalls: TrialKeychainCalling, Sendable {
    private struct State {
        var data: Data?
        var status = errSecSuccess
        var applies = true
        var readFailure: OSStatus?
        var readFailureAfterWrite: OSStatus?
        var readOverrideAfterWrite: TrialKeychainRead?
        var readOverride: TrialKeychainRead?
        var updates = 0
        var adds = 0
        var services: Set<String> = []
    }
    private let state: Mutex<State>
    init(data: Data?) { state = Mutex(State(data: data)) }
    var status: OSStatus {
        get { state.withLock { $0.status } }
        set { state.withLock { $0.status = newValue } }
    }
    var applies: Bool {
        get { state.withLock { $0.applies } }
        set { state.withLock { $0.applies = newValue } }
    }
    var readFailure: OSStatus? {
        get { state.withLock { $0.readFailure } }
        set { state.withLock { $0.readFailure = newValue } }
    }
    var readFailureAfterWrite: OSStatus? {
        get { state.withLock { $0.readFailureAfterWrite } }
        set { state.withLock { $0.readFailureAfterWrite = newValue } }
    }
    var adds: Int { state.withLock { $0.adds } }
    var readOverrideAfterWrite: TrialKeychainRead? {
        get { state.withLock { $0.readOverrideAfterWrite } }
        set { state.withLock { $0.readOverrideAfterWrite = newValue } }
    }
    var updates: Int { state.withLock { $0.updates } }
    var services: Set<String> { state.withLock { $0.services } }
    func read(service: String) -> TrialKeychainRead {
        state.withLock { value in
            value.services.insert(service)
            if let result = value.readOverride { return result }
            if let status = value.readFailure { return TrialKeychainRead(status: status, data: nil) }
            return TrialKeychainRead(status: value.data == nil ? errSecItemNotFound : errSecSuccess, data: value.data)
        }
    }
    func add(service: String, data: Data) -> OSStatus { write(service: service, data: data, adding: true) }
    func update(service: String, data: Data) -> OSStatus { write(service: service, data: data, adding: false) }
    private func write(service: String, data: Data, adding: Bool) -> OSStatus {
        state.withLock { value in
            value.services.insert(service)
            if adding { value.adds += 1 } else { value.updates += 1 }
            if value.applies { value.data = data }
            value.readFailure = value.readFailureAfterWrite
            value.readOverride = value.readOverrideAfterWrite
            return value.status
        }
    }
}
