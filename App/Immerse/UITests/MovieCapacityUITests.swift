import XCTest

/// A loaded Movie Film's Journal row shows its remaining capacity the way the Load screen shows it,
/// as minutes and seconds, and VoiceOver speaks the units. Loading uses the Debug testing unlock.
@MainActor
final class MovieCapacityUITests: XCTestCase {
    func testJournalRowShowsRemainingMovieCapacityAsMinutesAndSeconds() throws {
        try checkJournalRow(size: nil)
    }

    func testJournalRowShowsRemainingMovieCapacityAtLargestText() throws {
        try checkJournalRow(size: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    private func checkJournalRow(size: String?) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImmerseDebugTestingUnlock", "YES"]
        if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        let camera = app.buttons["camera-cinema16mm"]
        for _ in 0..<5 where !camera.isHittable { app.swipeUp() }
        camera.tap()
        XCTAssertTrue(app.staticTexts["Capacity, 2:45 of film"].waitForExistence(timeout: 5))
        let title = "Capacity check \(UUID().uuidString.prefix(4))"
        let field = app.textFields["film-title"]
        for _ in 0..<8 where !field.isHittable { app.swipeUp() }
        field.tap()
        // The field starts with the suggested title; replace it.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + title)
        let load = app.buttons["load-film"]
        for _ in 0..<8 where !load.isHittable { app.swipeUp() }
        load.tap()

        // A new Film opens on top of the Journal; going back shows its row.
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        for _ in 0..<5 where !row.waitForExistence(timeout: 2) {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(row.exists)
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.label.contains("2 minutes 45 seconds left"), row.label)
        XCTAssertFalse(row.label.contains(".000"), row.label)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Journal-movie-row-\(size ?? "default")"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
