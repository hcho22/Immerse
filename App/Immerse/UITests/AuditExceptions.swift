import XCTest

/// One accessibility audit finding that measurement shows is not a defect, accepted only at one audit point,
/// for one audit type and one exact element label. Every other finding still fails the test.
///
/// Entries are not added for a newly flagged element without the same measurement. If row order or copy
/// changes and a different element is flagged, re-examine it instead of extending this list.
/// Evidence: `Evidence/NativeApp/qa13-audit-exceptions-052.md`.
struct AuditException: Equatable {
    let audit: String
    let type: XCUIAccessibilityAuditType
    let label: String

    static let accepted: [AuditException] = [
        // Dynamic Type at the Super 8 load screen, default text size. The auditor grows the text in place,
        // without scrolling, and reports any Form row that is on screen at AX XL but scrolled out of view by
        // AX XXXL; the lazy Form does not redraw those rows until they scroll back in. It follows the position:
        // a plain substitute row in this slot was flagged 4 of 4 times, and moving these rows up flagged the
        // unchanged "Handheld..." and "Silent capture" rows instead. Measured per size, the label is 20 pt tall
        // at L and 48 pt at AX XL, the options 29 pt and 56 pt; `ContentSizeTests` checks the growth to AX XXXL.
        AuditException(audit: "Super8-load-default", type: .dynamicType, label: "Movie Orientation"),
        AuditException(audit: "Super8-load-default", type: .dynamicType, label: "Portrait"),
        AuditException(audit: "Super8-load-default", type: .dynamicType, label: "Landscape"),
        // Contrast at the two 16mm audits at the largest text size, after the test scrolls. Each element was
        // flagged on this source and measures, fully visible at rest, 21.00:1 light and 9.12 to 13.94:1 dark.
        // The description and the label are flagged only while under the navigation bar's scroll-edge blur
        // (1.75 to 10.97:1 there); the others measure 9.12 to 21.00:1 in the auditor's own screenshots.
        AuditException(audit: "16mm-title-accessibility-largest", type: .contrast, label: "Deliberate framing, finer grain"),
        AuditException(audit: "16mm-title-accessibility-largest", type: .contrast, label: "Silent capture"),
        AuditException(audit: "16mm-command-accessibility-largest", type: .contrast, label: "Movie Orientation"),
        AuditException(audit: "16mm-command-accessibility-largest", type: .contrast, label: "Portrait"),
        AuditException(audit: "16mm-command-accessibility-largest", type: .contrast, label: "Trial status unavailable"),
        AuditException(audit: "16mm-command-accessibility-largest", type: .contrast,
                       label: "Your Camera and Movie Orientation cannot change after loading."),
    ]

    /// Whether `exceptions` accept a finding; a finding without an element label is never accepted.
    static func accepts(_ exceptions: [AuditException], audit: String, type: XCUIAccessibilityAuditType,
                        label: String?) -> Bool {
        guard let label else { return false }
        return exceptions.contains(AuditException(audit: audit, type: type, label: label))
    }
}

/// The matching stays exact: another audit point, audit type or label is reported.
final class AuditExceptionTests: XCTestCase {
    private let list = [AuditException(audit: "point", type: .contrast, label: "Accepted")]

    func testOnlyTheExactAuditTypeAndLabelAreAccepted() {
        XCTAssertTrue(AuditException.accepts(list, audit: "point", type: .contrast, label: "Accepted"))
        XCTAssertFalse(AuditException.accepts(list, audit: "point", type: .contrast, label: "Unlisted low contrast"))
        XCTAssertFalse(AuditException.accepts(list, audit: "point", type: .contrast, label: "Accepted text"))
        XCTAssertFalse(AuditException.accepts(list, audit: "point", type: .contrast, label: nil))
        XCTAssertFalse(AuditException.accepts(list, audit: "point", type: .dynamicType, label: "Accepted"))
        XCTAssertFalse(AuditException.accepts(list, audit: "point", type: [.contrast, .dynamicType], label: "Accepted"))
        XCTAssertFalse(AuditException.accepts(list, audit: "other point", type: .contrast, label: "Accepted"))
    }
}
