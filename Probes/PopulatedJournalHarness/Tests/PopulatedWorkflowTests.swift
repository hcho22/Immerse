import XCTest

@MainActor
final class PopulatedWorkflowTests: XCTestCase {
    func testEarlyPhotoDevelopmentDarkroomAndRemoval() throws {
        let app = launch()
        openFilm(app)
        XCTAssertEqual(app.buttons.matching(identifier: "Open photo 1").count, 0)
        XCTAssertTrue(app.staticTexts["Sealed"].firstMatch.exists)
        app.buttons["Film actions"].tap()
        app.buttons["Rewind & Develop Early"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "25 exposures")).firstMatch.exists)
        app.buttons["Complete Film"].tap()
        XCTAssertTrue(app.navigationBars["Development"].waitForExistence(timeout: 5))
        app.buttons["Remove originals after verified Development"].tap()
        app.buttons["confirm-original-choice"].tap()
        XCTAssertTrue(app.buttons["Open photo 1"].waitForExistence(timeout: 40))
        snapshot(app, "revealed-photo-Film")
        app.buttons["Open photo 1"].tap()
        app.buttons["Darkroom"].tap()
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 5))
        let exposure = app.sliders["Print exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        exposure.adjust(toNormalizedSliderPosition: 0.65)
        app.buttons["Reset to Original"].tap()
        snapshot(app, "darkroom-reset")
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: save)
        waitForExpectations(timeout: 20)
        save.tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        app.buttons["Discard"].tap()
        let discardConfirmation = app.sheets.buttons.matching(identifier: "confirm-discard-photo").firstMatch
        XCTAssertTrue(discardConfirmation.waitForExistence(timeout: 5))
        discardConfirmation.tap()
        XCTAssertTrue(app.staticTexts["Discarded"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Open photo 1"].exists)
        XCTAssertTrue(app.buttons["Open photo 2"].exists)
        app.buttons["Film actions"].tap()
        app.buttons["Rename"].tap()
        let title = app.alerts.textFields.firstMatch
        // A tap on an already focused field moves the cursor to the nearest word boundary, so place it past the end of the title.
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (title.value as? String)?.count ?? 100))
        // An empty field reports either no text or its placeholder.
        XCTAssertTrue(["", title.placeholderValue].contains(title.value as? String), "The Rename field is empty before typing")
        title.typeText("Renamed synthetic Film")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Renamed synthetic Film"].waitForExistence(timeout: 10))
        app.buttons["Film actions"].tap()
        app.buttons["Archive"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Your Journal begins here"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Renamed synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Renamed synthetic Film"].waitForExistence(timeout: 10))
        app.buttons["Film actions"].tap()
        app.buttons["Restore from Archive"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["No archived Films"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Renamed synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Renamed synthetic Film"].waitForExistence(timeout: 10))
        app.buttons["Film actions"].tap()
        app.buttons["Archive"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Archive"].tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Renamed synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Renamed synthetic Film"].waitForExistence(timeout: 10))
        app.buttons["Film actions"].tap()
        app.buttons["Delete Film"].tap()
        let deleteConfirmation = app.sheets.buttons.matching(identifier: "confirm-delete-film").firstMatch
        XCTAssertTrue(deleteConfirmation.waitForExistence(timeout: 5))
        deleteConfirmation.tap()
        XCTAssertTrue(app.staticTexts["No archived Films"].waitForExistence(timeout: 10))
    }

    func testMovieDiscardKeepsNumberedEmptyFilmWithoutPlaybackExportOrDarkroom() throws {
        let app = launch(arguments: ["--movie", "--hide-inspection-bar"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Save Developed to Photos"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "seconds wasted")).firstMatch.exists)
        XCTAssertFalse(app.buttons["Darkroom"].exists)
        let player = app.descendants(matching: .any)["developed-movie-player"]
        XCTAssertTrue(player.waitForExistence(timeout: 20))
        snapshot(app, "developed-Movie")
        discardClip(1, app: app)
        XCTAssertTrue(app.buttons["discard-clip-2"].waitForExistence(timeout: 40))
        XCTAssertTrue(player.waitForExistence(timeout: 20))
        discardClip(2, app: app)
        XCTAssertFalse(player.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Save Developed to Photos"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "seconds wasted")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Discarded").count, 2)
        XCTAssertTrue(app.staticTexts["01"].exists)
        XCTAssertTrue(app.staticTexts["02"].exists)
        snapshot(app, "empty-Movie-placeholders")
    }

    func testMovieDiscardRetiresObservedPlayerItemBeforeSuccessorPlayback() throws {
        let app = launch(arguments: ["--movie", "--hide-inspection-bar", "--movie-player-observer"])
        openFilm(app)
        let player = app.descendants(matching: .any)["developed-movie-player"]
        XCTAssertTrue(player.waitForExistence(timeout: 20))

        let oldState = app.staticTexts["movie-observer-old-state"]
        let successorState = app.staticTexts["movie-observer-successor-state"]
        let identity = app.staticTexts["movie-observer-identity"]
        XCTAssertTrue(waitForAnyLabel(oldState, ["attached"], timeout: 20), identity.label)
        XCTAssertTrue(waitForAnyLabel(successorState, ["initial-visible"], timeout: 20), identity.label)
        let initialIdentity = identity.label
        snapshot(app, "movie-player-observer-initial")

        discardClip(1, app: app)
        XCTAssertTrue(app.buttons["discard-clip-2"].waitForExistence(timeout: 40))
        XCTAssertTrue(player.waitForExistence(timeout: 20))
        XCTAssertTrue(waitForAnyLabel(oldState, ["released", "detached", "replaced"], timeout: 20), "before: \(initialIdentity) after: \(identity.label)")
        XCTAssertTrue(waitForAnyLabel(successorState, ["successor-visible"], timeout: 20), "before: \(initialIdentity) after: \(identity.label)")
        XCTAssertNotEqual(identity.label, initialIdentity)
        snapshot(app, "movie-player-observer-after-discard")
    }

    func testInstantRevealedPrintsRemainOpenAndHaveNoRollDevelopment() throws {
        let app = launch(arguments: ["--instant"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Open Camera"].exists)
        XCTAssertTrue(app.buttons["Open photo 1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open photo 2"].exists)
        XCTAssertFalse(app.buttons["Develop Film"].exists)
        app.buttons["Film actions"].tap()
        XCTAssertFalse(app.buttons["Rewind & Develop Early"].exists)
        app.tap()
        snapshot(app, "Instant-revealed-pack-open")
    }

    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60))
        return app
    }

    private func openFilm(_ app: XCUIApplication) {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Private synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
    }

    private func discardClip(_ sequence: Int, app: XCUIApplication) {
        let discard = app.buttons["discard-clip-\(sequence)"]
        for _ in 0..<6 where !discard.isHittable { app.swipeUp() }
        XCTAssertTrue(discard.isHittable)
        discard.tap()
        let confirm = app.buttons["Discard #\(sequence)"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: discard)
        waitForExpectations(timeout: 40)
    }

    private func waitForAnyLabel(_ element: XCUIElement, _ labels: Set<String>, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return labels.contains(element.label)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
