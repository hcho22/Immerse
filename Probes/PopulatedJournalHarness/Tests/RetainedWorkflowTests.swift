import XCTest

@MainActor final class RetainedWorkflowTests: XCTestCase {
    func testEmptyFilmDisablesEarlyDevelopmentAndDeleteRequiresConfirmation() throws {
        let app = launch(["--empty"])
        openFilm(app)
        XCTAssertFalse(app.buttons["Develop Film"].exists)
        app.buttons["Film actions"].tap()
        XCTAssertFalse(app.buttons["Rewind & Develop Early"].isEnabled)
        app.buttons["Delete Film"].tap()
        XCTAssertTrue(app.sheets.buttons.matching(identifier: "confirm-delete-film").firstMatch.waitForExistence(timeout: 5))
        cancelConfirmation(app)
        inspect(app, "empty-delete-cancelled")
        app.buttons["Film actions"].tap()
        app.buttons["Delete Film"].tap()
        app.sheets.buttons.matching(identifier: "confirm-delete-film").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your Journal begins here"].waitForExistence(timeout: 10))
        inspect(app, "empty-deleted")
    }

    func testEarlyWasteCancelAndOriginalExportChoiceSurviveRelaunchWithoutExport() throws {
        let id = UUID()
        let app = launch([], id: id)
        openFilm(app)
        early(app)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "25 exposures")).firstMatch.exists)
        cancelConfirmation(app)
        XCTAssertTrue(app.buttons["Open Camera"].exists)
        XCTAssertFalse(app.buttons["Open photo 1"].exists)
        inspect(app, "early-cancelled")
        early(app)
        app.buttons["Complete Film"].tap()
        XCTAssertTrue(app.navigationBars["Development"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Develop Film"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Open Camera"].exists)
        XCTAssertFalse(app.buttons["Open photo 1"].exists)
        inspect(app, "completed-not-developed")
        app.buttons["Develop Film"].tap()
        app.buttons["Save Originals to Photos after reveal"].tap()
        app.buttons["confirm-original-choice"].tap()
        XCTAssertTrue(app.buttons["Open photo 1"].waitForExistence(timeout: 40))
        XCTAssertTrue(app.buttons["Save Developed to Photos"].exists)
        inspect(app, "developed-export-requested-no-write")
        reopen(app, id: id)
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertFalse(app.buttons["Open Camera"].exists)
        app.buttons["Originals"].tap()
        XCTAssertTrue(app.buttons["Save Originals to Photos"].waitForExistence(timeout: 5))
        // Do not invoke PhotoKit. Choosing originals and executing export are independent.
        app.buttons["Cancel"].tap()
        snapshot(app, "reopened-original-export-still-pending")
    }

    func testInstantRevealsOnePrintWhileNextIsSealedAndPreservesFirstOnResume() throws {
        let id = UUID()
        let app = launch(["--instant-mixed"], id: id)
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertFalse(app.buttons["Open photo 2"].exists)
        XCTAssertTrue(app.staticTexts["Sealed"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Open Camera"].exists)
        snapshot(app, "Instant-first-revealed-second-sealed")
        app.buttons["Resume Development"].tap()
        XCTAssertTrue(app.buttons["Open photo 2"].waitForExistence(timeout: 40))
        XCTAssertTrue(app.buttons["Open Camera"].exists)
        XCTAssertFalse(app.buttons["Develop Film"].exists)
        inspect(app, "Instant-both-revealed-still-open")
        reopen(app, id: id)
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertTrue(app.buttons["Open photo 2"].exists)
        XCTAssertTrue(app.buttons["Open Camera"].exists)
        snapshot(app, "Instant-reopened")
    }

    func testSavedDarkroomEditAndExactResetPersistAcrossRelaunch() throws {
        let id = UUID()
        let app = launch(["--developed-photo"], id: id)
        openFilm(app)
        openDarkroom(app)
        app.sliders["Print exposure"].adjust(toNormalizedSliderPosition: 0.75)
        saveDarkroom(app)
        inspect(app, "edited-first-photo")
        reopen(app, id: id)
        openFilm(app)
        openDarkroom(app)
        XCTAssertFalse(app.staticTexts["0.0 stops"].exists)
        app.buttons["Reset to Original"].tap()
        XCTAssertTrue(app.staticTexts["0.0 stops"].waitForExistence(timeout: 5))
        saveDarkroom(app)
        inspect(app, "reset-first-photo")
        reopen(app, id: id)
        openFilm(app)
        openDarkroom(app)
        XCTAssertTrue(app.staticTexts["0.0 stops"].waitForExistence(timeout: 5))
        snapshot(app, "reset-reopened")
        app.buttons["Cancel"].tap()
        app.buttons["Done"].tap()
    }

    func testDarkroomAccessibleControlsReachNonGestureEditingPaths() throws {
        let id = UUID()
        let app = launch(["--developed-photo"], id: id)
        openFilm(app)
        openDarkroom(app)

        app.buttons["Contrast"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Contrast grade")).firstMatch.waitForExistence(timeout: 5))

        app.buttons["Filtration"].tap()
        let cyan = app.sliders["Cyan"]
        XCTAssertTrue(cyan.waitForExistence(timeout: 5))
        cyan.adjust(toNormalizedSliderPosition: 0.65)
        XCTAssertTrue(app.sliders["Magenta"].exists)
        XCTAssertTrue(app.sliders["Yellow"].exists)

        app.buttons["Crop"].tap()
        let crop = app.switches["Crop"]
        XCTAssertTrue(crop.waitForExistence(timeout: 5))
        crop.tap()
        let size = app.sliders["Crop size"]
        XCTAssertTrue(size.waitForExistence(timeout: 5))
        size.adjust(toNormalizedSliderPosition: 0.6)
        XCTAssertTrue(app.sliders["Crop Horizontal"].exists)
        XCTAssertTrue(app.sliders["Crop Vertical"].exists)
        crop.tap()

        app.buttons["Dodge / Burn"].tap()
        let horizontal = app.sliders["Local exposure horizontal position"]
        XCTAssertTrue(horizontal.waitForExistence(timeout: 5))
        horizontal.adjust(toNormalizedSliderPosition: 0.7)
        let vertical = app.sliders["Local exposure vertical position"]
        XCTAssertTrue(vertical.waitForExistence(timeout: 5))
        vertical.adjust(toNormalizedSliderPosition: 0.35)
        XCTAssertTrue(app.buttons["Dodge point"].waitForExistence(timeout: 5))
        app.buttons["Dodge point"].tap()
        let undo = app.buttons["Undo last stroke"]
        XCTAssertTrue(undo.isEnabled)
        // At the default text size the last row rests in the bottom bar's edge band, where a tap
        // reaches the bar instead. Scroll it clear as a person would, starting on the plain heading
        // so the drag cannot move a slider or paint on the print.
        let bar = app.buttons["Reset to Original"]
        let heading = app.staticTexts["Dodge / Burn"]
        for _ in 0..<4 where undo.frame.maxY > bar.frame.minY - 12 {
            heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -10)))
        }
        XCTAssertLessThan(undo.frame.maxY, bar.frame.minY - 12)
        undo.tap()
        XCTAssertFalse(app.buttons["Undo last stroke"].isEnabled)

        saveDarkroom(app)
        inspect(app, "darkroom-accessible-controls")
    }

    private func launch(_ arguments: [String], id: UUID = UUID()) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["--workflow-run", id.uuidString]
        app.launch()
        ready(app)
        return app
    }

    private func ready(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60), app.debugDescription)
        XCTAssertFalse(app.staticTexts["fixture-failed"].exists)
        XCTAssertTrue(app.buttons["inspect-state"].exists)
    }

    private func reopen(_ app: XCUIApplication, id: UUID) {
        app.terminate()
        app.launchArguments = ["--workflow-run", id.uuidString, "--reopen"]
        app.launch()
        ready(app)
    }

    private func openFilm(_ app: XCUIApplication) {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Private synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
    }

    private func early(_ app: XCUIApplication) {
        app.buttons["Film actions"].tap()
        app.buttons["Rewind & Develop Early"].tap()
        XCTAssertTrue(app.buttons["Complete Film"].waitForExistence(timeout: 5))
    }

    private func cancelConfirmation(_ app: XCUIApplication) {
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else {
            let dismissRegion = app.otherElements["PopoverDismissRegion"]
            XCTAssertTrue(dismissRegion.waitForExistence(timeout: 5))
            dismissRegion.tap()
        }
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.sheets.firstMatch)
        waitForExpectations(timeout: 5)
    }

    private func openDarkroom(_ app: XCUIApplication) {
        let photo = app.buttons["Open photo 1"]
        for _ in 0..<6 where !photo.exists { app.swipeUp() }
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()
        app.buttons["Darkroom"].tap()
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
    }

    private func saveDarkroom(_ app: XCUIApplication) {
        let save = app.buttons["Save"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 20)
        save.tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
    }

    private func inspect(_ app: XCUIApplication, _ name: String) {
        let count = app.staticTexts["inspection-count"]
        let previous = Int(count.label)!
        app.buttons["inspect-state"].tap()
        expectation(for: NSPredicate(format: "label == %@", String(previous + 1)), evaluatedWith: count)
        waitForExpectations(timeout: 20)
        XCTAssertFalse(app.staticTexts["fixture-failed"].exists)
        snapshot(app, name)
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
