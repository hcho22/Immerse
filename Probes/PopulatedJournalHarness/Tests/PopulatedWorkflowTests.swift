import RenderCore
import XCTest

@MainActor
final class PopulatedWorkflowTests: XCTestCase {
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

    /// DEC-11 (the captain, 2026-10-13): print exposure and Dodge/Burn each run to 3 stops either way. The sliders reach
    /// both ends, show and speak the stops there, and a recipe at the ends saves, prints and comes back.
    func testDarkroomExposureAndDodgeBurnReachThreeStopsAndSave() throws {
        let app = launch(arguments: ["--developed-photo"])
        openFilm(app)
        app.buttons["Open photo 1"].tap()
        app.buttons["Darkroom"].tap()
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

        app.buttons["Dodge / Burn"].tap()
        let strength = app.sliders["Local exposure strength"]
        XCTAssertTrue(strength.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Strength: 0.4 stops"].exists, "A stroke starts at the strength it always had")
        XCTAssertEqual(strength.value as? String, "0.4 stops")
        adjust(strength, toEnd: 1, showing: app.staticTexts["Strength: 3.0 stops"])
        XCTAssertTrue(app.staticTexts["Strength: 3.0 stops"].waitForExistence(timeout: 5), "A stroke reaches 3 stops")
        XCTAssertEqual(strength.value as? String, "3 stops")
        let darkest = print.screenshot().pngRepresentation
        let point = app.buttons["Dodge point"]
        for _ in 0..<4 where !point.isHittable { app.staticTexts["Dodge / Burn"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.staticTexts["Dodge / Burn"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -6))) }
        point.tap()
        XCTAssertTrue(waitForChange(of: print, from: darkest), "A 3 stop dodge on a print 3 stops down shows in the print")
        snapshot(app, "Darkroom-minus-3-stops-with-a-3-stop-dodge")

        let save = app.buttons["Save"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 20)
        save.tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 10), "A recipe at the limits saves")
        snapshot(app, "Photo-printed-at-the-limits")
        app.buttons["Darkroom"].tap()
        XCTAssertTrue(app.staticTexts["-3.0 stops"].waitForExistence(timeout: 10), "The saved recipe comes back")
        app.buttons["Dodge / Burn"].tap()
        XCTAssertTrue(app.buttons["Undo last stroke"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Undo last stroke"].isEnabled)
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
            .press(forDuration: 0.2, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: end == 1 ? 1.2 : -0.2, dy: 0.5)))
    }

    private func waitForChange(of element: XCUIElement, from before: Data, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.screenshot().pngRepresentation != before { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// A sheet the app raises on its own, not after a tap of the test's, is still rising when its controls first exist,
    /// and iOS ignores a tap sent while it rises. Two looks alike a quarter of a second apart mean it has come to rest.
    private func waitUntilStill(_ app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var last = app.screenshot().pngRepresentation
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
            let now = app.screenshot().pngRepresentation
            if now == last { return true }
            last = now
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

    /// DEC-11 (the captain, 2026-10-13): the Instant asks about the original after each print is revealed. A print
    /// revealed at the camera is shown first; closing it brings the question, for that print only, and the camera is
    /// back afterwards. The earlier print, never asked about here, still waits under Originals on the Film screen.
    func testInstantAsksAboutTheOriginalOfThePrintRevealedAtTheCamera() throws {
        let app = launch(arguments: ["--instant-mixed", "--reveal-at-camera"])
        openFilm(app)
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertFalse(app.buttons["Open photo 2"].exists)
        app.buttons["Open Camera"].tap()
        let revealed = printRevealedAtTheCamera(2, app: app)
        snapshot(app, "Instant-print-revealed-at-the-camera")
        revealed.buttons["Done"].tap()
        let asked = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Original of photo 2")).firstMatch
        XCTAssertTrue(asked.waitForExistence(timeout: 10), "Closing the print brings the question about its original")
        let keep = app.buttons["Save to Photos, then remove from Immerse"]
        let remove = app.buttons["Remove from Immerse without saving"]
        XCTAssertTrue(keep.exists)
        XCTAssertTrue(remove.exists)
        let confirm = app.buttons["confirm-original-choice"]
        XCTAssertFalse(confirm.isEnabled, "Nothing is chosen for the user")
        snapshot(app, "Instant-original-question-at-the-camera")
        remove.tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(app.buttons["capture-shutter"].waitForExistence(timeout: 20), "The camera is back after the answer")
        XCTAssertFalse(asked.exists)
        app.navigationBars.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Open photo 2"].waitForExistence(timeout: 10))
        // The Film screen does not ask again about a print the camera asked about.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(asked.exists)
        XCTAssertFalse(app.navigationBars["Originals"].exists)
        // Print 1 was revealed before this session and never asked about here: its choice still waits under Originals.
        app.buttons["Originals"].tap()
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove from Immerse without saving"].waitForExistence(timeout: 5))
        snapshot(app, "Instant-earlier-print-waits-under-Originals")
        app.buttons["Cancel"].tap()
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
        XCTAssertFalse(app.navigationBars["Originals"].exists, "No question follows a discarded print")
        snapshot(app, "Instant-print-discarded-at-the-camera")
        app.navigationBars.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Discarded"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open photo 1"].exists)
        XCTAssertFalse(app.buttons["Open photo 2"].exists)
        // The Film screen asks nothing either: print 1 was revealed before the camera opened.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.navigationBars["Originals"].exists)
        app.buttons["Originals"].tap()
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove from Immerse without saving"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    /// Two prints that one Development reveals together at the camera are each shown in the order they were taken, and
    /// closing each brings the question about that print's original before the next is shown: once each, none skipped.
    /// The Film screen asks about neither again, and the question left unanswered waits under Originals.
    func testInstantShowsAndAsksAboutEachOfTwoPrintsRevealedTogetherAtTheCamera() throws {
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
        let askedEarlier = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Original of photo 2")).firstMatch
        XCTAssertTrue(askedEarlier.waitForExistence(timeout: 10), "Closing the earlier print brings the question about its original")
        XCTAssertFalse(later.exists, "The later print waits for the answer")
        app.buttons["Remove from Immerse without saving"].tap()
        app.buttons["confirm-original-choice"].tap()
        printRevealedAtTheCamera(3, app: app, timeout: 20)
        XCTAssertFalse(askedEarlier.exists)
        later.buttons["Done"].tap()
        let askedLater = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Original of photo 3")).firstMatch
        XCTAssertTrue(askedLater.waitForExistence(timeout: 10), "Closing the later print brings the question about its original")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(askedLater.waitForNonExistence(timeout: 10))
        XCTAssertFalse(earlier.waitForExistence(timeout: 5), "No print is shown a second time")
        XCTAssertFalse(later.exists, "No print is shown a second time")
        XCTAssertFalse(app.navigationBars["Originals"].exists, "No print is asked about a second time")
        app.navigationBars.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Open photo 3"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open photo 2"].exists)
        // The Film screen does not ask again about the prints the camera asked about.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.navigationBars["Originals"].exists)
        // The unanswered question, and print 1's, wait under Originals.
        app.buttons["Originals"].tap()
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove from Immerse without saving"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    /// A question about an original that is closed without an answer is not an answer: nothing is removed or saved, and
    /// the choice waits under Originals on the Film screen.
    func testInstantOriginalQuestionLeftUnansweredWaitsUnderOriginals() throws {
        let app = launch(arguments: ["--instant-mixed"])
        openFilm(app)
        app.buttons["Resume Development"].tap()
        let asked = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Original of photo 2")).firstMatch
        XCTAssertTrue(asked.waitForExistence(timeout: 40), "The Film screen asks about the print it revealed")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Open photo 2"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(asked.exists, "The question is asked once")
        app.buttons["Originals"].tap()
        XCTAssertTrue(app.navigationBars["Originals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Original captures")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Save to Photos, then remove from Immerse"].exists)
        XCTAssertTrue(app.buttons["Remove from Immerse without saving"].exists)
        app.buttons["Cancel"].tap()
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

    /// PRD 2.1 slice 3 (CAM-16, DEV-11, DRK-10): a 6×6 Film on the black-and-white Film Stock names it on the Film
    /// screen and develops gray prints, and its Darkroom offers chemical toning beside contrast, crop and Dodge/Burn, with
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
        app.buttons["Darkroom"].tap()
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10))
        for tool in ["Exposure", "Contrast", "Crop", "Dodge / Burn", "Chemical toning"] { XCTAssertTrue(app.buttons[tool].exists, tool) }
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

    /// The Darkroom lays out without overlap, clipping or lost margins for each Photo Camera on the smallest supported
    /// iPhone, at the default and the largest text size. At rest the whole print, an Instant card included, sits below the
    /// navigation bar and inside the screen, scaled to the space the controls leave; the controls clear the reset button;
    /// and the tool row and slider keep the same side margins. At the largest size the slider can also be scrolled to.
    /// With Dodge/Burn's longer controls nothing tappable rests under the reset button's bar, and the last row scrolls
    /// clear of it and takes taps.
    func testDarkroomFitsAnInstantPrintAtTheDefaultSize() throws { assertDarkroomFits("--instant", label: "Instant", largest: false) }
    func testDarkroomFitsAnInstantPrintAtTheLargestSize() throws { assertDarkroomFits("--instant", label: "Instant", largest: true) }
    func testDarkroomFitsADisposablePrintAtTheDefaultSize() throws { assertDarkroomFits("--developed-photo", label: "Disposable", largest: false) }
    func testDarkroomFitsADisposablePrintAtTheLargestSize() throws { assertDarkroomFits("--developed-photo", label: "Disposable", largest: true) }
    func testDarkroomFitsA6x6PrintAtTheDefaultSize() throws {
        try requireTetrahedralReader()
        assertDarkroomFits("--medium-format", label: "6x6", largest: false)
    }
    func testDarkroomFitsA6x6PrintAtTheLargestSize() throws {
        try requireTetrahedralReader()
        assertDarkroomFits("--medium-format", label: "6x6", largest: true)
    }
    func testDarkroomFitsABlackAndWhite6x6PrintAtTheDefaultSize() throws {
        assertDarkroomFits("--medium-format", label: "6x6-black-and-white", largest: false, blackAndWhite: true)
    }
    func testDarkroomFitsABlackAndWhite6x6PrintAtTheLargestSize() throws {
        assertDarkroomFits("--medium-format", label: "6x6-black-and-white", largest: true, blackAndWhite: true)
    }

    private func assertDarkroomFits(_ mode: String, label: String, largest: Bool, blackAndWhite: Bool = false) {
        var arguments = [mode]
        if blackAndWhite { arguments.append("--black-and-white") }
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
        for control in [exposure] + ["Exposure", "Contrast", "Filtration", "Crop", "Dodge / Burn", "Chemical toning"].map({ app.buttons[$0] })
        where control.exists {
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
        // Dodge/Burn has the most controls, which overflow the screen once the print is at its smallest. The floating
        // Reset to Original bar takes every tap across the screen's width from 15 pt above its button, so at rest no
        // control may show there. XCUITest reports a control's whole frame, so only the part the scroll area shows counts.
        app.buttons["Dodge / Burn"].tap()
        let point = app.buttons["Dodge point"]
        let undo = app.buttons["Undo last stroke"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "\(name) Dodge / Burn")
        Thread.sleep(forTimeInterval: 1.5)
        let resetBar = CGRect(x: window.minX, y: reset.frame.minY - 15, width: window.width, height: window.maxY - reset.frame.minY + 15)
        let controlsArea = app.scrollViews.containing(NSPredicate(format: "label == %@", "Photo 1, print preview")).firstMatch.frame
        XCTAssertGreaterThanOrEqual(print.frame.minY, bar.frame.maxY + 4, "\(name): Dodge / Burn keeps the print below the bar")
        for control in app.buttons.allElementsBoundByIndex + app.sliders.allElementsBoundByIndex
        where control.isHittable && control.label != "Reset to Original" {
            XCTAssertFalse(control.frame.intersection(controlsArea).intersects(resetBar), "\(name): \(control.label) rests under the Reset bar")
        }
        snapshot(app, "\(name)-dodge-burn")
        // The last row scrolls fully clear of the bar, and its controls then take a tap. The held drags in the left
        // margin neither coast nor move a slider or paint on the print.
        let clear = min(controlsArea.maxY + 1, resetBar.minY)
        for _ in 0..<12 where undo.frame.maxY > clear {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.6))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)), withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTAssertLessThanOrEqual(undo.frame.maxY, clear, "\(name): the last row scrolls fully into view, clear of the Reset bar")
        XCTAssertFalse(undo.isEnabled, "\(name): no stroke yet")
        point.tap()
        XCTAssertTrue(undo.isEnabled, "\(name): Dodge point takes the tap")
        undo.tap()
        XCTAssertFalse(undo.isEnabled, "\(name): Undo last stroke takes the tap")
    }

    /// A Darkroom explanation takes its height from the print, so the selected tool stays where a finger finds it. With
    /// the explanation of a print whose stored recipe is outside the limits showing (`--recipe-outside-limits`), at the
    /// default text size the tool row, the tool's heading, its value and its slider all rest on screen, above the fade
    /// and the Reset to Original bar, and the slider takes a drag with nothing scrolled. At the largest size the
    /// explanation alone is taller than the screen, so the slider is scrolled to: it comes fully clear of the fade and
    /// takes the same drag.
    func testDarkroomRestsTheSelectedToolOnScreenUnderAnExplanation() throws { assertDarkroomExplains(largest: false) }
    func testDarkroomUnderAnExplanationScrollsItsSliderClearAtTheLargestSize() throws { assertDarkroomExplains(largest: true) }

    private func assertDarkroomExplains(largest: Bool) {
        var arguments = ["--developed-photo", "--recipe-outside-limits"]
        if largest { arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        let app = launch(arguments: arguments)
        openFilm(app)
        let open = app.buttons["Open photo 1"]
        for _ in 0..<12 where !open.exists { _ = open.waitForExistence(timeout: 3); if !open.exists { app.swipeUp() } }
        XCTAssertTrue(open.exists, "\(largest)")
        open.tap()
        app.buttons["Darkroom"].tap()
        let name = "Darkroom-explanation-\(largest ? "largest" : "default")"
        let mark = app.images["Print unavailable"]
        XCTAssertTrue(mark.waitForExistence(timeout: 20), "\(name): the print is refused")
        let explanation = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "outside what this version of Immerse can print")).firstMatch
        XCTAssertTrue(explanation.exists, "\(name): the Darkroom says why")
        let exposure = app.sliders["Print exposure"]
        XCTAssertTrue(exposure.exists, "\(name) slider")
        // Let the controls' measured height settle before reading frames.
        Thread.sleep(forTimeInterval: 1.5)
        let bar = app.navigationBars["Darkroom"]
        let reset = app.buttons["Reset to Original"]
        let area = app.scrollViews.containing(NSPredicate(format: "label == %@", "Print unavailable")).firstMatch.frame
        // The scroll area's last 12 pt fade out, so a control in full view ends above them.
        let clear = area.maxY - 12 + 1
        snapshot(app, name)
        if largest {
            // The held drags in the left margin neither coast nor move a slider.
            for _ in 0..<16 where exposure.frame.maxY > clear {
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -240)), withVelocity: .slow, thenHoldForDuration: 0.3)
            }
            snapshot(app, "\(name)-slider")
        } else {
            XCTAssertGreaterThanOrEqual(mark.frame.minY, bar.frame.maxY, "\(name): the print's place is below the navigation bar")
            XCTAssertLessThanOrEqual(mark.frame.maxY, explanation.frame.minY, "\(name): the explanation is under the print's place")
            let tools = ["Exposure", "Contrast", "Filtration", "Crop", "Dodge / Burn"].map { app.buttons[$0] }
            for control in [explanation, app.staticTexts["Exposure"], app.staticTexts["3.5 stops"]] + tools {
                XCTAssertTrue(control.exists, name)
                XCTAssertGreaterThanOrEqual(control.frame.minY, bar.frame.maxY, "\(name): \(control.label) rests on screen")
                XCTAssertLessThanOrEqual(control.frame.maxY, clear, "\(name): \(control.label) rests on screen, above the fade")
            }
        }
        XCTAssertGreaterThanOrEqual(exposure.frame.minY, bar.frame.maxY, "\(name): the slider is in view")
        XCTAssertLessThanOrEqual(exposure.frame.maxY, clear, "\(name): the slider is in view, above the fade")
        XCTAssertLessThanOrEqual(area.maxY, reset.frame.minY, "\(name): the controls end above Reset to Original")
        XCTAssertTrue(reset.isHittable, "\(name): Reset to Original is on screen")
        // A drag sent to where the slider's thumb is, which scrolls nothing: 3.5 stops rests at the slider's end.
        exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: exposure.coordinate(withNormalizedOffset: CGVector(dx: -0.2, dy: 0.5)))
        XCTAssertTrue(app.staticTexts["-3.0 stops"].waitForExistence(timeout: 5), "\(name): the slider takes the drag")
        XCTAssertTrue(app.images["Photo 1, print preview"].waitForExistence(timeout: 20), "\(name): inside the limits the print is made")
        XCTAssertFalse(explanation.exists, "\(name): the explanation goes once the print can be made")
    }

    /// The captain (2026-10-14): on a short screen the print gives up height in the Crop tool, so every Crop control
    /// shows. With a crop smaller than the whole print, at the default text size the switch and the Size, Horizontal and
    /// Vertical sliders and their captions all rest between the navigation bar and the fade, above Reset to Original,
    /// with nothing scrolled, and the Vertical slider takes a drag there. The print is still shown above them, and back
    /// in Exposure it has the size it had before Crop. At the largest size the controls cannot all fit, so the Vertical
    /// slider is scrolled to, comes fully clear of the fade and takes the same drag.
    func testDarkroomRestsEveryCropControlOnScreenAtTheDefaultSize() throws { assertDarkroomCropFits(largest: false) }
    func testDarkroomScrollsTheCropControlsClearAtTheLargestSize() throws { assertDarkroomCropFits(largest: true) }

    private func assertDarkroomCropFits(largest: Bool) {
        var arguments = ["--developed-photo"]
        if largest { arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        let app = launch(arguments: arguments)
        openFilm(app)
        let open = app.buttons["Open photo 1"]
        for _ in 0..<12 where !open.exists { _ = open.waitForExistence(timeout: 3); if !open.exists { app.swipeUp() } }
        XCTAssertTrue(open.exists, "\(largest)")
        open.tap()
        app.buttons["Darkroom"].tap()
        let name = "Darkroom-crop-\(largest ? "largest" : "default")"
        let print = app.images["Photo 1, print preview"]
        XCTAssertTrue(print.waitForExistence(timeout: 20), "\(name) print")
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 10), name)
        // Let the first render and the controls' measured height settle before reading frames.
        Thread.sleep(forTimeInterval: 1.5)
        let exposurePrint = print.frame
        app.buttons["Crop"].tap()
        let crop = app.switches["Crop"]
        XCTAssertTrue(crop.waitForExistence(timeout: 5), name)
        // At the largest size the switch can start below the fold; held drags in the left margin bring it up.
        let area = app.scrollViews.containing(NSPredicate(format: "label == %@", "Photo 1, print preview")).firstMatch
        for _ in 0..<12 where !crop.isHittable { dragUp(app, by: 160) }
        crop.tap()
        let size = app.sliders["Crop size"]
        XCTAssertTrue(size.waitForExistence(timeout: 5), name)
        for _ in 0..<12 where !size.isHittable { dragUp(app, by: 160) }
        size.adjust(toNormalizedSliderPosition: 0.6)
        let vertical = app.sliders["Crop Vertical"]
        XCTAssertTrue(vertical.waitForExistence(timeout: 5), name)
        XCTAssertTrue(print.waitForExistence(timeout: 20), "\(name): the cropped print is made")
        Thread.sleep(forTimeInterval: 1.5)
        let bar = app.navigationBars["Darkroom"]
        let reset = app.buttons["Reset to Original"]
        // The scroll area's last 12 pt fade out, so a control in full view ends above them.
        let clear = area.frame.maxY - 12 + 1
        XCTAssertLessThanOrEqual(area.frame.maxY, reset.frame.minY, "\(name): the controls end above Reset to Original")
        snapshot(app, name)
        if largest {
            for _ in 0..<16 where vertical.frame.maxY > clear { dragUp(app, by: 240) }
            snapshot(app, "\(name)-vertical")
        } else {
            let controls = [crop, size, app.sliders["Crop Horizontal"], vertical, app.staticTexts["Crop"].firstMatch]
                + ["Size", "Horizontal", "Vertical"].map { app.staticTexts[$0] }
            for control in controls {
                XCTAssertTrue(control.exists, "\(name): \(control.label)")
                XCTAssertGreaterThanOrEqual(control.frame.minY, bar.frame.maxY, "\(name): \(control.label) rests on screen")
                XCTAssertLessThanOrEqual(control.frame.maxY, clear, "\(name): \(control.label) rests on screen, above the fade")
            }
            // The print is still shown, below the bar and above the controls.
            XCTAssertGreaterThanOrEqual(print.frame.minY, bar.frame.maxY + 4, "\(name): the print is below the navigation bar")
            XCTAssertLessThanOrEqual(print.frame.maxY, crop.frame.minY, "\(name): the print is above the controls")
            XCTAssertGreaterThanOrEqual(print.frame.height, 64, "\(name): the print is not squeezed away")
        }
        XCTAssertGreaterThanOrEqual(vertical.frame.minY, bar.frame.maxY, "\(name): the Vertical slider is in view")
        XCTAssertLessThanOrEqual(vertical.frame.maxY, clear, "\(name): the Vertical slider is in view, above the fade")
        XCTAssertTrue(vertical.isHittable, "\(name): the Vertical slider can be used")
        // A drag from the thumb at the start of the slider to past its end moves the crop to the bottom of the print.
        let before = vertical.value as? String
        vertical.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: vertical.coordinate(withNormalizedOffset: CGVector(dx: 1.2, dy: 0.5)))
        XCTAssertNotEqual(vertical.value as? String, before, "\(name): the Vertical slider takes the drag")
        // Without the crop, back in Exposure, the print has the size it had before Crop opened.
        for _ in 0..<16 where !crop.isHittable { dragDown(app, by: 240) }
        crop.tap()
        app.buttons["Exposure"].tap()
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 5), name)
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(print.frame.height, exposurePrint.height, accuracy: 1, "\(name): Exposure keeps the print's size")
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
