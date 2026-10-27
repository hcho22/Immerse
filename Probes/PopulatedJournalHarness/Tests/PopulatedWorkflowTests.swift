import RenderCore
import XCTest

@MainActor
final class PopulatedWorkflowTests: HarnessTestCase {
    func testEarlyPhotoDevelopmentDarkroomAndRemoval() throws {
        // Rename types deletes into the pre-filled title. With autocorrection off the field receives only the typed
        // keys; otherwise the tap that focuses a pre-filled field makes UIKit accept an autocorrection
        // (Evidence/NativeApp/title-autocorrection-058.md).
        let app = launch(arguments: ["-KeyboardAutocorrection", "NO"])
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
        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 5))
        // A color Photo Film gets contrast grades and Adjust; the print process hides toning.
        XCTAssertTrue(app.buttons["Contrast"].exists)
        XCTAssertTrue(app.buttons["Adjust"].exists)
        XCTAssertTrue(app.buttons["Saturation"].exists)
        XCTAssertTrue(app.buttons["Vignette"].exists)
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
        // The photo view shows the next print once one is discarded (FR-22 item 7); Done returns to the Film.
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 20))
        app.navigationBars["Photo 2"].buttons["Done"].tap()
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
        try requireTetrahedralReader()
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

    /// S8: a Film loaded before live sound records none, and with no Soundtrack in the catalog it has no choice to make,
    /// so its Film screen offers no Movie sound button, though its Movie plays.
    func testAnEarlierSilentMovieFilmOffersNoSoundChoiceWithoutCatalogSoundtracks() throws {
        try requireTetrahedralReader()
        let app = launch(arguments: ["--movie", "--earlier-package", "--hide-inspection-bar"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Save Developed to Photos"].waitForExistence(timeout: 20), "The Movie is developed")
        XCTAssertFalse(app.buttons["movie-sound-choice"].exists, "No dead-end Movie sound button")
        snapshot(app, "earlier-16mm-without-sound-choice")
    }

    func testSuper8SoundChoiceWorksWithoutCatalogSoundtracks() throws {
        try requireTetrahedralReader()
        let app = launch(arguments: ["--movie", "--super8", "--hide-inspection-bar"])
        openFilm(app)
        let soundChoice = app.buttons["movie-sound-choice"]
        XCTAssertTrue(soundChoice.waitForExistence(timeout: 20))
        XCTAssertTrue(soundChoice.label.contains("Recorded sound"), soundChoice.label)
        tapWhole(app, soundChoice)
        XCTAssertTrue(app.navigationBars["Movie sound"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Recorded sound"].exists)
        let silent = app.buttons["Silent"]
        XCTAssertTrue(silent.exists, "Recorded sound and Silent are shown with the empty catalog")
        snapshot(app, "Super8-movie-sound-choices")
        tapWhole(app, silent)
        tapWhole(app, app.buttons["Apply sound choice"])
        XCTAssertTrue(soundChoice.waitForExistence(timeout: 20))
        XCTAssertTrue(soundChoice.label.contains("Silent"), soundChoice.label)

        tapWhole(app, soundChoice)
        XCTAssertTrue(app.navigationBars["Movie sound"].waitForExistence(timeout: 10))
        tapWhole(app, app.buttons["Recorded sound"])
        tapWhole(app, app.buttons["Apply sound choice"])
        XCTAssertTrue(soundChoice.waitForExistence(timeout: 20))
        XCTAssertTrue(soundChoice.label.contains("Recorded sound"), soundChoice.label)
        XCTAssertTrue(app.descendants(matching: .any)["developed-movie-player"].waitForExistence(timeout: 20))
        snapshot(app, "Super8-movie-sound-recorded-again")
    }

    func testMovieDiscardRetiresObservedPlayerItemBeforeSuccessorPlayback() throws {
        try requireTetrahedralReader()
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

    func testPhotoViewSwipesDevelopedPrintsAndDarkroomReturnsToTheSelectedPrint() throws {
        let app = launch(arguments: ["--developed-photo"])
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 1"])
        let first = app.navigationBars["Photo 1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let photo = app.descendants(matching: .any)["photo-view-image"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertEqual(photo.label, "Photo 1, 1 of 2")
        snapshot(app, "photo-view-first-print")
        photo.swipeLeft()
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 10), "A left swipe advances in capture order")
        XCTAssertEqual(photo.label, "Photo 2, 2 of 2")
        turn(app, to: .landscapeLeft)
        XCTAssertGreaterThan(photo.frame.width, photo.frame.height, "The photo view turns with the iPhone")
        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 10))
        let darkroomPortrait = NSPredicate { _, _ in app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width }
        wait(for: [XCTNSPredicateExpectation(predicate: darkroomPortrait, object: nil)], timeout: 10)
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 10))
        let photoLandscape = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        wait(for: [XCTNSPredicateExpectation(predicate: photoLandscape, object: nil)], timeout: 10)
        XCTAssertGreaterThan(photo.frame.width, photo.frame.height, "Cancel restores the turning photo view")
        turn(app, to: .portrait)
        photo.swipeLeft()
        XCTAssertTrue(app.navigationBars["Photo 2"].exists, "The view stays at the end")
        photo.swipeRight()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10), "A right swipe returns to the earlier print")
        photo.swipeLeft()

        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 10), "Cancel returns to the print being edited")
        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 10))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 20), "Save returns to the same print")
        snapshot(app, "photo-view-after-darkroom-save")
    }

    func testPhotoViewSwipesOnSixBySix() throws {
        let app = launch(arguments: ["--medium-format", "--black-and-white"])
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 1"])
        let photo = app.descendants(matching: .any)["photo-view-image"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertEqual(photo.label, "Photo 1, 1 of 2")
        photo.swipeLeft()
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 10))
        XCTAssertEqual(photo.label, "Photo 2, 2 of 2")
        photo.swipeRight()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
    }

    func testFilmPhotoViewDoesNotSwipeToASealedInstantFrame() throws {
        let app = launch(arguments: ["--instant-mixed"])
        openFilm(app)
        XCTAssertTrue(app.staticTexts["Sealed"].firstMatch.exists)
        tapWhole(app, app.buttons["Open photo 1"])
        let photo = app.descendants(matching: .any)["photo-view-image"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertEqual(photo.label, "Photo 1, 1 of 1")
        photo.swipeLeft()
        XCTAssertTrue(app.navigationBars["Photo 1"].exists)
        XCTAssertEqual(photo.label, "Photo 1, 1 of 1")
    }

    /// FR-22 item 7, as the Photos app does it (P4): Discard shows the next print, or the previous one when the last in
    /// order goes, and closes the view only when no developed print is left.
    func testPhotoViewDiscardShowsTheNearestPrintAndClosesWhenNoneIsLeft() throws {
        let app = launch(arguments: ["--developed-photo", "--three-distinct-prints"])
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 2"])
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 10))
        let photo = app.descendants(matching: .any)["photo-view-image"]
        for (expected, label) in [("Photo 3", "Photo 3, 2 of 2"), ("Photo 1", "Photo 1, 1 of 1")] {
            discardShownPrint(app)
            XCTAssertTrue(app.navigationBars[expected].waitForExistence(timeout: 20), "Discard shows \(expected)")
            XCTAssertEqual(photo.label, label)
        }
        discardShownPrint(app)
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 20),
                      "Discard closes the view once no developed print is left")
        XCTAssertTrue(app.staticTexts["Discarded"].exists)
    }

    private func discardShownPrint(_ app: XCUIApplication) {
        XCTAssertTrue(waitUntilStill(app))
        app.buttons["Discard"].tap()
        let confirm = app.sheets.buttons.matching(identifier: "confirm-discard-photo").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }

    /// FR-22 on three prints opened from the middle (P1, P8): each swipe shows the next print's own picture, not only its
    /// title, the ends stop, and a Darkroom Save shows its edit on that print after swiping away and back, while Cancel
    /// changes nothing.
    func testPhotoViewShowsEachPrintsPictureAndTheDarkroomsEdit() throws {
        let app = launch(arguments: ["--developed-photo", "--three-distinct-prints"])
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 2"])
        let photo = app.descendants(matching: .any)["photo-view-image"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        func shown(_ label: String) -> Data {
            let labelled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: photo)
            XCTAssertEqual(XCTWaiter().wait(for: [labelled], timeout: 10), .completed, label)
            XCTAssertTrue(waitUntilStill(app), label)
            return photo.screenshot().pngRepresentation
        }
        let second = shown("Photo 2, 2 of 3")
        photo.swipeLeft()
        let third = shown("Photo 3, 3 of 3")
        XCTAssertNotEqual(third, second, "A swipe shows the next print's picture")
        photo.swipeLeft()
        XCTAssertEqual(shown("Photo 3, 3 of 3"), third, "The last print stops the swipe")
        photo.swipeRight()
        photo.swipeRight()
        let first = shown("Photo 1, 1 of 3")
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, third)
        photo.swipeRight()
        XCTAssertEqual(shown("Photo 1, 1 of 3"), first, "The first print stops the swipe")
        photo.swipeLeft()
        XCTAssertEqual(shown("Photo 2, 2 of 3"), second, "Swiping back shows the same picture")

        // Cancel leaves the print as it was; Save shows the edit there, after swiping away and back too.
        tapDarkroom(app)
        let exposure = app.sliders["Print exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .dragThumb(to: exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        app.buttons["Cancel"].tap()
        XCTAssertEqual(shown("Photo 2, 2 of 3"), second, "Cancel changes nothing")
        tapDarkroom(app)
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .dragThumb(to: exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertNotEqual(exposure.value as? String, "0 stops")
        let save = app.buttons["Save"]
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [rendered], timeout: 20), .completed)
        save.tap()
        let edited = shown("Photo 2, 2 of 3")
        XCTAssertNotEqual(edited, second, "After Save the photo view shows the edit")
        photo.swipeLeft()
        _ = shown("Photo 3, 3 of 3")
        photo.swipeRight()
        XCTAssertEqual(shown("Photo 2, 2 of 3"), edited, "Swiping away and back still shows the edit")
    }

    /// Print exposure reaches both three-stop limits, prints each edit, and saves the result. Dodge/Burn is not an
    /// available Darkroom tool in this build.
    func testDarkroomExposureReachesThreeStopsAndSavesWithoutDodgeBurn() throws {
        let app = launch(arguments: ["--developed-photo"])
        openFilm(app)
        app.buttons["Open photo 1"].tap()
        tapDarkroom(app)
        let exposure = app.sliders["Print exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        XCTAssertEqual(exposure.value as? String, "0 stops")
        let print = app.images["Photo 1, print preview"]
        XCTAssertTrue(print.waitForExistence(timeout: 10))
        let developed = print.screenshot().pngRepresentation

        adjust(exposure, toEnd: 1, showing: app.staticTexts["3.0 stops"])
        XCTAssertTrue(app.staticTexts["3.0 stops"].waitForExistence(timeout: 5), "The slider ends at plus 3 stops")
        XCTAssertEqual(exposure.value as? String, "plus 3 stops")
        XCTAssertTrue(waitForChange(of: print, from: developed), "Plus 3 stops prints a lighter picture")
        snapshot(app, "Darkroom-exposure-plus-3-stops")
        let lightest = print.screenshot().pngRepresentation
        adjust(exposure, toEnd: 0, showing: app.staticTexts["-3.0 stops"])
        XCTAssertTrue(app.staticTexts["-3.0 stops"].waitForExistence(timeout: 5), "The slider ends at minus 3 stops")
        XCTAssertEqual(exposure.value as? String, "minus 3 stops")
        XCTAssertTrue(waitForChange(of: print, from: lightest), "Minus 3 stops prints a darker picture")
        snapshot(app, "Darkroom-exposure-minus-3-stops")

        XCTAssertFalse(app.buttons["Dodge / Burn"].exists)
        XCTAssertFalse(app.buttons["Dodge point"].exists)
        XCTAssertFalse(app.buttons["Undo last stroke"].exists)

        let save = app.buttons["Save"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 20)
        save.tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10), "A recipe at the limits saves")
        snapshot(app, "Photo-printed-at-the-limits")
        tapDarkroom(app)
        XCTAssertTrue(app.staticTexts["-3.0 stops"].waitForExistence(timeout: 10), "The saved recipe comes back")
        XCTAssertFalse(app.buttons["Dodge / Burn"].exists)
        app.buttons["Cancel"].tap()
    }

    /// Moves a slider to one of its ends. XCTest's own adjustment can stop a step short of an end (it does on the strength
    /// slider, and on an iPhone SE it once left the exposure slider at "-2.9 stops"), so where the end's value is not
    /// showing it finishes as a finger does: it drags the thumb past the end. The drag starts on the thumb's middle,
    /// wherever it stopped (the thumb is 38 points wide), because a drag begun beside the thumb does not move it.
    private func adjust(_ slider: XCUIElement, toEnd end: CGFloat, showing value: XCUIElement) {
        slider.adjust(toNormalizedSliderPosition: end)
        guard !value.exists else { return }
        let thumb = (19 + slider.normalizedSliderPosition * (slider.frame.width - 38)) / slider.frame.width
        slider.coordinate(withNormalizedOffset: CGVector(dx: thumb, dy: 0.5))
            .dragThumb(to: slider.coordinate(withNormalizedOffset: CGVector(dx: end == 1 ? 1.2 : -0.2, dy: 0.5)))
    }

    private func waitForChange(of element: XCUIElement, from before: Data, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.screenshot().pngRepresentation != before { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// The sheet of a print the camera has revealed, at rest with nothing over it. A simulator that has not been asked
    /// yet shows the system's Camera request over the print, and XCTest answers it on the test's next touch, so the
    /// print's title is touched before the screen is waited on.
    @discardableResult
    private func printRevealedAtTheCamera(_ sequence: Int, app: XCUIApplication, timeout: TimeInterval = 60) -> XCUIElement {
        let print = app.navigationBars["Photo \(sequence)"]
        XCTAssertTrue(print.waitForExistence(timeout: timeout), "Print \(sequence) is shown at the camera")
        print.tap()
        XCTAssertTrue(waitUntilStill(app), "The sheet of print \(sequence) has come to rest")
        return print
    }

    /// DEV-12: after the tenth Instant print closes, the camera asks once about every revealed original still undecided.
    /// Cancel closes the question without bringing it back; Originals on the Film screen remains the way to decide later.
    func testInstantAsksOnceAfterThePacksLastPrintForEveryUndecidedOriginal() throws {
        let app = launch(arguments: ["--instant-final", "--reveal-at-camera"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertTrue(app.buttons["Open photo 9"].exists)
        XCTAssertFalse(app.buttons["Open photo 10"].exists)
        tapWhole(app, app.buttons["Open Camera"])
        let revealed = printRevealedAtTheCamera(10, app: app)
        snapshot(app, "Instant-pack-final-print-at-the-camera")
        revealed.buttons["Done"].tap()
        let asked = app.staticTexts["Originals of 10 photos"]
        XCTAssertTrue(asked.waitForExistence(timeout: 10), "Closing the pack's last print brings one question for all ten")
        let keep = app.buttons["Save to Photos, then remove from Immerse"]
        let remove = app.buttons["Remove from Immerse without saving"]
        XCTAssertTrue(keep.exists)
        XCTAssertTrue(remove.exists)
        let confirm = app.buttons["confirm-original-choice"]
        XCTAssertFalse(confirm.isEnabled, "Nothing is chosen for the user")
        snapshot(app, "Instant-one-original-question-after-the-pack")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(asked.exists)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10), "The shooting screen returns after cancellation")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Open photo 10"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2), "Cancelling does not ask again by itself")
        tapWhole(app, app.buttons["Originals"])
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Original captures"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove from Immerse without saving"].waitForExistence(timeout: 5))
        snapshot(app, "Instant-originals-remain-available-on-film-screen")
        app.buttons["Cancel"].tap()
    }

    /// The pack-end question, answered once, decides every undecided original together (FR-35 item 3, P8): after it the
    /// Film screen's Originals has nothing left to ask about.
    func testThePackEndAnswerDecidesEveryUndecidedOriginal() throws {
        let app = launch(arguments: ["--instant-final", "--reveal-at-camera"])
        openFilm(app)
        tapWhole(app, app.buttons["Open Camera"])
        let revealed = printRevealedAtTheCamera(10, app: app)
        revealed.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Originals of 10 photos"].waitForExistence(timeout: 10))
        app.buttons["Remove from Immerse without saving"].tap()
        let confirm = app.buttons["confirm-original-choice"]
        let chosen = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: confirm)
        XCTAssertEqual(XCTWaiter().wait(for: [chosen], timeout: 5), .completed)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Originals of 10 photos"].waitForNonExistence(timeout: 20), "The answer closes it")
        XCTAssertTrue(app.buttons["Done"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Open photo 10"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2), "Nothing is asked again")
        tapWhole(app, app.buttons["Originals"])
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Remove from Immerse without saving"].waitForExistence(timeout: 2),
                       "Every original of the pack was decided by the one answer")
        app.buttons["Cancel"].firstMatch.tap()
    }

    func testInstantDoesNotReaskAfterAppClosesWhilePackEndQuestionIsOpen() throws {
        let id = UUID()
        let app = launch(arguments: ["--instant-final", "--reveal-at-camera"], id: id)
        openFilm(app)
        tapWhole(app, app.buttons["Open Camera"])
        let revealed = printRevealedAtTheCamera(10, app: app)
        revealed.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Originals of 10 photos"].waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments = ["--workflow-run", id.uuidString, "--reopen"]
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60))
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 10"].exists)
        XCTAssertTrue(app.buttons["Originals"].exists)
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2), "The missed camera question does not return")
        XCTAssertFalse(app.staticTexts["Originals of 10 photos"].waitForExistence(timeout: 2))
    }

    /// A print discarded from the sheet that revealed it at the camera closes with nothing after it: no earlier print is
    /// shown in its place, and nothing is asked about a print the camera did not just reveal. Print 1, revealed before
    /// the camera opened, still waits under Originals.
    func testInstantPrintDiscardedAtTheCameraBringsNoEarlierPrintAndNoQuestion() throws {
        let app = launch(arguments: ["--instant-mixed", "--reveal-at-camera"])
        openFilm(app)
        app.buttons["Open Camera"].tap()
        let revealed = printRevealedAtTheCamera(2, app: app)
        app.buttons["Discard"].tap()
        let discardConfirmation = app.sheets.buttons.matching(identifier: "confirm-discard-photo").firstMatch
        XCTAssertTrue(discardConfirmation.waitForExistence(timeout: 5))
        discardConfirmation.tap()
        XCTAssertTrue(revealed.waitForNonExistence(timeout: 20), "The discarded print closes")
        XCTAssertFalse(app.navigationBars["Photo 1"].waitForExistence(timeout: 5), "No earlier print is shown in its place")
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2), "No question follows a discarded print")
        snapshot(app, "Instant-print-discarded-at-the-camera")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Discarded"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertFalse(app.buttons["Open photo 2"].exists)
        // The Film screen asks nothing either: print 1 was revealed before the camera opened.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2))
        app.buttons["Originals"].tap()
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove from Immerse without saving"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    /// Two prints that one Development reveals together at the camera are shown in capture order without asking about
    /// originals between them. Until the pack is full, the Film screen's Originals button is the choice path.
    func testInstantShowsNewPrintsInOrderWithoutAnOriginalsQuestionBeforeThePackIsFull() throws {
        let app = launch(arguments: ["--instant-mixed", "--two-sealed", "--reveal-at-camera"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertFalse(app.buttons["Open photo 2"].exists)
        XCTAssertFalse(app.buttons["Open photo 3"].exists)
        app.buttons["Open Camera"].tap()
        let later = app.navigationBars["Photo 3"]
        let earlier = printRevealedAtTheCamera(2, app: app)
        XCTAssertFalse(later.exists, "The earlier print is shown first")
        earlier.buttons["Done"].tap()
        XCTAssertTrue(later.waitForExistence(timeout: 20), "The later print follows directly")
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2), "No question interrupts the reveal queue")
        later.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["capture-shutter"].waitForExistence(timeout: 20), "The camera resumes after the queue")
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Open photo 3"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open photo 2"].exists)
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2), "The Film screen does not ask before the pack is full")
        tapWhole(app, app.buttons["Originals"])
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove from Immerse without saving"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    /// The Instant's reveal view is limited to the new print; the Film screen photo view can swipe between prints.
    func testInstantRevealPhotoViewShowsOnlyItsNewPrint() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(arguments: ["--instant-mixed", "--reveal-at-camera"])
        openFilm(app)
        tapWhole(app, app.buttons["Open Camera"])
        let print = printRevealedAtTheCamera(2, app: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft)
        let staysPortrait = NSPredicate { _, _ in
            let window = app.windows.firstMatch.frame
            return window.height > window.width
        }
        wait(for: [XCTNSPredicateExpectation(predicate: staysPortrait, object: nil)], timeout: 10)
        XCUIDevice.shared.orientation = .portrait
        turn(app, to: .portrait)
        let image = app.descendants(matching: .any)["photo-view-image"]
        // The reveal shows only its new print, counted among the pack's developed prints (P7).
        XCTAssertEqual(image.label, "Photo 2, 2 of 2")
        image.swipeRight()
        XCTAssertTrue(print.exists, "The Instant reveal does not swipe to earlier prints")
        XCTAssertEqual(image.label, "Photo 2, 2 of 2")
        XCTAssertFalse(app.navigationBars["Originals"].waitForExistence(timeout: 2), "No originals question after one print")
        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 10), "The camera reveal opens the same Darkroom")
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width,
                             "The Darkroom stays upright over the shooting screen")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(print.waitForExistence(timeout: 10), "Cancel returns to the camera reveal")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft)
        wait(for: [XCTNSPredicateExpectation(predicate: staysPortrait, object: nil)], timeout: 10)
        XCUIDevice.shared.orientation = .portrait
        turn(app, to: .portrait)
        print.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["capture-shutter"].waitForExistence(timeout: 20))
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

    /// The Instant keeps its white card in the Film screen, the Photo screen and the Darkroom; Adjust turns the whole
    /// card without offering crop or straightening, and Saturation and Vignette reach only its picture.
    func testInstantPrintShowsItsCardAndTheDarkroomOffersWholeCardAdjustments() throws {
        let app = launch(arguments: ["--instant"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].waitForExistence(timeout: 10))
        snapshot(app, "Instant-card-film-screen")
        app.buttons["Open photo 1"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        snapshot(app, "Instant-card-photo-screen")
        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
        snapshot(app, "Instant-card-darkroom-exposure")
        for tool in ["Exposure", "Contrast", "Filtration", "Adjust", "Saturation", "Vignette"] {
            XCTAssertTrue(app.buttons[tool].exists, tool)
        }
        XCTAssertFalse(app.buttons["Dodge / Burn"].exists)
        XCTAssertFalse(app.buttons["Chemical toning"].exists)
        app.buttons["Adjust"].tap()
        XCTAssertTrue(app.buttons["darkroom-rotate-left"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["darkroom-rotate-right"].exists)
        XCTAssertFalse(app.switches["Crop"].exists)
        XCTAssertFalse(app.sliders["Straighten"].exists)
        app.buttons["Vignette"].tap()
        XCTAssertTrue(app.sliders["Vignette"].waitForExistence(timeout: 5))
        app.buttons["Contrast"].tap()
        let grade = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Contrast grade")).firstMatch
        for _ in 0..<3 where !grade.exists { app.swipeUp() }
        XCTAssertTrue(grade.exists, "Contrast grades are offered on an Instant print")
        snapshot(app, "Instant-card-darkroom-contrast")
    }

    /// PRD 2.1 slice 3 (CAM-16, DEV-11, DRK-10): a 6×6 Film on the black-and-white Film Stock names it on the Film
    /// screen and develops gray prints, and its Darkroom offers chemical toning beside contrast and Adjust, with
    /// no color filtration. A sepia-toned print is saved and shown on the Photo and Film screens and in the Journal.
    func testBlackAndWhite6x6PrintTakesChemicalToning() throws {
        let app = launch(arguments: ["--medium-format", "--black-and-white", "--hide-inspection-bar"] + Self.sourceArguments)
        openFilm(app)
        XCTAssertTrue(app.staticTexts["Black and white Film Stock"].exists)
        let open = app.buttons["Open photo 1"]
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        snapshot(app, "BW-6x6-film-screen")
        open.tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        tapDarkroom(app)
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
        for tool in ["Exposure", "Contrast", "Adjust", "Chemical toning"] { XCTAssertTrue(app.buttons[tool].exists, tool) }
        XCTAssertFalse(app.buttons["Dodge / Burn"].exists)
        XCTAssertFalse(app.buttons["Filtration"].exists, "Filtration is for color prints")
        app.buttons["Chemical toning"].tap()
        let toner = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Chemical toning,")).firstMatch
        for _ in 0..<3 where !toner.exists { app.swipeUp() }
        XCTAssertTrue(toner.waitForExistence(timeout: 5), "The toner picker")
        toner.tap()
        let sepia = app.buttons["Sepia"]
        XCTAssertTrue(sepia.waitForExistence(timeout: 5))
        sepia.tap()
        XCTAssertTrue(app.sliders["Toning amount"].waitForExistence(timeout: 5))
        let save = app.buttons["Save"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 30)
        snapshot(app, "BW-6x6-darkroom-sepia")
        save.tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        snapshot(app, "BW-6x6-photo-sepia")
        app.navigationBars["Photo 1"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        snapshot(app, "BW-6x6-film-screen-sepia")
        app.navigationBars["Private synthetic Film"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        snapshot(app, "BW-6x6-journal")
    }

    /// PRD 2.1 slice 3 (DEV-11): a 16mm Film on the black-and-white Film Stock names it and develops a gray Movie.
    func testBlackAndWhite16mmFilmShowsItsDevelopedMovie() throws {
        let app = launch(arguments: ["--movie", "--black-and-white", "--hide-inspection-bar"] + Self.sourceArguments)
        openFilm(app)
        XCTAssertTrue(app.staticTexts["Black and white Film Stock"].exists)
        let player = app.descendants(matching: .any)["developed-movie-player"]
        XCTAssertTrue(player.waitForExistence(timeout: 60))
        Thread.sleep(forTimeInterval: 2)
        snapshot(app, "BW-16mm-developed-movie")
    }

    /// PRD 2.1 slice 4 (CAM-17): each Camera and Film Stock's developed look, on its Film screen and in the photo or
    /// Developed Movie, for screenshots on a large and a small iPhone (Evidence/NativeApp/prd-2-slice-4-looks.md).
    func testDisposableLookScreens() throws { lookScreens(["--developed-photo"], name: "Look-disposable") }
    func testInstantLookScreens() throws { lookScreens(["--instant"], name: "Look-instant") }
    func testSixBySixColorLookScreens() throws {
        try requireTetrahedralReader()
        lookScreens(["--medium-format"], name: "Look-6x6-color")
    }
    func testSixBySixBlackAndWhiteLookScreens() throws {
        lookScreens(["--medium-format", "--black-and-white"], name: "Look-6x6-black-and-white")
    }
    func testSuperEightLookScreens() throws { lookScreens(["--movie", "--super8", "--landscape-movie"], name: "Look-super8") }
    func testSixteenMillimeterColorLookScreens() throws {
        try requireTetrahedralReader()
        lookScreens(["--movie", "--landscape-movie"], name: "Look-16mm-color")
    }
    func testSixteenMillimeterBlackAndWhiteLookScreens() throws {
        lookScreens(["--movie", "--landscape-movie", "--black-and-white"], name: "Look-16mm-black-and-white")
    }

    private func lookScreens(_ arguments: [String], name: String) {
        let app = launch(arguments: arguments + ["--hide-inspection-bar"] + Self.sourceArguments)
        openFilm(app)
        if arguments.contains("--movie") {
            let player = app.descendants(matching: .any)["developed-movie-player"]
            XCTAssertTrue(player.waitForExistence(timeout: 120), name)
            Thread.sleep(forTimeInterval: 2)
            snapshot(app, "\(name)-developed-movie")
            return
        }
        let open = app.buttons["Open photo 1"]
        XCTAssertTrue(open.waitForExistence(timeout: 60), name)
        Thread.sleep(forTimeInterval: 1)
        snapshot(app, "\(name)-film-screen")
        open.tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10), name)
        Thread.sleep(forTimeInterval: 1.5)
        snapshot(app, "\(name)-photo")
    }

    /// A natural still and silent movie for screenshots, when the run supplies them (TEST_RUNNER_PHOTO_SOURCE and
    /// TEST_RUNNER_MOVIE_SOURCE); the generated fixtures otherwise.
    private static var sourceArguments: [String] {
        let environment = ProcessInfo.processInfo.environment
        return [("--photo-source", "PHOTO_SOURCE"), ("--movie-source", "MOVIE_SOURCE")].flatMap { flag, key in
            environment[key].map { [flag, $0] } ?? []
        }
    }

    /// The Darkroom band's text at every one of the 12 text sizes (FR-30): on a color print, every text of every tool
    /// scrolls whole into the band, and the print keeps its frame. One test per size keeps each inside its allowance.
    func testDarkroomBandTextAtExtraSmall() throws { checkBandText("XS") }
    func testDarkroomBandTextAtSmall() throws { checkBandText("S") }
    func testDarkroomBandTextAtMedium() throws { checkBandText("M") }
    func testDarkroomBandTextAtLarge() throws { checkBandText("L") }
    func testDarkroomBandTextAtExtraLarge() throws { checkBandText("XL") }
    func testDarkroomBandTextAtExtraExtraLarge() throws { checkBandText("XXL") }
    func testDarkroomBandTextAtExtraExtraExtraLarge() throws { checkBandText("XXXL") }
    func testDarkroomBandTextAtAccessibilityMedium() throws { checkBandText("AccessibilityM") }
    func testDarkroomBandTextAtAccessibilityLarge() throws { checkBandText("AccessibilityL") }
    func testDarkroomBandTextAtAccessibilityExtraLarge() throws { checkBandText("AccessibilityXL") }
    func testDarkroomBandTextAtAccessibilityExtraExtraLarge() throws { checkBandText("AccessibilityXXL") }
    func testDarkroomBandTextAtAccessibilityExtraExtraExtraLarge() throws { checkBandText("AccessibilityXXXL") }

    private func checkBandText(_ size: String) {
        let app = launch(arguments: ["--developed-photo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"])
        openFilm(app)
        let open = app.buttons["Open photo 1"]
        for _ in 0..<12 where !open.exists { _ = open.waitForExistence(timeout: 3); if !open.exists { app.swipeUp() } }
        tapWhole(app, open)
        tapDarkroom(app)
        let print = app.images["Photo 1, print preview"]
        let band = app.scrollViews["darkroom-control-band"]
        XCTAssertTrue(print.waitForExistence(timeout: 20), "\(size): print")
        XCTAssertTrue(band.waitForExistence(timeout: 10), "\(size): band")
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10), size)
        let printFrame = print.frame
        for tool in ["Exposure", "Contrast", "Filtration", "Adjust", "Saturation", "Vignette"] {
            let button = app.buttons[tool]
            scrollBand(band, untilWhole: button)
            tapWhole(app, button)
            XCTAssertTrue(button.isSelected, "\(size): \(tool) is selected")
            for text in band.staticTexts.allElementsBoundByIndex where text.exists && !text.label.isEmpty {
                scrollBand(band, untilWhole: text)
                XCTAssertTrue(visibleBand(app, band).contains(text.frame),
                              "\(size) \(tool): \"\(text.label)\" scrolls whole into the band: \(text.frame) in \(visibleBand(app, band))")
            }
            XCTAssertEqual(print.frame, printFrame, "\(size) \(tool): the print keeps its frame")
        }
        snapshot(app, "Darkroom-band-text-\(size)")
    }

    /// The part of the band a person sees: its scroll view reaches on under the bottom bar, so it ends at the top of
    /// Reset to Original's bar.
    private func visibleBand(_ app: XCUIApplication, _ band: XCUIElement) -> CGRect {
        let reset = app.buttons["Reset to Original"]
        var frame = band.frame
        if reset.exists { frame.size.height = max(0, min(frame.maxY, reset.frame.minY - 4) - frame.minY) }
        return frame
    }

    /// Scrolls the band with held drags in its leading margin, never free swipes, until `element` is whole in its visible
    /// part. A drag moves at least 40 points, more than the scroll view's own threshold, which a shorter one may not pass.
    private func scrollBand(_ band: XCUIElement, untilWhole element: XCUIElement) {
        let app = XCUIApplication()
        for _ in 0..<12 {
            let frame = element.frame, visible = visibleBand(app, band).insetBy(dx: 0, dy: 2)
            if visible.contains(frame) { return }
            // Content moves with the finger: drag up to reach text below the band, down to reach text above it.
            let needed = max(frame.maxY - visible.maxY, visible.minY - frame.minY) + 8
            let distance = min(visible.height * 0.6, max(40, needed))
            let up = frame.maxY > visible.maxY
            let start = band.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0))
                .withOffset(CGVector(dx: 0, dy: up ? visible.height * 0.85 : visible.height * 0.15))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: up ? -distance : distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    /// Every tool uses the same print area and fixed controls band. At the largest text size, the band scrolls internally.
    func testDarkroomKeepsThePrintAreaAtEveryToolAtTheDefaultSize() throws {
        assertDarkroomLayout("--developed-photo", label: "Disposable", largest: false)
    }

    func testDarkroomKeepsThePrintAreaAtEveryToolAtTheLargestSize() throws {
        assertDarkroomLayout("--developed-photo", label: "Disposable", largest: true)
    }

    func testInstantDarkroomKeepsThePrintAreaAtEveryTool() throws {
        assertDarkroomLayout("--instant", label: "Instant", largest: false)
    }

    func testInstantDarkroomKeepsThePrintAreaAtEveryToolAtTheLargestSize() throws {
        assertDarkroomLayout("--instant", label: "Instant", largest: true)
    }

    func testSixBySixDarkroomKeepsThePrintAreaAtEveryTool() throws {
        try requireTetrahedralReader()
        assertDarkroomLayout("--medium-format", label: "6x6", largest: false)
    }

    func testSixBySixDarkroomKeepsThePrintAreaAtEveryToolAtTheLargestSize() throws {
        try requireTetrahedralReader()
        assertDarkroomLayout("--medium-format", label: "6x6", largest: true)
    }

    func testBlackAndWhiteSixBySixDarkroomKeepsThePrintAreaAtEveryToolAtTheDefaultSize() throws {
        assertDarkroomLayout("--medium-format", label: "6x6-black-and-white", largest: false, blackAndWhite: true)
    }

    func testBlackAndWhiteSixBySixDarkroomKeepsThePrintAreaAtEveryTool() throws {
        assertDarkroomLayout("--medium-format", label: "6x6-black-and-white", largest: true, blackAndWhite: true)
    }

    private func assertDarkroomLayout(_ mode: String, label: String, largest: Bool, blackAndWhite: Bool = false) {
        var arguments = [mode]
        if blackAndWhite { arguments.append("--black-and-white") }
        if largest { arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        let app = launch(arguments: arguments)
        openFilm(app)
        let open = app.buttons["Open photo 1"]
        for _ in 0..<12 where !open.exists { _ = open.waitForExistence(timeout: 3); if !open.exists { app.swipeUp() } }
        XCTAssertTrue(open.exists, "\(label) \(largest)")
        tapWhole(app, open)
        tapDarkroom(app)

        let name = "Darkroom-\(label)-\(largest ? "largest" : "default")"
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 10), name)
        let print = app.images["Photo 1, print preview"]
        let band = app.scrollViews["darkroom-control-band"]
        XCTAssertTrue(print.waitForExistence(timeout: 20), "\(name): print")
        XCTAssertTrue(band.waitForExistence(timeout: 10), "\(name): fixed controls band")
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10), name)
        Thread.sleep(forTimeInterval: 1)

        let window = app.windows.firstMatch.frame
        let initialPrint = print.frame
        let initialBand = band.frame
        XCTAssertTrue(window.contains(print.frame), "\(name): print is on screen")
        XCTAssertGreaterThan(print.frame.height, 0, "\(name): the print remains visible in its fixed area")
        XCTAssertTrue(window.contains(band.frame), "\(name): controls band is on screen")
        XCTAssertGreaterThanOrEqual(band.frame.height, 300, "\(name): band fits the tallest controls at default size")

        let tools: [String]
        if label == "Instant" {
            tools = ["Exposure", "Contrast", "Adjust", "Saturation", "Vignette"]
        } else if blackAndWhite {
            tools = ["Exposure", "Contrast", "Adjust", "Vignette", "Chemical toning"]
        } else if label == "6x6" {
            tools = ["Exposure", "Contrast", "Filtration", "Adjust", "Saturation", "Vignette"]
        } else {
            tools = ["Exposure", "Contrast", "Filtration", "Adjust", "Saturation", "Vignette"]
        }

        for tool in tools {
            let button = app.buttons[tool]
            XCTAssertTrue(button.exists, "\(name): \(tool) is available")
            tapWhole(app, button)
            XCTAssertTrue(button.isSelected, "\(name): \(tool) is selected")
            Thread.sleep(forTimeInterval: 0.25)
            XCTAssertEqual(print.frame.minX, initialPrint.minX, accuracy: 1, "\(name): \(tool) keeps the print's left edge")
            XCTAssertEqual(print.frame.minY, initialPrint.minY, accuracy: 1, "\(name): \(tool) keeps the print's top edge")
            XCTAssertEqual(print.frame.width, initialPrint.width, accuracy: 1, "\(name): \(tool) keeps the print's width")
            XCTAssertEqual(print.frame.height, initialPrint.height, accuracy: 1, "\(name): \(tool) keeps the print's height")
            XCTAssertEqual(band.frame.minY, initialBand.minY, accuracy: 1, "\(name): \(tool) keeps the band's top edge")
            XCTAssertEqual(band.frame.height, initialBand.height, accuracy: 1, "\(name): \(tool) keeps the band's height")
            snapshot(app, "\(name)-tool-\(tool)")
        }

        if largest && tools.contains("Filtration") {
            tapWhole(app, app.buttons["Filtration"])
            let yellow = app.sliders["Yellow"]
            XCTAssertTrue(yellow.waitForExistence(timeout: 5), "\(name): the last Filtration slider exists")
            scrollBand(band, untilWhole: yellow)
            XCTAssertTrue(visibleBand(app, band).contains(yellow.frame), "\(name): the fixed band scrolls internally at large text")
            XCTAssertEqual(print.frame.height, initialPrint.height, accuracy: 1, "\(name): scrolling the band does not resize the print")
            snapshot(app, "\(name)-tool-Filtration-bottom")
        } else if !largest && label != "Instant" {
            // The tallest tool is Adjust with a crop smaller than the print, which shows all five of its rows. At the
            // default text size every one of them rests whole in the band, unscrolled.
            tapWhole(app, app.buttons["Adjust"])
            let crop = app.switches["Crop"]
            XCTAssertTrue(crop.waitForExistence(timeout: 5), "\(name): Crop")
            crop.flipSwitch()
            let size = app.sliders["Crop size"]
            XCTAssertTrue(size.waitForExistence(timeout: 5), "\(name): Crop size")
            size.adjust(toNormalizedSliderPosition: 0.5)
            XCTAssertTrue(app.sliders["Crop Vertical"].waitForExistence(timeout: 5), "\(name): Crop Vertical")
            let rows = [app.sliders["Straighten"], crop, size, app.sliders["Crop Horizontal"], app.sliders["Crop Vertical"]]
            for row in rows {
                XCTAssertTrue(visibleBand(app, band).contains(row.frame),
                              "\(name): \(row.label) rests whole in the band at the default size")
            }
            XCTAssertEqual(band.frame.height, initialBand.height, accuracy: 1, "\(name): the crop's rows keep the band's height")
            snapshot(app, "\(name)-tool-Adjust-crop")
            crop.flipSwitch()
        }
        snapshot(app, name)
        XCTAssertFalse(app.buttons["Dodge / Burn"].exists, "\(name): Dodge/Burn is not a Darkroom tool")
    }

    /// The Darkroom locks portrait even when opened over the landscape photo view, then restores that view's orientation.
    func testDarkroomOpenedFromLandscapePhotoViewRestoresThePhotoView() throws {
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let app = launch(arguments: ["--developed-photo"])
        openFilm(app)
        let open = app.buttons["Open photo 1"]
        for _ in 0..<12 where !open.exists { _ = open.waitForExistence(timeout: 3); if !open.exists { app.swipeUp() } }
        tapWhole(app, open)
        let photo = app.descendants(matching: .any)["photo-view-image"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        turn(app, to: .landscapeLeft)
        XCTAssertGreaterThan(photo.frame.width, photo.frame.height, "The photo view follows the iPhone")

        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 10))
        let upright = NSPredicate { _, _ in app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width }
        wait(for: [XCTNSPredicateExpectation(predicate: upright, object: nil)], timeout: 10)
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        let sideways = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        wait(for: [XCTNSPredicateExpectation(predicate: sideways, object: nil)], timeout: 10)
        XCTAssertGreaterThan(photo.frame.width, photo.frame.height, "Cancel restores the photo view's landscape orientation")

        tapDarkroom(app)
        XCTAssertTrue(app.navigationBars["Darkroom"].waitForExistence(timeout: 10))
        wait(for: [XCTNSPredicateExpectation(predicate: upright, object: nil)], timeout: 10)
        turn(app, to: .portrait)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10))
        wait(for: [XCTNSPredicateExpectation(predicate: upright, object: nil)], timeout: 10)
        XCTAssertGreaterThan(photo.frame.height, photo.frame.width,
                             "The photo view follows the phone's current orientation after Darkroom closes")
    }

    /// Turns the simulator and waits for the window to follow and the layout to settle.
    private func turn(_ app: XCUIApplication, to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let wide = orientation.isLandscape
        let settled = NSPredicate { _, _ in
            let window = app.windows.firstMatch.frame
            return (window.width > window.height) == wide
        }
        wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 10)
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// The screen upright in landscape, where `XCUIApplication.screenshot()` turns the image sideways a second time and
    /// crops it (Evidence/NativeApp/scroll-indicator-drag-053.md).
    private func uprightSnapshot(_ app: XCUIApplication, _ name: String) {
        let screen = XCUIScreen.main.screenshot().image
        let format = UIGraphicsImageRendererFormat()
        format.scale = screen.scale
        let upright = UIGraphicsImageRenderer(size: screen.size, format: format).image { _ in screen.draw(at: .zero) }
        for attachment in [XCTAttachment(image: upright), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// Held drags in the left margin, which neither coast nor move a slider.
    private func dragUp(_ app: XCUIApplication, by distance: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)), withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    private func dragDown(_ app: XCUIApplication, by distance: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)), withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// A test whose Film is on the 16mm Cinema's or the 6×6 Medium Format's color Film Stock is skipped where Core
    /// Image cannot run the tetrahedral reader: there the harness cannot develop that Film.
    private func requireTetrahedralReader() throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
    }

    private func launch(arguments: [String] = [], id: UUID? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = id.map { arguments + ["--workflow-run", $0.uuidString] } ?? arguments
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
