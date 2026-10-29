import XCTest

@MainActor final class RetainedWorkflowTests: HarnessTestCase {
    func testEmptyFilmDisablesEarlyDevelopmentAndDeleteRequiresConfirmation() throws {
        let app = launch(["--empty"])
        openFilm(app)
        XCTAssertFalse(app.buttons["Develop Film"].exists)
        app.buttons["Film actions"].tap()
        XCTAssertFalse(app.buttons["Finish & Develop Early"].isEnabled)
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
        // DEV-12: the pack is not full, so development reveals the print without asking about its original.
        XCTAssertTrue(app.buttons["Open photo 2"].waitForExistence(timeout: 40))
        XCTAssertFalse(app.navigationBars["Originals"].exists)
        XCTAssertTrue(app.buttons["Originals"].exists, "Originals can still be decided from the Film screen")
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

    func testDarkroomAccessibleControlsReachAdjustmentPaths() throws {
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

        app.buttons["Adjust"].tap()
        let crop = app.switches["Crop"]
        XCTAssertTrue(crop.waitForExistence(timeout: 5))
        crop.flipSwitch()
        let size = app.sliders["Crop size"]
        XCTAssertTrue(size.waitForExistence(timeout: 5))
        size.adjust(toNormalizedSliderPosition: 0.6)
        XCTAssertTrue(app.sliders["Crop Horizontal"].exists)
        XCTAssertTrue(app.sliders["Crop Vertical"].exists)
        // At the default text size each caption sits beside its slider, the captions in one column and the sliders in
        // the next.
        for caption in ["Crop", "Size", "Horizontal", "Vertical"] {
            XCTAssertEqual(app.staticTexts[caption].frame.minX, app.staticTexts["Size"].frame.minX, accuracy: 1, caption)
            XCTAssertLessThan(app.staticTexts[caption].frame.maxX, size.frame.minX, caption)
        }
        for slider in ["Straighten", "Crop Horizontal", "Crop Vertical"] {
            XCTAssertEqual(app.sliders[slider].frame.minX, size.frame.minX, accuracy: 1, slider)
        }
        snapshot(app, "darkroom-crop-captions")
        crop.flipSwitch()

        XCTAssertFalse(app.buttons["Dodge / Burn"].exists)
        XCTAssertFalse(app.buttons["Dodge point"].exists)
        XCTAssertFalse(app.buttons["Undo last stroke"].exists)

        saveDarkroom(app)
        inspect(app, "darkroom-accessible-controls")
    }

    func testDarkroomShowsAdjustSaturationAndVignetteControlsOnColorPrints() throws {
        let app = launch(["--developed-photo"], id: UUID())
        openFilm(app)
        openDarkroom(app)

        app.buttons["Adjust"].tap()
        XCTAssertTrue(app.buttons["darkroom-rotate-left"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["darkroom-rotate-right"].exists)
        let straighten = app.sliders["Straighten"]
        XCTAssertTrue(straighten.exists)
        XCTAssertEqual(straighten.value as? String, "0.0 degrees")
        tapWhole(app, straighten)
        straighten.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .dragThumb(to: straighten.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)))
        XCTAssertEqual(straighten.value as? String, "-45.0 degrees")
        straighten.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .dragThumb(to: straighten.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)))
        XCTAssertEqual(straighten.value as? String, "45.0 degrees")

        app.buttons["Saturation"].tap()
        let saturation = app.sliders["Saturation"]
        XCTAssertTrue(saturation.waitForExistence(timeout: 5))
        XCTAssertEqual(saturation.value as? String, "0")
        tapWhole(app, saturation)
        saturation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .dragThumb(to: saturation.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)))
        XCTAssertEqual(saturation.value as? String, "-50")
        saturation.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .dragThumb(to: saturation.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)))
        XCTAssertEqual(saturation.value as? String, "50")

        app.buttons["Vignette"].tap()
        let vignette = app.sliders["Vignette"]
        XCTAssertTrue(vignette.waitForExistence(timeout: 5))
        XCTAssertEqual(vignette.value as? String, "0 stops")
        tapWhole(app, vignette)
        vignette.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .dragThumb(to: vignette.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)))
        XCTAssertEqual(vignette.value as? String, "minus 2 stops")
        snapshot(app, "darkroom-vignette-minus-2-stops")
        vignette.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .dragThumb(to: vignette.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)))
        XCTAssertEqual(vignette.value as? String, "plus 2 stops")
        snapshot(app, "darkroom-vignette-plus-2-stops")
    }

    func testBlackAndWhiteDarkroomHidesColorControlsButKeepsVignette() throws {
        let app = launch(["--medium-format", "--black-and-white"], id: UUID())
        openFilm(app)
        openDarkroom(app)
        XCTAssertFalse(app.buttons["Filtration"].exists)
        XCTAssertFalse(app.buttons["Saturation"].exists)
        XCTAssertTrue(app.buttons["Vignette"].exists)
    }

    func testLegacyDodgeStrokeStillPrintsAndResetClearsItAcrossRelaunch() throws {
        let id = UUID()
        let app = launch(["--developed-photo", "--recipe-with-strokes"], id: id)
        openFilm(app)
        openDarkroom(app)
        XCTAssertFalse(app.buttons["Dodge / Burn"].exists)
        XCTAssertFalse(app.buttons["Dodge point"].exists)
        XCTAssertFalse(app.buttons["Burn point"].exists)
        XCTAssertFalse(app.buttons["Undo last stroke"].exists)
        let legacyNote = app.staticTexts["darkroom-legacy-strokes-note"]
        XCTAssertEqual(legacyNote.label,
                       "This print keeps its earlier Dodge/Burn strokes until Reset to Original.")
        snapshot(app, "legacy-stroke-notice")
        let print = app.images["Photo 1, print preview"]
        XCTAssertTrue(print.waitForExistence(timeout: 10))
        let legacyStrokePrint = print.screenshot().pngRepresentation
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
        inspect(app, "legacy-stroke-still-prints")

        openDarkroom(app)
        let printAfterReopeningDarkroom = app.images["Photo 1, print preview"]
        XCTAssertTrue(printAfterReopeningDarkroom.waitForExistence(timeout: 10))
        app.buttons["Reset to Original"].tap()
        XCTAssertTrue(legacyNote.waitForNonExistence(timeout: 5), "Reset clears the saved Dodge/Burn strokes and their notice")
        var resetPrint: Data?
        for _ in 0..<60 where resetPrint == nil {
            let current = printAfterReopeningDarkroom.screenshot().pngRepresentation
            if current != legacyStrokePrint { resetPrint = current }
            else { Thread.sleep(forTimeInterval: 0.25) }
        }
        let clearedPrint = try XCTUnwrap(resetPrint, "Reset to Original removes the saved stroke from the rendered print")
        snapshot(app, "legacy-stroke-reset")
        saveDarkroom(app)
        inspect(app, "legacy-stroke-reset-saved")

        reopen(app, id: id)
        openFilm(app)
        openDarkroom(app)
        XCTAssertFalse(app.buttons["Dodge / Burn"].exists)
        XCTAssertFalse(app.buttons["Undo last stroke"].exists)
        let reopenedPrint = app.images["Photo 1, print preview"]
        XCTAssertTrue(reopenedPrint.waitForExistence(timeout: 10))
        XCTAssertEqual(reopenedPrint.screenshot().pngRepresentation, clearedPrint,
                       "The reset print remains cleared after reopening")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
        inspect(app, "legacy-stroke-reset-reopened")
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
        app.buttons["Finish & Develop Early"].tap()
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
        tapDarkroom(app)
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
