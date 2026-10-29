import XCTest

/// The low-storage warning on the Film screen (DEC-12), on a synthetic Film with saved captures, which the app's own
/// screen tests cannot make: above Open Camera while the Film is open, above Develop Film once it is complete, and
/// gone once it is developed. A launch argument sets the free-space reading: just under 2 GB (1,999,999,999 bytes)
/// shows the warning, and exactly 2 GB, just over, and a reading that fails show none. No disk is filled, so this is
/// not evidence of what a nearly full iPhone does. Like the harness's other tests these are functional; the
/// warning's accessibility audits run in the app's own `LowStorageUITests`.
@MainActor final class LowStorageWorkflowTests: HarnessTestCase {
    private static let captureWarning = "This iPhone has less than 2 GB free, so a capture may not save. A capture that does not save uses no exposures or time, and saved captures are unchanged. Free space in iPhone Settings."
    private static let developmentWarning = "This iPhone has less than 2 GB free, so Development may not finish. Saved captures are unchanged, and Development can be resumed. Free space in iPhone Settings."

    func testFilmScreenWarnsBeforeOpenCameraThenBeforeDevelopFilmJustUnderTwoGigabytes() throws {
        let app = launch(freeSpace: "1999999999")
        openFilm(app)
        let warning = app.staticTexts["low-storage-warning"]
        let open = app.buttons["Open Camera"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertEqual(warning.label, Self.captureWarning)
        XCTAssertTrue(warning.isHittable, "The warning is visible without scrolling")
        XCTAssertTrue(open.isHittable)
        XCTAssertTrue(open.isEnabled, "The warning stops nothing")
        XCTAssertLessThanOrEqual(warning.frame.maxY, open.frame.minY, "The warning comes before Open Camera")
        snapshot(app, "film-low-storage-open")

        completeEarly(app)
        let develop = app.buttons["Develop Film"]
        XCTAssertEqual(warning.label, Self.developmentWarning)
        XCTAssertTrue(warning.isHittable, "The warning is visible without scrolling")
        XCTAssertTrue(develop.isHittable)
        XCTAssertTrue(develop.isEnabled, "The warning stops nothing")
        XCTAssertLessThanOrEqual(warning.frame.maxY, develop.frame.minY, "The warning comes before Develop Film")
        snapshot(app, "film-low-storage-ready-to-develop")

        // Development still runs, and the developed Film, which needs no more space, carries no warning.
        develop.tap()
        app.buttons["Remove originals after verified Development"].tap()
        app.buttons["confirm-original-choice"].tap()
        XCTAssertTrue(app.buttons["Open photo 1"].waitForExistence(timeout: 40), "Development runs while the warning shows")
        XCTAssertFalse(warning.exists, "A developed Film carries no warning")
        snapshot(app, "film-low-storage-developed")
    }

    func testFilmScreenShowsNoWarningAtExactlyTwoGigabytes() throws { assertNoWarning(freeSpace: "2000000000") }
    func testFilmScreenShowsNoWarningJustOverTwoGigabytes() throws { assertNoWarning(freeSpace: "2000000001") }
    func testFilmScreenShowsNoWarningWhenTheReadingFails() throws { assertNoWarning(freeSpace: "unreadable") }

    /// At the largest text size the warning pushes the command below the first screen; it is reached by scrolling,
    /// and the warning stays inside the screen's width.
    func testFilmScreenWarningsAtTheLargestTextSizeHideNoControl() throws {
        let app = launch(freeSpace: "1999999999", size: "UICTContentSizeCategoryAccessibilityXXXL")
        let window = app.windows.firstMatch.frame
        openFilm(app)
        let warning = app.staticTexts["low-storage-warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertEqual(warning.label, Self.captureWarning)
        XCTAssertTrue(warning.frame.minX >= window.minX && warning.frame.maxX <= window.maxX, "The warning fits the width")
        snapshot(app, "film-low-storage-open-accessibility-largest")
        let open = app.buttons["Open Camera"]
        reveal(open, in: app)
        XCTAssertTrue(open.isEnabled)
        XCTAssertLessThanOrEqual(warning.frame.maxY, open.frame.minY, "The warning comes before Open Camera")
        snapshot(app, "film-low-storage-open-command-accessibility-largest")

        completeEarly(app)
        XCTAssertEqual(warning.label, Self.developmentWarning)
        XCTAssertTrue(warning.frame.minX >= window.minX && warning.frame.maxX <= window.maxX, "The warning fits the width")
        let develop = app.buttons["Develop Film"]
        reveal(develop, in: app)
        XCTAssertTrue(develop.isEnabled)
        XCTAssertLessThanOrEqual(warning.frame.maxY, develop.frame.minY, "The warning comes before Develop Film")
        snapshot(app, "film-low-storage-ready-to-develop-accessibility-largest")
    }

    private func assertNoWarning(freeSpace: String) {
        let app = launch(freeSpace: freeSpace)
        openFilm(app)
        XCTAssertTrue(app.buttons["Open Camera"].isHittable)
        XCTAssertFalse(app.staticTexts["low-storage-warning"].exists, "No warning before Open Camera with \(freeSpace) free")
        completeEarly(app)
        XCTAssertTrue(app.buttons["Develop Film"].isHittable)
        XCTAssertFalse(app.staticTexts["low-storage-warning"].exists, "No warning before Develop Film with \(freeSpace) free")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "2 GB")).firstMatch.exists)
    }

    private func launch(freeSpace: String, size: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--hide-inspection-bar", "-ImmerseDebugFreeSpace", freeSpace]
        if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60))
        XCTAssertFalse(app.staticTexts["fixture-failed"].exists)
        return app
    }

    private func openFilm(_ app: XCUIApplication) {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Private synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
    }

    /// Completes the open Film early and leaves the Development sheet, so the Film screen offers Develop Film.
    private func completeEarly(_ app: XCUIApplication) {
        app.buttons["Film actions"].tap()
        app.buttons["Finish & Develop Early"].tap()
        XCTAssertTrue(app.buttons["Complete Film"].waitForExistence(timeout: 5))
        app.buttons["Complete Film"].tap()
        XCTAssertTrue(app.navigationBars["Development"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Develop Film"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
