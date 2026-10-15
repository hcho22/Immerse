import XCTest

extension XCUIScreen {
    /// The screen as it appears, in either orientation. In landscape, `XCUIApplication.screenshot()` turned the image
    /// sideways a second time and cropped it, and the screen's own capture keeps the display's portrait pixels with an
    /// orientation flag that attachments and `cgImage` drop, so the capture is redrawn upright
    /// (Evidence/NativeApp/scroll-indicator-drag-053.md).
    func uprightScreenshot() -> UIImage {
        let screen = screenshot().image
        let format = UIGraphicsImageRendererFormat()
        format.scale = screen.scale
        return UIGraphicsImageRenderer(size: screen.size, format: format).image { _ in screen.draw(at: .zero) }
    }
}

@MainActor
extension XCTestCase {
    /// Scrolls up in equal, slow drags that end held, so the list never coasts, until `element` can be tapped.
    /// Free swipes coasted a different distance each run, which changed the rows under the bars at each audit
    /// (Evidence/NativeApp/qa13-audit-exceptions-052.md). The drag runs in the left margin, outside the rows' controls
    /// and away from the scroll indicator, which a right-edge drag can grab and scrub the list back toward its start
    /// (Evidence/NativeApp/scroll-indicator-drag-053.md).
    func scrollUp(_ app: XCUIApplication, until element: XCUIElement) {
        scrollUp(app) { element.isHittable }
    }

    /// Scrolls up in the same held drags, `distance` points each, until `done` holds. With a keyboard raised, a drag
    /// starts just above it instead, since one that starts on the keyboard types.
    @nonobjc func scrollUp(_ app: XCUIApplication, by distance: CGFloat = 300, until done: () -> Bool) {
        for _ in 0..<16 where !done() {
            let height = app.frame.height
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: min(0.7, (wholeBottom(app) - 24) / height)))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    /// The lowest an element's bottom edge can be and the whole element still be clear on screen: 40 points above the
    /// window's bottom edge, clear of the home indicator, or with a keyboard raised, 15 points above the keyboard. On
    /// iOS 26.5 the keyboard's panel is drawn 45 points above the frame its element reports (from y 538, against 583,
    /// on an iPhone 17 Pro), and a drag that starts on the panel goes to the keyboard.
    private func wholeBottom(_ app: XCUIApplication) -> CGFloat {
        let window = app.windows.firstMatch.frame
        let keyboard = app.keyboards.firstMatch
        return keyboard.exists ? min(window.maxY - 40, keyboard.frame.minY - 60) : window.maxY - 40
    }

    /// Scrolls until the whole element, not just its center, is on screen with room below it, finishing in short drags.
    /// A heading that stops at the screen's bottom edge is half hidden by the home indicator's edge effect, which the
    /// contrast audit flags in dark; a full-size drag past it would instead push the Camera's description rows under the
    /// navigation bar, where the audit flags them too.
    func scrollUpUntilWhole(_ app: XCUIApplication, _ element: XCUIElement) {
        scrollUp(app, until: element)
        scrollUp(app, by: 100) { element.frame.maxY <= wholeBottom(app) }
    }

    /// Taps `element` once the whole of it is on screen, above the home indicator and any keyboard. `isHittable` holds
    /// while only a sliver of an element shows, and XCTest taps the middle of what shows: one CI run (38483188498) tapped
    /// the 16mm row at y 865.7 of 874, the top 17 points of a 168-point row, inside the home indicator's area, and the
    /// tap did nothing (Evidence/NativeApp/main-ci-flakes-063.md).
    func tapWhole(_ app: XCUIApplication, _ element: XCUIElement) {
        scrollUpUntilWhole(app, element)
        XCTAssertLessThanOrEqual(element.frame.maxY, wholeBottom(app), "\(element) is whole on screen before the tap")
        element.tap()
    }

    /// Taps Back on the pushed screen whose bar is titled `title`, then waits until that bar has left the tree and the
    /// `previous` screen's bar shows. The tap can return before the pop ends: one CI run (37788441803) then found the
    /// Load screen still in the tree and no Cancel button on the catalog. A dropped tap fails here rather than at the
    /// next step.
    func goBack(_ app: XCUIApplication, from title: String, to previous: String) {
        let bar = app.navigationBars[title]
        bar.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5), "\(title) still showed 5 seconds after Back")
        XCTAssertTrue(app.navigationBars[previous].waitForExistence(timeout: 5), "\(previous) did not show after Back")
    }

    /// Taps Start a Film once and waits for the Camera catalog sheet. One CI run (main, run 37627486582) delivered a tap
    /// at the button's centre, (201, 822), where every passing launch did, and the Journal stayed on screen for the
    /// next six seconds with no sheet; no repeat reproduced it (Evidence/NativeApp/ci-flakes-057.md). A second tap
    /// would hide that, so a miss fails here, with a screenshot of what was showing.
    func openCameraCatalog(_ app: XCUIApplication) {
        let start = app.buttons["start-film"]
        let catalog = app.navigationBars["Choose a Camera"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        if catalog.waitForExistence(timeout: 5) { return }
        let miss = XCTAttachment(screenshot: app.screenshot())
        miss.name = "Start-a-Film-tap-did-not-open-the-catalog"
        miss.lifetime = .keepAlways
        add(miss)
        XCTFail("The Camera catalog did not open within 5 seconds of the tap on Start a Film")
    }

    /// Replaces the Load screen's suggested Film title with `title`, failing the test and returning false if the typed
    /// title does not land in the field.
    @discardableResult func enterFilmTitle(_ title: String, _ app: XCUIApplication) -> Bool {
        let field = app.textFields["film-title"]
        // The field starts with the suggested title, which wraps at the largest sizes. A tap puts the cursor where it
        // lands, so tap past the end of the last line before deleting the suggestion. That point is on screen only
        // once the whole field is: a free swipe that coasted short left the field's center hittable but its last line
        // under the window's bottom edge, and the tap there gave the field no focus.
        // The Form adds and removes the field's row as it nears the screen, so the field can exist and be gone a moment
        // later, and reading a missing element's frame fails the test; one snapshot reads both and throws instead.
        let window = app.windows.firstMatch.frame
        let onScreen = { (try? field.snapshot()).map { window.contains($0.frame) } ?? false }
        scrollUp(app, until: onScreen)
        XCTAssertTrue(onScreen(), "The whole title field is on screen")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.9)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String)?.count ?? 100) + title)
        // Typed edits reach the field from the out-of-process keyboard after typeText returns, so wait for them to land.
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: field)
        guard XCTWaiter().wait(for: [entered], timeout: 10) == .completed else {
            XCTFail("The title field holds \"\(field.value as? String ?? "")\" instead of \"\(title)\"")
            return false
        }
        return true
    }

    /// Deletes the Film a test loaded from a fresh launch, whatever screen the test stopped on.
    func deleteFilm(titled title: String, _ app: XCUIApplication) {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        guard row.waitForExistence(timeout: 5) else { return }
        tapWhole(app, row)
        // The Film screen's actions, rather than its bar, which reads a 6×6 title as "6 by 6".
        XCTAssertTrue(app.buttons["Film actions"].waitForExistence(timeout: 5))
        app.buttons["Film actions"].tap()
        app.buttons["Delete Film"].tap()
        let confirm = app.sheets.buttons.matching(identifier: "confirm-delete-film").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 10))
    }

    /// Audits the screen, failing on every finding except the exact entries in `exceptions`, and returns
    /// the labels of the findings it reported.
    @discardableResult
    func audit(_ app: XCUIApplication, name: String, for types: XCUIAccessibilityAuditType = .all,
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
