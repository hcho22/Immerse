import XCTest

/// One accessibility audit finding that measurement shows is not a defect, accepted only at one audit point,
/// for one audit type and one exact element label. Every other finding still fails the test.
///
/// Entries are not added for a newly flagged element without the same measurement. If row order, copy or the
/// test's scrolling changes and a different element is flagged, re-examine it instead of extending this list.
/// Evidence: `Evidence/NativeApp/qa13-audit-exceptions-052.md`.
struct AuditException: Equatable {
    let audit: String
    let type: XCUIAccessibilityAuditType
    let label: String

    static let accepted: [AuditException] = [
        // Contrast at the 16mm title audit at the largest text size. The test's held drags stop with this
        // look line's first lines under the navigation bar's scroll-edge blur in every run; at rest it measured
        // 21.00:1 light and 13.94:1 dark (Evidence/NativeApp/prd-2-slice-1-names-card-copy.md).
        AuditException(audit: "16mm-title-accessibility-largest", type: .contrast, label: "Visible grain, a red highlight glow, minor jitter and weave, soft dark edges"),
        // Contrast at the Disposable Load screen's low-storage audit, at the end of the Form, where the warning and
        // Load Film are on screen together. The Form stops there in every run with the end of the Camera's controls
        // line and the start of its look line under the navigation bar's scroll-edge blur; at rest each measured
        // 21.00:1 light and 13.94:1 dark (Evidence/NativeApp/low-storage-warning-062.md).
        AuditException(audit: "Load-low-storage", type: .contrast, label: "Focus switch: Auto / Fixed; tap to focus in Auto; fixed exposure, optional flash and low-light cue"),
        AuditException(audit: "Load-low-storage", type: .contrast, label: "1990s disposable camera: borderless 3:2 picture, warm, saturated color, heavy grain, harsh flash and soft edges"),
    ]

    /// Whether `exceptions` accept a finding; a finding without an element label is never accepted.
    static func accepts(_ exceptions: [AuditException], audit: String, type: XCUIAccessibilityAuditType,
                        label: String?) -> Bool {
        guard let label else { return false }
        return exceptions.contains { $0.audit == audit && $0.type == type && $0.label == label }
    }
}

/// The matching stays exact: another audit point, audit type or label is reported.
final class AuditExceptionTests: XCTestCase {
    private let list = [AuditException(audit: "point", type: .contrast, label: "Accepted")]

    func testOnlyTheExactAuditTypeAndLabelAreAccepted() {
        XCTAssertTrue(accepts("point", .contrast, "Accepted"))
        XCTAssertFalse(accepts("point", .contrast, "Unlisted low contrast"))
        XCTAssertFalse(accepts("point", .contrast, "Accepted text"))
        XCTAssertFalse(accepts("point", .contrast, nil))
        XCTAssertFalse(accepts("point", .dynamicType, "Accepted"))
        XCTAssertFalse(accepts("point", [.contrast, .dynamicType], "Accepted"))
        XCTAssertFalse(accepts("other point", .contrast, "Accepted"))
    }

    private func accepts(_ audit: String, _ type: XCUIAccessibilityAuditType, _ label: String?) -> Bool {
        AuditException.accepts(list, audit: audit, type: type, label: label)
    }
}
