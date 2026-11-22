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
        // Contrast at Choose a Camera's audit at the largest text size. On CI (run 44932061664) the check, run in one pass
        // with the clipped-text check, which swaps the Cameras' column for the dial and back, flagged the 6×6 and Super 8
        // rows' names; at rest their white words on Orbit's #1A1A1A are 17.4:1, in the one appearance Orbit has
        // (Evidence/NativeApp/orbit-083.md).
        AuditException(audit: "Catalog-accessibility-largest", type: .contrast, label: "6×6"),
        AuditException(audit: "Catalog-accessibility-largest", type: .contrast, label: "Super 8"),
        // Contrast at the 16mm title audit at the largest text size. On a 390-point iPhone the test's held drags stop
        // with the Movie Orientation's Landscape option half under the navigation bar's scroll-edge blur; at rest its
        // white word on Orbit's #1A1A1A circle is 17.4:1, in the one appearance Orbit has (Evidence/NativeApp/orbit-083.md).
        AuditException(audit: "16mm-title-accessibility-largest", type: .contrast, label: "Landscape"),
        // Contrast at the Disposable Load screen's low-storage audit, at the end of the screen, where the warning and
        // Load Film are on screen together. The screen stops there with the Camera's reveal chip, and on a 390-point
        // iPhone its name too, under the navigation bar's scroll-edge blur; at rest the chip's #D4D4D4 words on Orbit's
        // #1A1A1A are 11.7:1 and the white name on black 21:1 (Evidence/NativeApp/orbit-083.md).
        AuditException(audit: "Load-low-storage", type: .contrast, label: "Sealed until Development"),
        AuditException(audit: "Load-low-storage", type: .contrast, label: "Disposable"),
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
