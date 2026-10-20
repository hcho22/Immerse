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

/// The base of every screen test class. Each test starts with the simulator held upright. A test stopped at its time
/// allowance runs no `defer` or teardown, so a turn it made stays, and the tests after it launched sideways: one run
/// (39004998658) launched `JournalFlowTests` in landscape for that reason, another harness run (38980604148) failed the
/// test after a timed-out one (Evidence/NativeApp/main-ci-flakes-069.md).
@MainActor
class ScreenTestCase: XCTestCase {
    /// Launches the app once before the class's first test, outside every test's time allowance. XCTest installs the
    /// app at a session's first launch, and on CI that launch took 11 to 48 seconds where later ones took about 5; inside
    /// the session's first test it took the Disposable shooting screen's test past its 3 minutes in run 39292846150
    /// (Evidence/NativeApp/main-ci-flakes-072.md). The session's first tap and first screenshot were slow too (4 to 7 s for
    /// XCTest's check for interrupting elements before the tap, 5 to 25 s for the screenshot, in three runs each, against
    /// under a second for every later one), so they are made here, and what of that is a first use falls outside every
    /// test; a stall of the whole simulator in the same seconds is not shown to move with it
    /// (Evidence/NativeApp/main-ci-flakes-073.md). Nothing is asserted: a warm-up that finds nothing to tap costs nothing.
    override class func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            let app = XCUIApplication()
            app.launch()
            let start = app.buttons["start-film"]
            if start.waitForExistence(timeout: 10) { start.tap() }
            _ = XCUIScreen.main.screenshot()
            app.terminate()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        XCUIDevice.shared.orientation = .portrait
    }
}

extension XCUIElement {
    /// Flips a switch with a press held for 1 s, where `tap()` holds for 66 ms. When the simulator's touch service is
    /// late to register the touchscreen XCTest attaches for a tap, as on a slow runner, the finger-down and the finger-up
    /// reach the app a few milliseconds apart, and a switch ignores that touch while a button still fires:
    /// `Evidence/NativeApp/main-ci-flakes-069.md` has the log of the lost tap and its reproduction. A press held longer
    /// than the lag, which reached 628 ms once on CI, still has its finger-up after its finger-down. This is one press,
    /// never a second tap.
    func flipSwitch() {
        press(forDuration: 1)
    }

    /// Whether the element exists within `timeout`. One that is already there answers at once, where
    /// `waitForExistence(timeout:)` returns no sooner than about a second after it is called even then (1.04 s at the
    /// median over the 387 calls of one CI run, 1.1 s here). The shooting screen's tests make 40 such calls each, which
    /// were 45 of the Disposable test's 89 seconds here and 50 of its 127 on CI (Evidence/NativeApp/main-ci-flakes-073.md).
    /// One that is not there yet is waited for as before, for the same `timeout`. That second also let a screen finish
    /// coming up, so use this only where the next step is a tap, which waits for the app to be idle by itself, or a read
    /// that settles by itself (`wait(_:until:)` in `CaptureSidewaysUITests`), and not where it reads a frame at once.
    func exists(within timeout: TimeInterval) -> Bool {
        exists || waitForExistence(timeout: timeout)
    }

    /// Whether the element is gone within `timeout`, with the same quick answer and the same caution as `exists(within:)`.
    func isGone(within timeout: TimeInterval) -> Bool {
        !exists || waitForNonExistence(timeout: timeout)
    }
}

@MainActor
extension XCTestCase {
    /// Scrolls up in equal, slow drags that end held, so the list never coasts, until `element` can be tapped.
    /// Free swipes coasted a different distance each run, which changed the rows under the bars at each audit
    /// (Evidence/NativeApp/qa13-audit-exceptions-052.md). The drag runs in the left margin, outside the rows' controls
    /// and away from the scroll indicator, which a right-edge drag can grab and scrub the list back toward its start
    /// (Evidence/NativeApp/scroll-indicator-drag-053.md).
    /// A lazy list has not made a row far below yet, and `isHittable` on a missing element looks for it twice more,
    /// about 2.3 seconds a drag on this Intel Mac, so `exists` answers first (Evidence/NativeApp/ui-test-isolation-064.md).
    func scrollUp(_ app: XCUIApplication, until element: XCUIElement) {
        scrollUp(app) { element.exists && element.isHittable }
    }

