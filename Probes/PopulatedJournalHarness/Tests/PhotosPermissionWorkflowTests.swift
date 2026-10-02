import XCTest

/// Requires host-side simulator state before launch:
/// `xcrun simctl privacy $SIM revoke photos-add com.immerse.PopulatedJournalHarness`.
/// The harness has no Photos usage key, so each test confirms the denied status in
/// Settings before touching an export control and can never reach a system prompt.
@MainActor final class PhotosPermissionWorkflowTests: XCTestCase {
    func testDeniedAddOnlyPhotosExportIsNeverSuccessAndPointsToSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--hide-inspection-bar"]
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60))
        try requireDeniedPhotosAccess(app)

        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Private synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
        app.buttons["Film actions"].tap()
        app.buttons["Rewind & Develop Early"].tap()
        app.buttons["Complete Film"].tap()
        XCTAssertTrue(app.navigationBars["Development"].waitForExistence(timeout: 10))
        reveal(app.buttons["Save Originals to Photos after reveal"], in: app).tap()
        reveal(app.buttons["confirm-original-choice"], in: app).tap()
        XCTAssertTrue(app.staticTexts["Developed"].waitForExistence(timeout: 40))

        reveal(app.buttons["Save Developed to Photos"], in: app).tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        snapshot(app, "developed-export-photos-denied")
        XCTAssertFalse(app.alerts["Saved to Photos"].exists)
        assertPhotosAccessGuidance(alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " "))
        alert.buttons["OK"].tap()

        reveal(app.buttons["Originals"], in: app).tap()
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        let saveOriginals = reveal(app.buttons["Save Originals to Photos"], in: app)
        saveOriginals.tap()
        let failure = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@",
                                                               "Photos access is off", "error")).firstMatch
        XCTAssertTrue(reveal(failure, in: app, timeout: 20).exists)
        snapshot(app, "original-export-photos-denied")
        XCTAssertFalse(app.alerts["Saved to Photos"].exists)
        XCTAssertTrue(reveal(saveOriginals, in: app).exists, "Denied export must leave the original export pending")
        assertPhotosAccessGuidance(app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " "))
    }

    private func requireDeniedPhotosAccess(_ app: XCUIApplication) throws {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        // Form rows combine the label and value into one accessibility element.
        let photos = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Photos (add only), ")).firstMatch
        for _ in 0..<6 where !photos.isHittable { app.swipeUp() }
        snapshot(app, "settings-privacy-status")
        guard photos.exists, photos.label == "Photos (add only), Off" else {
            XCTFail("Revoke photos-add for com.immerse.PopulatedJournalHarness before launch; never prompt without a usage key")
            throw XCTSkip("Photos add-only access is not denied")
        }
        app.navigationBars["Settings"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 5))
    }

    /// Accessibility text sizes push Form rows below the fold, where they are not yet in the hierarchy.
    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement {
        _ = element.waitForExistence(timeout: timeout)
        for _ in 0..<10 where !(element.exists && element.isHittable) { app.swipeUp() }
        XCTAssertTrue(element.isHittable, "\(element) never became hittable")
        return element
    }

    private func assertPhotosAccessGuidance(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(text.contains("Photos access is off"), text, file: file, line: line)
        XCTAssertTrue(text.contains("iPhone Settings"), text, file: file, line: line)
        XCTAssertFalse(text.contains("storage"), text, file: file, line: line)
        XCTAssertFalse(text.contains("error"), text, file: file, line: line)
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
