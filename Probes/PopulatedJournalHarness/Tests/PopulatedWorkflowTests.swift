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
        // A color Photo Film gets contrast grades and crop; the print process hides toning.
        XCTAssertTrue(app.buttons["Contrast"].exists)
        XCTAssertTrue(app.buttons["Crop"].exists)
        XCTAssertFalse(app.buttons["Chemical toning"].exists)
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
        // Typed edits reach the field from the out-of-process keyboard after typeText returns, so wait for them to land.
        // An empty field reports either no text or its placeholder.
        XCTAssertTrue(waitForValue(title, in: ["", title.placeholderValue ?? ""], timeout: 10), "The Rename field is empty before typing")
        title.typeText("Renamed synthetic Film")
        XCTAssertTrue(waitForValue(title, in: ["Renamed synthetic Film"], timeout: 10), "The Rename field holds the new title before saving")
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
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label ENDSWITH %@", " wasted")).firstMatch.exists)
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
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label ENDSWITH %@", " wasted")).firstMatch.exists)
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

    /// PRD 2.1 slice 1 (CAM-14, DRK-09, DRK-10): the white card is part of the print in the Film screen, the Photo
    /// screen and the Darkroom; the Darkroom has no Crop for an Instant print but keeps every other control.
    func testInstantPrintShowsItsCardAndTheDarkroomOffersNoCrop() throws {
        let app = launch(arguments: ["--instant"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].waitForExistence(timeout: 10))
        snapshot(app, "Instant-card-film-screen")
        app.buttons["Open photo 1"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        snapshot(app, "Instant-card-photo-screen")
        app.buttons["Darkroom"].tap()
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
        snapshot(app, "Instant-card-darkroom-exposure")
        for tool in ["Exposure", "Contrast", "Filtration", "Dodge / Burn"] { XCTAssertTrue(app.buttons[tool].exists, tool) }
        XCTAssertFalse(app.buttons["Crop"].exists)
        XCTAssertFalse(app.buttons["Chemical toning"].exists)
        app.buttons["Contrast"].tap()
        let grade = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Contrast grade")).firstMatch
        for _ in 0..<3 where !grade.exists { app.swipeUp() }
        XCTAssertTrue(grade.exists, "Contrast grades are offered on an Instant print")
        snapshot(app, "Instant-card-darkroom-contrast")
        app.buttons["Dodge / Burn"].tap()
        let dodge = app.buttons["Dodge point"]
        for _ in 0..<3 where !dodge.exists { app.swipeUp() }
        XCTAssertTrue(dodge.exists, "Dodge and Burn stay available on an Instant print")
        snapshot(app, "Instant-card-darkroom-dodge-burn")
    }

    /// The Darkroom lays out without overlap, clipping or lost margins for each Photo Camera on the smallest supported
    /// iPhone, at the default and the largest text size. At rest the whole print, an Instant card included, sits below the
    /// navigation bar and inside the screen, scaled to the space the controls leave; the controls clear the reset button;
    /// and the tool row and slider keep the same side margins. At the largest size the slider can also be scrolled to.
    func testDarkroomFitsThePrintAndItsControlsForEveryPhotoCamera() throws {
        for (mode, label) in [("--instant", "Instant"), ("--developed-photo", "Disposable"), ("--medium-format", "6x6")] {
            for largest in [false, true] {
                var arguments = [mode]
                if largest { arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
                let app = launch(arguments: arguments)
                openFilm(app)
                let open = app.buttons["Open photo 1"]
                // At the largest size the print grid starts below the first screen and its rows are created as they scroll in.
                for _ in 0..<12 where !open.exists { _ = open.waitForExistence(timeout: 3); if !open.exists { app.swipeUp() } }
                XCTAssertTrue(open.exists, "\(label) \(largest)")
                open.tap()
                app.buttons["Darkroom"].tap()
                let exposure = app.sliders["Print exposure"]
                XCTAssertTrue(exposure.waitForExistence(timeout: 10), label)
                let name = "Darkroom-\(label)-\(largest ? "largest" : "default")"
                let window = app.windows.firstMatch.frame
                let bar = app.navigationBars["Darkroom"]
                let reset = app.buttons["Reset to Original"]
                let print = app.images["Photo 1, print preview"]
                XCTAssertTrue(print.waitForExistence(timeout: 10), "\(name) print")
                // Let the first render and the controls' measured height settle before reading frames.
                Thread.sleep(forTimeInterval: 1.5)
                // The print, at rest: clear of the bar above, inside the screen, and a usable size.
                XCTAssertGreaterThanOrEqual(print.frame.minY, bar.frame.maxY + 4, "\(name): the print is below the navigation bar")
                XCTAssertTrue(window.contains(print.frame), "\(name): the print is on screen")
                XCTAssertGreaterThanOrEqual(print.frame.height, 100, "\(name): the print is not squeezed away")
                // The controls, at rest: full size, in the side margins, clear of the reset button.
                let margin: CGFloat = 16
                for control in [exposure] + ["Exposure", "Contrast", "Filtration", "Dodge / Burn"].map({ app.buttons[$0] }) where control.exists {
                    XCTAssertGreaterThanOrEqual(control.frame.minX, margin - 2, "\(name): \(control.label) keeps its left margin")
                    XCTAssertLessThanOrEqual(control.frame.maxX, window.maxX - margin + 2, "\(name): \(control.label) keeps its right margin")
                }
                XCTAssertGreaterThanOrEqual(exposure.frame.minX, margin - 2, "\(name): slider left margin")
                XCTAssertLessThanOrEqual(exposure.frame.maxX, window.maxX - margin + 2, "\(name): slider right margin")
                XCTAssertLessThanOrEqual(print.frame.maxY, exposure.frame.minY, "\(name): the print is above the controls")
                XCTAssertLessThanOrEqual(exposure.frame.maxY, reset.frame.minY, "\(name): the slider clears the reset button")
                let value = app.staticTexts["0.0 stops"]
                XCTAssertTrue(value.exists, "\(name) value")
                XCTAssertLessThanOrEqual(value.frame.maxY, reset.frame.minY, "\(name): the value clears the reset button")
                XCTAssertTrue(window.contains(value.frame), "\(name): the value is not clipped")
                XCTAssertTrue(window.contains(exposure.frame), "\(name): the slider is on screen")
                snapshot(app, name)
                // Rendering never resizes the print: releasing the slider starts a render, and the print keeps its frame while
                // it runs and after it ends. The progress sits over the print, not among the controls.
                if label == "Instant" {
                    let before = print.frame
                    exposure.adjust(toNormalizedSliderPosition: 0.75)
                    for _ in 0..<20 {
                        XCTAssertEqual(print.frame.height, before.height, accuracy: 1, "\(name): the print keeps its height while rendering")
                        XCTAssertEqual(print.frame.minY, before.minY, accuracy: 1, "\(name): the print keeps its place while rendering")
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    app.buttons["Reset to Original"].tap()
                    Thread.sleep(forTimeInterval: 1)
                    XCTAssertEqual(print.frame.height, before.height, accuracy: 1, "\(name): and after resetting")
                }
                // Everything fits at rest, so a swipe has nothing to scroll and the print cannot slide under the bar.
                let restingTop = print.frame.minY
                XCTAssertTrue(exposure.isHittable, "\(name): the slider can be used without scrolling")
                app.swipeUp()
                XCTAssertEqual(print.frame.minY, restingTop, accuracy: 1, "\(name): the print stays below the bar after a swipe")
                XCTAssertGreaterThanOrEqual(print.frame.minY, bar.frame.maxY + 4, "\(name): still below the bar after a swipe")
                app.terminate()
            }
        }
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

    private func waitForValue(_ element: XCUIElement, in values: [String], timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value IN %@", values), object: element)
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