    /// Scrolls up in the same held drags, `distance` points each, until `done` holds. It stops asking once `done`
    /// holds: a `where` clause skips the drag but goes on through every remaining pass, and each pass asked again,
    /// about 5 seconds a scroll at the largest text size on this Intel Mac (Evidence/NativeApp/ui-test-isolation-064.md).
    /// With a keyboard raised, a drag starts just above it instead, since one that starts on the keyboard types.
    @nonobjc func scrollUp(_ app: XCUIApplication, by distance: CGFloat = 300, until done: () -> Bool) {
        for _ in 0..<16 {
            if done() { return }
            let height = app.frame.height
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: min(0.7, (wholeBottom(app) - 24) / height)))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    /// The lowest an element's bottom edge can be and the whole element still be clear on screen: 40 points above the
    /// window's bottom edge, clear of the home indicator (4 on an iPhone with a home button, which has none), or with a
    /// keyboard raised, 15 points above the keyboard. On
    /// iOS 26.5 the keyboard's panel is drawn 45 points above the frame its element reports (from y 538, against 583,
    /// on an iPhone 17 Pro), and a drag that starts on the panel goes to the keyboard.
    private func wholeBottom(_ app: XCUIApplication) -> CGFloat {
        let window = app.windows.firstMatch.frame
        let keyboard = app.keyboards.firstMatch
        // An iPhone with a home button has no home indicator to keep clear of, and its Load Film command never rests
        // 40 points above the bottom edge. Its screen is at most 667 points long, in either orientation.
        let indicator: CGFloat = max(window.width, window.height) > 700 ? 40 : 4
        return keyboard.exists ? min(window.maxY - indicator, keyboard.frame.minY - 60) : window.maxY - indicator
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
    /// tap did nothing (Evidence/NativeApp/main-ci-flakes-066.md).
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
    /// would hide that, so a miss fails here, with a screenshot of what was showing. The wait is 30 seconds, not 5: on a
    /// runner that stalled, the simulator handed the app the finger 15.7 s after XCTest played it, and the sheet came right
    /// after (run 39307626086, Evidence/NativeApp/main-ci-flakes-073.md); 30 s covers the longest single stall read on CI.
    /// A tap that never arrives still fails, 25 s later.
    func openCameraCatalog(_ app: XCUIApplication) {
        let start = app.buttons["start-film"]
        let catalog = app.navigationBars["Choose a Camera"]
        XCTAssertTrue(start.exists(within: 10))
        start.tap()
        if catalog.waitForExistence(timeout: 30) { return }
        let miss = XCTAttachment(screenshot: app.screenshot())
        miss.name = "Start-a-Film-tap-did-not-open-the-catalog"
        miss.lifetime = .keepAlways
        add(miss)
        XCTFail("The Camera catalog did not open within 30 seconds of the tap on Start a Film")
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
        XCTAssertTrue(app.buttons["start-film"].exists(within: 10))
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        guard row.waitForExistence(timeout: 5) else { return }
        deleteFilm(at: row, app)
        XCTAssertTrue(row.isGone(within: 10))
    }

    /// Launches the app on an empty Journal, deleting every Film an earlier test left. A test deletes the Films it
    /// loaded in a `defer`, which never runs when the test is stopped at its time allowance: the runner is ended
    /// mid-test, and on 2026-10-14 the Disposable Film of a Low Storage test stopped that way sat in the Journal of
    /// the Movie capacity test that ran next and failed its audit (Evidence/NativeApp/ui-test-isolation-064.md). So
    /// every test that loads a Film or reads the Journal starts here. Each leftover Film is kept as a screenshot
    /// before it is deleted, so the earlier test's failure stays visible.
    func launchWithEmptyJournal(_ app: XCUIApplication) {
        app.launch()
        let start = app.buttons["start-film"]
        XCTAssertTrue(start.exists(within: 10))
        // Start a Film stays disabled until launch recovery ends.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: start)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 10), .completed, "Start a Film stayed disabled")
        let rows = app.buttons.matching(identifier: "journal-film")
        for _ in 0..<10 {
            if rows.count == 0 { break }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Film-left-by-an-earlier-test"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            deleteFilm(at: rows.firstMatch, app)
        }
        XCTAssertTrue(app.staticTexts["Your Journal begins here"].exists(within: 10), "The Journal is empty")
    }

    /// Opens the Journal row `row` and deletes its Film, returning once the Film screen has closed and the Journal
    /// shows again. Delete Film removes the Film, which leaves the Film screen showing "Film removed" without its
    /// actions, and then closes the screen, which stays in the tree until its pop ends. So the actions leaving shows
    /// the Film was removed, and "Film removed" leaving shows the Journal is at rest to count, audit or measure.
    private func deleteFilm(at row: XCUIElement, _ app: XCUIApplication) {
        tapWhole(app, row)
        // The Film screen's actions, rather than its bar, which reads a 6×6 title as "6 by 6".
        XCTAssertTrue(app.buttons["Film actions"].exists(within: 5))
        app.buttons["Film actions"].tap()
        app.buttons["Delete Film"].tap()
        let confirm = app.sheets.buttons.matching(identifier: "confirm-delete-film").firstMatch
        XCTAssertTrue(confirm.exists(within: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["Film actions"].isGone(within: 10), "The Film was removed")
        XCTAssertTrue(app.staticTexts["Film removed"].isGone(within: 10), "The Film screen closed")
        XCTAssertTrue(app.buttons["start-film"].exists(within: 10), "The Journal shows")
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
