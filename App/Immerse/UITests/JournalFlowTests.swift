import XCTest

@MainActor
final class JournalFlowTests: XCTestCase {
    func testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore() throws {
        let app = XCUIApplication.shippingGate()
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.auditTypes)
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        for id in ["disposable1990s", "instant1970s", "mediumFormat6x6", "super8HomeMovie", "cinema16mm"] {
            XCTAssertTrue(app.buttons["camera-\(id)"].exists)
        }
        let camera = app.buttons["camera-super8HomeMovie"]
        camera.tap()
        // Audit only once the outgoing camera row has left the tree, after the push (Evidence/NativeApp/push-audit-055.md).
        XCTAssertTrue(camera.waitForNonExistence(timeout: 5))
        // Assert the load screen's own capacity element; a bare capacity query also matched the
        // outgoing camera row mid-push (Evidence/NativeApp/qa13-measurement-049.md).
        XCTAssertTrue(app.staticTexts["Capacity, 3 minutes 20 seconds of film"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        try audit(app, name: "Super8-load-default", for: Self.auditTypes)
        retainScreenshot(name: "Super8-load-default")
        // The Form is lazy and its Camera description is long enough that the command is below the first screen.
        scrollUp(app, until: app.buttons["load-film"])
        XCTAssertTrue(app.buttons["load-film"].exists)
        app.navigationBars["Super 8"].buttons.element(boundBy: 0).tap()
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
        XCTAssertTrue(app.staticTexts["Capacity, 2 minutes 47 seconds of film"].waitForExistence(timeout: 5))
        let title = app.staticTexts["film-title-heading"]
        scrollUp(app, until: title)
        XCTAssertTrue(title.isHittable)
        let withheld = AuditException.accepted.filter { $0.label != "Visible grain, a red highlight glow, minor jitter and weave, soft dark edges" }
        XCTAssertEqual(withheld.count, AuditException.accepted.count - 1)
        var reported: [String] = []
        XCTExpectFailure("A finding outside the exceptions must fail the audit") {
            reported = (try? audit(app, name: "16mm-title-accessibility-largest", for: .contrast, exceptions: withheld)) ?? []
        }
        XCTAssertEqual(reported, ["Visible grain, a red highlight glow, minor jitter and weave, soft dark edges"])
    }

    /// Every Camera's Load screen at the smallest text size, where the Film title field's text is shortest: 19 points,
    /// which the hit-region check reported as too small to tap until the field's frame became at least 44 points tall
    /// (Evidence/NativeApp/title-field-hit-area-056.md). Each audit waits until the tapped Camera row has left the
    /// tree, after the push, so the outgoing catalog is not audited. One test per Camera: all five in one test took
    /// 1 minute 24 seconds on CI and ran past the 3-minute allowance when the runner slowed to about half speed
    /// (run 37627486582), which the allowance counts as a failure (Evidence/NativeApp/ci-flakes-057.md).
    func testExtraSmallLoadScreenAuditDisposable() throws { try auditExtraSmallLoadScreen(id: "disposable1990s", name: "Disposable") }
    func testExtraSmallLoadScreenAuditInstant() throws { try auditExtraSmallLoadScreen(id: "instant1970s", name: "Instant") }
    func testExtraSmallLoadScreenAudit6x6() throws { try auditExtraSmallLoadScreen(id: "mediumFormat6x6", name: "6×6") }
    func testExtraSmallLoadScreenAuditSuper8() throws { try auditExtraSmallLoadScreen(id: "super8HomeMovie", name: "Super 8") }
    func testExtraSmallLoadScreenAudit16mm() throws { try auditExtraSmallLoadScreen(id: "cinema16mm", name: "16mm") }

    private func auditExtraSmallLoadScreen(id: String, name: String) throws {
        let app = XCUIApplication.shippingGate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXS"]
        app.launch()
        openCameraCatalog(app)
        let camera = app.buttons["camera-\(id)"]
        scrollUp(app, until: camera)
        camera.tap()
        XCTAssertTrue(camera.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars[name].exists)
        let field = app.textFields["film-title"]
        scrollUp(app, until: field)
        XCTAssertTrue(field.isHittable)
        try audit(app, name: "\(name)-load-extra-small", for: Self.auditTypes)
        retainScreenshot(name: "\(name)-load-extra-small")
        // The Journal's bar stays in the tree under the catalog sheet on smaller iPhones, so go back from this bar.
        app.navigationBars[name].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
    }

    func testLargestDynamicTypeCatalogAndLandscapeSettings() throws {
        let app = XCUIApplication.shippingGate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: Self.auditTypes)
        retainScreenshot(name: "Catalog-accessibility-largest")
        let camera = app.buttons["camera-cinema16mm"]
        for _ in 0..<5 where !camera.isHittable { app.swipeUp() }
        XCTAssertTrue(camera.isHittable)
        camera.tap()
        // The tap can return before the push ends, or even starts, while the outgoing camera rows are still in the tree
        // with sliding or zero-size frames. An audit that began then reported four "Hit area is too small" findings
        // without elements, so the audit waits until the camera row has left the tree (Evidence/NativeApp/push-audit-055.md).
        XCTAssertTrue(camera.waitForNonExistence(timeout: 5))
        // The load screen exposes its capacity as one "Capacity, 2 minutes 47 seconds of film" element. A bare
        // capacity query also matched the outgoing camera row mid-push, so it passed or failed with timing
        // (Evidence/NativeApp/qa13-measurement-049.md).
        XCTAssertTrue(app.staticTexts["Capacity, 2 minutes 47 seconds of film"].exists)
        try app.performAccessibilityAudit(for: Self.auditTypes)
        retainScreenshot(name: "16mm-load-accessibility-largest")
        let title = app.staticTexts["film-title-heading"]
        scrollUp(app, until: title)
        XCTAssertTrue(title.isHittable)
        try audit(app, name: "16mm-title-accessibility-largest", for: Self.auditTypes)
        retainScreenshot(name: "16mm-title-accessibility-largest")
        let load = app.buttons["load-film"]
        scrollUp(app, until: load)
        XCTAssertTrue(load.isHittable)
        try audit(app, name: "16mm-command-accessibility-largest", for: Self.auditTypes)
        retainScreenshot(name: "16mm-command-accessibility-largest")
        app.navigationBars["16mm"].buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: Self.auditTypes)
        retainScreenshot(name: "Settings-landscape-accessibility-largest")
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
        retainScreenshot(name: "Load-camera-denied")
        XCTAssertFalse(app.alerts.firstMatch.exists)

        app.navigationBars["Disposable"].buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Your Journal begins here"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        // Form rows combine the label and value into one accessibility element.
        let camera = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Camera, ")).firstMatch
        for _ in 0..<8 where !camera.exists { app.swipeUp() }
        XCTAssertEqual(camera.label, "Camera, Off", "Settings reports the declined Camera access")
        retainScreenshot(name: "Settings-camera-denied")
    }

    /// Every audit type except Dynamic Type, for every audit. Xcode's Dynamic Type check grows the text in place and
    /// flagged correctly resizing text from run to run: rows of the lazy Load Film Form, scrolled or not
    /// (Evidence/NativeApp/qa13-audit-exceptions-052.md), and later the 16mm Load screen at its top and the empty
    /// Journal (Evidence/NativeApp/scroll-indicator-drag-053.md). `ContentSizeTests` instead measures every text
    /// element on the audited screens at all twelve sizes.
    private static let auditTypes = XCUIAccessibilityAuditType.all.subtracting(.dynamicType)

    private func retainScreenshot(name: String) {
        let attachment = XCTAttachment(image: XCUIScreen.main.uprightScreenshot())
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
