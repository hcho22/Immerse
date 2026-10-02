import XCTest

@MainActor
final class JournalFlowTests: XCTestCase {
    func testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore() throws {
        let app = XCUIApplication.shippingGate()
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        for id in ["disposable1990s", "instant1970s", "mediumFormat6x6", "super8HomeMovie", "cinema16mm"] {
            XCTAssertTrue(app.buttons["camera-\(id)"].exists)
        }
        app.buttons["camera-super8HomeMovie"].tap()
        // Assert the load screen's own capacity element; a bare "3:20 of film" query also matched the
        // outgoing camera row mid-push (Evidence/NativeApp/qa13-measurement-049.md).
        XCTAssertTrue(app.staticTexts["Capacity, 3:20 of film"].exists)
        XCTAssertTrue(app.buttons["load-film"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        try audit(app, name: "Super8-load-default", for: Self.formAuditTypes)
        retainScreenshot(app, name: "Super8-load-default")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Your Journal begins here"].exists)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Restoring an older backup")).firstMatch.exists)
        app.buttons["Done"].tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["No archived Films"].exists)
    }

    /// The contrast exceptions stay narrow against the real auditor: at the same 16mm title pose, with only the
    /// description's entry withheld, the audit fails on exactly that element. The held-drag pose puts it under the
    /// navigation bar in every run; if the auditor stops flagging it, re-examine that entry.
    func testAuditStillReportsContrastFindingsOutsideItsExceptions() throws {
        let app = XCUIApplication.shippingGate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        let camera = app.buttons["camera-cinema16mm"]
        for _ in 0..<5 where !camera.isHittable { app.swipeUp() }
        camera.tap()
        XCTAssertTrue(app.staticTexts["Capacity, 2:45 of film"].waitForExistence(timeout: 5))
        let title = app.staticTexts["film-title-heading"]
        scrollUp(app, until: title)
        XCTAssertTrue(title.isHittable)
        let withheld = AuditException.accepted.filter { $0.label != "Deliberate framing, finer grain" }
        XCTAssertEqual(withheld.count, AuditException.accepted.count - 1)
        var reported: [String] = []
        XCTExpectFailure("A finding outside the exceptions must fail the audit") {
            reported = (try? audit(app, name: "16mm-title-accessibility-largest", for: .contrast, exceptions: withheld)) ?? []
        }
        XCTAssertEqual(reported, ["Deliberate framing, finer grain"])
    }

    func testLargestDynamicTypeCatalogAndLandscapeSettings() throws {
        let app = XCUIApplication.shippingGate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
        retainScreenshot(app, name: "Catalog-accessibility-largest")
        let camera = app.buttons["camera-cinema16mm"]
        for _ in 0..<5 where !camera.isHittable { app.swipeUp() }
        XCTAssertTrue(camera.isHittable)
        camera.tap()
        // The load screen exposes its capacity as one "Capacity, 2:45 of film" element. A bare "2:45 of film"
        // query also matched the outgoing camera row mid-push, so it passed or failed with timing
        // (Evidence/NativeApp/qa13-measurement-049.md).
        XCTAssertTrue(app.staticTexts["Capacity, 2:45 of film"].exists)
        try app.performAccessibilityAudit()
        retainScreenshot(app, name: "16mm-load-accessibility-largest")
        let title = app.staticTexts["film-title-heading"]
        scrollUp(app, until: title)
        XCTAssertTrue(title.isHittable)
        try audit(app, name: "16mm-title-accessibility-largest", for: Self.formAuditTypes)
        retainScreenshot(app, name: "16mm-title-accessibility-largest")
        let load = app.buttons["load-film"]
        scrollUp(app, until: load)
        XCTAssertTrue(load.isHittable)
        try audit(app, name: "16mm-command-accessibility-largest", for: Self.formAuditTypes)
        retainScreenshot(app, name: "16mm-command-accessibility-largest")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
        retainScreenshot(app, name: "Settings-landscape-accessibility-largest")
    }

    func testDeniedCameraAtLoadFilmLoadsNothingAndPointsToSettings() throws {
        let app = XCUIApplication.shippingGate()
        app.resetAuthorizationStatus(for: .camera)
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        app.buttons["camera-disposable1990s"].tap()
        let load = app.buttons["load-film"]
        for _ in 0..<8 where !load.isHittable { app.swipeUp() }

        // Answer the actual system Camera request as a person declining it. Without this
        // monitor, XCTest's own alert handling would allow access.
        var declined = false
        let monitor = addUIInterruptionMonitor(withDescription: "Camera access request") { alert in
            let deny = alert.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Don")).firstMatch
            guard alert.label.localizedCaseInsensitiveContains("Camera"), deny.exists else { return false }
            deny.tap()
            declined = true
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        load.tap()
        let denied = app.staticTexts["Camera access is off. No Film was loaded. Allow Camera in iPhone Settings."]
        // The monitor runs only on an interaction made while the request is showing, which can appear late.
        for _ in 0..<20 where !denied.exists {
            app.navigationBars.firstMatch.tap()
            _ = denied.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(denied.exists)
        XCTAssertTrue(declined, "Load Film must ask for Camera access")
        retainScreenshot(app, name: "Load-camera-denied")
        XCTAssertFalse(app.alerts.firstMatch.exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Your Journal begins here"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        // Form rows combine the label and value into one accessibility element.
        let camera = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Camera, ")).firstMatch
        for _ in 0..<8 where !camera.exists { app.swipeUp() }
        XCTAssertEqual(camera.label, "Camera, Off", "Settings reports the declined Camera access")
        retainScreenshot(app, name: "Settings-camera-denied")
    }

    /// Every audit type except Dynamic Type, for the three audits of the Form-based Load screens. Xcode's Dynamic
    /// Type check grows the text in place, and over this lazy Form it flagged different rows from run to run,
    /// scrolled or not (Evidence/NativeApp/qa13-audit-exceptions-052.md). `ContentSizeTests` instead measures every
    /// text element on these screens at all twelve sizes; Dynamic Type stays in the other audits.
    private static let formAuditTypes = XCUIAccessibilityAuditType.all.subtracting(.dynamicType)

    /// Scrolls up in equal, slow drags that end held, so the list never coasts, until `element` can be tapped.
    /// Free swipes coasted a different distance each run, which changed the rows under the bars at each audit
    /// (Evidence/NativeApp/qa13-audit-exceptions-052.md). The drag runs along the right edge, outside the rows' controls.
    private func scrollUp(_ app: XCUIApplication, until element: XCUIElement) {
        for _ in 0..<16 where !element.isHittable {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Audits the screen, failing on every finding except the exact entries in `exceptions`, and returns
    /// the labels of the findings it reported.
    @discardableResult
    private func audit(_ app: XCUIApplication, name: String, for types: XCUIAccessibilityAuditType = .all,
                       exceptions: [AuditException] = AuditException.accepted) throws -> [String] {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name)-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
        var reported: [String] = []
        let handler: (XCUIAccessibilityAuditIssue) throws -> Bool = { issue in
            let label = issue.element?.label
            let accepted = AuditException.accepts(exceptions, audit: name, type: issue.auditType, label: label)
            let detail = XCTAttachment(string: "\(issue.auditType): \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No element supplied by auditor")")
            detail.name = "\(name)-audit-node\(accepted ? "-accepted-exception" : "")"
            detail.lifetime = .keepAlways
            self.add(detail)
            if !accepted { reported.append(label ?? "") }
            return accepted
        }
        // The Dynamic Type and clipped-text checks grow and shrink the text in place. In a scrolled list the offset
        // clamps while the content is short and is not restored, so every other check runs first, at the pose the
        // test set (Evidence/NativeApp/qa13-audit-exceptions-052.md).
        let resizing: XCUIAccessibilityAuditType = [.dynamicType, .textClipped]
        let others = types.subtracting(resizing)
        if !others.isEmpty { try app.performAccessibilityAudit(for: others, handler) }
        let resized = types.intersection(resizing)
        if !resized.isEmpty { try app.performAccessibilityAudit(for: resized, handler) }
        return reported
    }
}
