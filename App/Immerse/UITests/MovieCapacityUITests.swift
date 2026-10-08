import XCTest

/// Movie time reads as minutes and seconds from the catalog to the Journal: the 16mm catalog row and Load screen,
/// then the loaded Film's detail header, capture line and Journal row, with VoiceOver speaking the units. Loading
/// uses the Debug testing unlock and answers a fresh Camera request itself, and each test deletes the Film it
/// loaded, so it neither depends on nor leaves Camera or Journal state that other tests assume. The populated
/// Journal card is also audited for contrast, since the suite's other audits only see an empty Journal.
@MainActor
final class MovieCapacityUITests: XCTestCase {
    func testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal() throws {
        try check(size: nil)
    }

    func testMovieTimeReadsAsMinutesAndSecondsAtLargestText() throws {
        try check(size: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    private func check(size: String?) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImmerseDebugTestingUnlock", "YES"]
        // The tap that focuses the title field makes UIKit accept an autocorrection of the suggestion's last word, and
        // on CI it once landed among the typed deletes and put "01" back, in a run no slower than passing ones; what
        // timing let it is not established (Evidence/NativeApp/title-autocorrection-058.md).
        app.launchArguments += ["-KeyboardAutocorrection", "NO"]
        if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
        // An earlier test can leave Camera declined, so Load Film asks afresh and a person allows it.
        app.resetAuthorizationStatus(for: .camera)
        var allowed = false
        let monitor = addUIInterruptionMonitor(withDescription: "Camera access request") { alert in
            let allow = alert.buttons["Allow"]
            guard alert.label.localizedCaseInsensitiveContains("Camera"), allow.exists else { return false }
            allow.tap()
            allowed = true
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        let camera = app.buttons["camera-cinema16mm"]
        for _ in 0..<5 where !camera.isHittable { app.swipeUp() }
        XCTAssertTrue(camera.label.contains("2 minutes 47 seconds of film"), camera.label)
        camera.tap()
        XCTAssertTrue(app.staticTexts["Capacity, 2 minutes 47 seconds of film"].waitForExistence(timeout: 5))
        let title = "Capacity check \(UUID().uuidString.prefix(4))"
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
            return XCTFail("The title field holds \"\(field.value as? String ?? "")\" instead of \"\(title)\"")
        }
        let load = app.buttons["load-film"]
        for _ in 0..<8 where !load.isHittable { app.swipeUp() }
        defer { deleteFilm(titled: title, app) }
        load.tap()

        // The new Film opens on top of the Journal. The monitor runs only on an interaction made while the
        // request is showing, which can appear late.
        let detail = app.navigationBars[title]
        for _ in 0..<20 where !detail.exists {
            app.navigationBars.firstMatch.tap()
            _ = detail.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(allowed, "Load Film asks for Camera access")
        XCTAssertTrue(app.staticTexts["2 minutes 47 seconds left"].exists, "Film detail header")

        let open = app.buttons["Open Camera"]
        for _ in 0..<5 where !open.isHittable { app.swipeUp() }
        open.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 minutes 47 seconds left"].exists, "Capture line")
        retainScreenshot(app, name: "Capture-movie-line-\(size ?? "default")")
        done.tap()

        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        detail.buttons.element(boundBy: 0).tap()
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        scrollUp(app, until: row)
        XCTAssertTrue(row.label.contains("2 minutes 47 seconds left"), row.label)
        retainScreenshot(app, name: "Journal-movie-row-\(size ?? "default")")
        try app.performAccessibilityAudit(for: .contrast)
    }

    /// Deletes the Film a test loaded from a fresh launch, whatever screen the test stopped on.
    private func deleteFilm(titled title: String, _ app: XCUIApplication) {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        guard row.waitForExistence(timeout: 5) else { return }
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
        app.buttons["Film actions"].tap()
        app.buttons["Delete Film"].tap()
        let confirm = app.sheets.buttons.matching(identifier: "confirm-delete-film").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 10))
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
