import EntitlementCore
import Security
import XCTest
@testable import ReceiptScenarioHarness

final class ReceiptNativeSecurityTests: XCTestCase {
    func testExplicitNativeSecurityCapabilityAndReceipt() async throws {
        let scenario = try ReceiptScenario(configuration: .init(runID: UUID(), cameraID: .disposable1990s,
            backend: .security, fault: .none, pauseAt: "none"))
        do { try await scenario.prepare() }
        catch let error as TrialKeychainError {
            scenario.evidence.record("native-capability-unavailable", ["status": String(error.status)])
            throw XCTSkip("Actual Security unavailable: \(error.status). No injected fallback or native receipt pass.")
        }
        try await scenario.commit()
        try await scenario.recover()
        let result = try await scenario.inventory()
        XCTAssertEqual(result.underlyingStatus, errSecSuccess)
        XCTAssertEqual(result.underlyingRecord?.consumedCaptureID, result.sqlReceipt?.captureID)
        XCTAssertEqual(result.underlyingRecord?.consumedFilmID, result.manifest.filmID)
        XCTAssertEqual(result.underlyingRecord?.consumedAt, result.manifest.savedAt)
        XCTAssertEqual(result.films.first?.savedCaptureCount, 1)
        XCTAssertEqual(result.sourceMatches, true)
        XCTAssertFalse(result.pending)
        do { try await scenario.attemptSecondLoad(); XCTFail("Consumed native receipt cannot load a second Film") }
        catch EntitlementDenial.currentDeviceTrialConsumed { }
    }
}
