import XCTest

/// Movie time reads as minutes and seconds from the catalog to the Journal: the 16mm catalog row and Load screen,
/// then the loaded Film's detail header, capture line and Journal row, with VoiceOver speaking the units. Loading
/// uses the Debug testing unlock and answers a fresh Camera request itself, and each test starts on an empty
/// Journal and deletes the Film it loaded, so it neither depends on nor leaves Camera or Journal state that other
/// tests assume. The populated Journal card is also audited for contrast, since the suite's other audits only see an
/// empty Journal.
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
        // With autocorrection off the title field receives only the typed keys; otherwise the tap that focuses it
        // makes UIKit accept an autocorrection of the suggestion's last word
        // (Evidence/NativeApp/title-autocorrection-058.md).
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
        launchWithEmptyJournal(app)
        app.buttons["start-film"].tap()
        let camera = app.buttons["camera-cinema16mm"]
        scrollUpUntilWhole(app, camera)
        XCTAssertTrue(camera.label.contains("2 minutes 47 seconds of film"), camera.label)
        tapWhole(app, camera)
        XCTAssertTrue(app.staticTexts["Capacity, 2 minutes 47 seconds of film"].waitForExistence(timeout: 5))
        let title = "Capacity check \(UUID().uuidString.prefix(4))"
        guard enterFilmTitle(title, app) else { return }
        let load = app.buttons["load-film"]
        defer { deleteFilm(titled: title, app) }
        tapWhole(app, load)

        // The new Film opens on top of the Journal. The monitor runs only on an interaction made while the
        // request is showing, which can appear late.
        let detail = app.navigationBars[title]
        for _ in 0..<20 {
            if detail.exists { break }
            app.navigationBars.firstMatch.tap()
            _ = detail.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(load.waitForNonExistence(timeout: 5), "The Load screen closed")
        XCTAssertTrue(allowed, "Load Film asks for Camera access")
        XCTAssertTrue(app.staticTexts["2 minutes 47 seconds left"].exists, "Film detail header")

        let open = app.buttons["Open Camera"]
        tapWhole(app, open)
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 minutes 47 seconds left"].exists, "Capture line")
        retainScreenshot(app, name: "Capture-movie-line-\(size ?? "default")")
        done.tap()

        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        goBack(app, from: title, to: "Film Journal")
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        scrollUp(app, until: row)
        XCTAssertTrue(row.label.contains("2 minutes 47 seconds left"), row.label)
        // The contrast audit samples the card at rest. A card passing under the screen's bottom edge fades into the
        // scroll edge effect behind Start a Film, which the audit reads as low contrast; a person scrolls it up to
        // read it, so the audited card ends above that edge and no other Film's card is there
        // (Evidence/NativeApp/ui-test-isolation-064.md).
        XCTAssertEqual(app.buttons.matching(identifier: "journal-film").count, 1, "The Journal holds only this Film")
        XCTAssertLessThanOrEqual(row.frame.maxY, app.buttons["start-film"].frame.minY, "The card ends above Start a Film")
        retainScreenshot(app, name: "Journal-movie-row-\(size ?? "default")")
        try app.performAccessibilityAudit(for: .contrast)
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
