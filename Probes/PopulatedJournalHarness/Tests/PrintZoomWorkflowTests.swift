import RenderCore
import XCTest

/// Print Zoom and Adjust's Photos-style crop (the captain, 2026-10-29, "1A", "2A", "3A" and "8A"), on actual views with
/// private synthetic Films. Each test photographs what it shows, which the approval screenshots are taken from:
/// `TEST_RUNNER_PHOTO_SOURCE` develops a natural photo instead of the synthetic one and `TEST_RUNNER_CONTENT_SIZE` sets
/// the text size.
final class PrintZoomWorkflowTests: HarnessTestCase {
    // MARK: Print Zoom in the photo view

    /// Pinch and double-tap zoom in, a drag looks around, and only the whole print swipes to the next one, as in the
    /// Photos app. Another print shows whole, and a zoom survives the iPhone turning.
    func testPhotoViewZoomsAsPhotosDoesAndSwipesOnlyAtTheWholePrint() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(["--developed-photo", "--three-distinct-prints"])
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 2"])
        let photo = app.descendants(matching: .any)["photo-view-image"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertFalse(isZoomed(photo))

        photo.pinch(withScale: 3, velocity: 2)
        XCTAssertTrue(waitForZoom(photo, true), "A pinch zooms in")
        let zoomed = waitForStillPicture(of: photo)
        photo.swipeLeft()
        XCTAssertTrue(app.navigationBars["Photo 2"].exists, "Zoomed in, a swipe looks around instead of moving on")
        XCTAssertTrue(isZoomed(photo))
        XCTAssertNotEqual(waitForStillPicture(of: photo), zoomed, "The drag moved the zoomed print")

        photo.doubleTap()
        XCTAssertTrue(waitForZoom(photo, false), "A double-tap shows the whole print again")
        photo.swipeLeft()
        XCTAssertTrue(app.navigationBars["Photo 3"].waitForExistence(timeout: 10), "The whole print swipes to the next")
        XCTAssertEqual(photo.label, "Photo 3, 3 of 3")

        photo.doubleTap()
        XCTAssertTrue(waitForZoom(photo, true), "A double-tap zooms in")
        turn(app, to: .landscapeLeft)
        XCTAssertTrue(isZoomed(photo), "The zoom survives a turn")
        turn(app, to: .portrait)
        XCTAssertTrue(isZoomed(photo))
        photo.swipeRight()
        XCTAssertTrue(app.navigationBars["Photo 3"].exists, "Still zoomed in, the swipe stays on the print")
        photo.doubleTap()
        XCTAssertTrue(waitForZoom(photo, false))
        photo.swipeRight()
        XCTAssertTrue(app.navigationBars["Photo 2"].waitForExistence(timeout: 10))
        XCTAssertFalse(isZoomed(photo), "Another print shows whole")
    }

    /// Every photo Camera zooms in its photo view: the Disposable, the 6×6 and the Instant, whose card edge zooms with
    /// the print.
    func testEveryPhotoCameraZoomsInThePhotoView() throws {
        let cameras: [(arguments: [String], name: String)] = NativePhotoRenderer.readsFilmTables
            ? [(["--developed-photo"], "Disposable"), (["--medium-format"], "6x6"), (["--instant"], "Instant")]
            : [(["--developed-photo"], "Disposable"), (["--medium-format", "--black-and-white"], "6x6"), (["--instant"], "Instant")]
        for camera in cameras {
            let app = launch(camera.arguments + Self.evidenceArguments)
            openFilm(app)
            openPhoto(app)
            let photo = app.descendants(matching: .any)["photo-view-image"]
            XCTAssertTrue(photo.waitForExistence(timeout: 10), camera.name)
            XCTAssertTrue(waitUntilStill(app), camera.name)
            photo.pinch(withScale: 4, velocity: 2)
            XCTAssertTrue(waitForZoom(photo, true), "\(camera.name): a pinch zooms in")
            _ = waitForStillPicture(of: photo)
            snapshot(app, "photo-view-\(camera.name)-zoomed")
            app.terminate()
        }
    }

    /// The Instant print shown at the camera right after an exposure zooms as well, and still moves to no other print.
    func testInstantPrintAtTheCameraZoomsAndStaysOnItsPrint() throws {
        let app = launch(["--instant-mixed", "--reveal-at-camera"] + Self.evidenceArguments)
        openFilm(app)
        tapWhole(app, app.buttons["Open Camera"])
        let revealed = app.navigationBars["Photo 2"]
        XCTAssertTrue(revealed.waitForExistence(timeout: 60), "The print is shown at the camera")
        revealed.tap()
        XCTAssertTrue(waitUntilStill(app))
        let photo = app.descendants(matching: .any)["photo-view-image"]
        photo.pinch(withScale: 3, velocity: 2)
        XCTAssertTrue(waitForZoom(photo, true), "A pinch zooms in at the camera")
        _ = waitForStillPicture(of: photo)
        snapshot(app, "photo-view-Instant-at-the-camera-zoomed")
        photo.doubleTap()
        XCTAssertTrue(waitForZoom(photo, false))
        photo.swipeRight()
        XCTAssertTrue(revealed.exists, "The reveal does not swipe to earlier prints")
        XCTAssertEqual(photo.label, "Photo 2, 2 of 2")
        revealed.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["capture-shutter"].waitForExistence(timeout: 20))
    }

    // MARK: Print Zoom in the Darkroom

    /// Print Zoom on a Darkroom tool is for looking only: a tool change shows the whole print again, and a Save after
    /// zooming leaves the print as it was.
    func testDarkroomZoomIsForLookingOnly() throws {
        let app = launch(["--developed-photo"] + Self.evidenceArguments)
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 1"])
        let photo = app.descendants(matching: .any)["photo-view-image"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        let before = waitForStillPicture(of: photo)
        tapDarkroom(app)
        let preview = app.images["Photo 1, print preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntilStill(app))

        preview.pinch(withScale: 4, velocity: 2)
        XCTAssertTrue(waitForZoom(preview, true), "A pinch zooms in on the Exposure tool")
        _ = waitForStillPicture(of: preview)
        snapshot(app, "darkroom-Exposure-zoomed")
        let exposure = app.sliders["Print exposure"]
        exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .dragThumb(to: exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        XCTAssertTrue(isZoomed(preview), "A slider move keeps the zoom")
        // Back to the developed print exactly, which a drag back to the slider's middle need not land on.
        app.buttons["Reset to Original"].tap()
        XCTAssertTrue(app.staticTexts["0.0 stops"].waitForExistence(timeout: 5))

        app.buttons["Contrast"].tap()
        XCTAssertTrue(waitForZoom(preview, false), "Another tool shows the whole print")
        preview.doubleTap()
        XCTAssertTrue(waitForZoom(preview, true), "A double-tap zooms in")
        app.buttons["Adjust"].tap()
        XCTAssertTrue(cropBox(app).waitForExistence(timeout: 20), "Adjust shows its crop box instead")
        app.buttons["Vignette"].tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertFalse(isZoomed(preview), "Back from Adjust, the whole print")
        preview.pinch(withScale: 3, velocity: 2)
        XCTAssertTrue(waitForZoom(preview, true))

        XCTAssertTrue(waitUntilEnabled(app.buttons["Save"]))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 20))
        XCTAssertFalse(isZoomed(photo), "The photo view shows the saved print whole")
        XCTAssertEqual(waitForStillPicture(of: photo), before, "Zooming never changes the print")
        tapDarkroom(app)
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        XCTAssertFalse(isZoomed(preview), "The Darkroom opens on the whole print")
        app.buttons["Cancel"].tap()
    }

    // MARK: Adjust's crop

    /// The crop box resizes by its handles, re-centers after release, takes every shape on the Disposable sideways or
    /// upright, and crops by a pinch on the print under it. A saved crop opens again as it was saved.
    func testAdjustCropsAsThePhotosAppCrops() throws {
        let app = launch(["--developed-photo"] + Self.evidenceArguments)
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 1"])
        tapDarkroom(app)
        let region = openAdjust(app)
        let box = cropBox(app)
        XCTAssertEqual(kept(box), Kept(width: 100, height: 100))
        XCTAssertTrue(shape(app, "Freeform").isSelected, "An uncropped print starts on Freeform")
        for name in ["Original", "Freeform", "Square", "4:3", "3:2"] {
            XCTAssertTrue(shape(app, name).exists, name)
        }
        XCTAssertFalse(app.buttons["darkroom-crop-orientation"].isEnabled, "Freeform has no sideways or upright")
        snapshot(app, "adjust-Disposable-freeform")

        // A corner handle on Freeform resizes the box freely over a still print; let go, the box re-centers and grows.
        drag(app, box, corner: CGVector(dx: 0, dy: 0), by: CGVector(dx: 70, dy: 30))
        let freeform = kept(box)
        XCTAssertLessThan(freeform.width, 100)
        XCTAssertLessThan(freeform.height, 100)
        XCTAssertNotEqual(freeform.width, freeform.height, "Freeform keeps no shape")
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.midX, region.midX, accuracy: 1.5, "The box re-centers after release")
        XCTAssertEqual(box.frame.midY, region.midY, accuracy: 1.5)
        XCTAssertTrue(abs(box.frame.width - (region.width - 48)) < 1.5 || abs(box.frame.height - (region.height - 48)) < 1.5,
                      "The box grows to fill the print area again")
        snapshot(app, "adjust-Disposable-freeform-cropped")

        // An edge handle moves one edge.
        drag(app, box, corner: CGVector(dx: 1, dy: 0.5), by: CGVector(dx: -40, dy: 0))
        XCTAssertLessThan(kept(box).width, freeform.width)
        XCTAssertEqual(kept(box).height, freeform.height, accuracy: 1)

        // Square on the 3:2 print: as many pixels across as down.
        tapInBand(app, shape(app, "Square"))
        let square = kept(box)
        XCTAssertEqual(Double(square.width) * 3, Double(square.height) * 2, accuracy: 3, "\(square)")
        XCTAssertFalse(app.buttons["darkroom-crop-orientation"].isEnabled)
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.width, box.frame.height, accuracy: 1.5)

        // 3:2, sideways and then upright.
        tapInBand(app, shape(app, "3:2"))
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.width / box.frame.height, 1.5, accuracy: 0.02)
        snapshot(app, "adjust-Disposable-3x2")
        let orientation = app.buttons["darkroom-crop-orientation"]
        XCTAssertEqual(orientation.value as? String, "Sideways")
        tapInBand(app, orientation)
        XCTAssertEqual(orientation.value as? String, "Upright")
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.height / box.frame.width, 1.5, accuracy: 0.02)
        snapshot(app, "adjust-Disposable-3x2-upright")
        // A corner handle keeps the shape.
        drag(app, box, corner: CGVector(dx: 1, dy: 1), by: CGVector(dx: -30, dy: -60))
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.height / box.frame.width, 1.5, accuracy: 0.02, "The shape holds under a corner handle")

        // A pinch on the print under the box crops closer.
        let beforePinch = kept(box)
        // Two fingers in the middle of the box, clear of its handles, on the print under it.
        box.pinch(withScale: 1.6, velocity: 1)
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertLessThan(kept(box).height, beforePinch.height, "A pinch on the print crops closer")
        XCTAssertEqual(box.frame.height / box.frame.width, 1.5, accuracy: 0.02, "The box keeps its shape")
        let saved = kept(box)

        tapInBand(app, shape(app, "4:3"))
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.height / box.frame.width, 4.0 / 3, accuracy: 0.02, "Upright carries to the next shape")
        tapInBand(app, shape(app, "Original"))
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.height / box.frame.width, 1.5, accuracy: 0.02, "Original upright on a 3:2 print")
        XCTAssertEqual(kept(box).width, saved.width, accuracy: 2)
        snapshot(app, "adjust-Disposable-original-upright")

        // Saved and opened again, the crop is as it was, and Original upright is chosen again.
        XCTAssertTrue(waitUntilEnabled(app.buttons["Save"]))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Photo 1"].waitForExistence(timeout: 20))
        tapDarkroom(app)
        openAdjust(app)
        XCTAssertEqual(kept(box).width, saved.width, accuracy: 2)
        XCTAssertTrue(shape(app, "Original").isSelected)
        XCTAssertEqual(orientation.value as? String, "Upright")
        app.buttons["Reset to Original"].tap()
        XCTAssertTrue(waitForValue(box, "100 percent of the width, 100 percent of the height"), "Reset returns the whole print")
        XCTAssertTrue(shape(app, "Freeform").isSelected)
        app.buttons["Cancel"].tap()
    }

    /// At the largest text size Adjust opens with its shapes readable in the band, under the heading, and the chosen
    /// shape is always whole in the row, which scrolls sideways there.
    func testAdjustShowsItsShapesAndTheChosenOneWholeAtTheLargestTextSize() throws {
        let app = launch(["--developed-photo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openFilm(app)
        openPhoto(app)
        tapDarkroom(app)
        openAdjust(app)
        let row = app.scrollViews["darkroom-crop-shapes"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(visibleBand(app).contains(row.frame), "The shapes open whole in the band: \(row.frame) in \(visibleBand(app))")
        XCTAssertTrue(waitForWhole(shape(app, "Freeform"), in: row), "The chosen shape opens whole in its row")
        snapshot(app, "adjust-largest-shapes-open")
        for name in ["3:2", "Original", "4:3"] {
            shape(app, name).tap()
            XCTAssertTrue(shape(app, name).isSelected, name)
            XCTAssertTrue(waitForWhole(shape(app, name), in: row), "\(name) is whole in the row once chosen")
        }
        snapshot(app, "adjust-largest-shapes-4x3")
        app.buttons["Cancel"].tap()
    }

    /// VoiceOver sets a crop by its four edges, each adjustable.
    func testTheCropBoxEdgesCanBeMovedOneAtATimeWithoutTouchingTheBox() throws {
        let app = launch(["--developed-photo"])
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 1"])
        tapDarkroom(app)
        openAdjust(app)
        for edge in ["left", "right", "top", "bottom"] {
            let element = app.descendants(matching: .any)["darkroom-crop-\(edge)"]
            XCTAssertTrue(element.exists, edge)
            XCTAssertEqual(element.label, "Crop \(edge) edge")
        }
        XCTAssertEqual(app.descendants(matching: .any)["darkroom-crop-left"].value as? String, "0 percent")
        XCTAssertEqual(app.descendants(matching: .any)["darkroom-crop-right"].value as? String, "100 percent")
        app.buttons["Cancel"].tap()
    }

    /// On the 6×6 the crop box stays square: no shapes, and every handle resizes it as a square; the straighten dial
    /// works as on the Disposable.
    func testSixBySixCropStaysSquare() throws {
        let arguments = NativePhotoRenderer.readsFilmTables ? ["--medium-format"] : ["--medium-format", "--black-and-white"]
        let app = launch(arguments + Self.evidenceArguments)
        openFilm(app)
        openPhoto(app)
        tapDarkroom(app)
        openAdjust(app)
        let box = cropBox(app)
        XCTAssertFalse(shape(app, "Square").exists, "The 6×6 offers no shapes")
        XCTAssertFalse(app.buttons["darkroom-crop-orientation"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["darkroom-straighten-dial"].exists)
        drag(app, box, corner: CGVector(dx: 1, dy: 0.5), by: CGVector(dx: -80, dy: 0))
        var square = kept(box)
        XCTAssertLessThan(square.width, 100)
        XCTAssertEqual(square.width, square.height, "An edge handle keeps it square")
        drag(app, box, corner: CGVector(dx: 0, dy: 0), by: CGVector(dx: 50, dy: 10))
        square = kept(box)
        XCTAssertEqual(square.width, square.height, "A corner handle keeps it square")
        turnDial(app, by: -60)
        XCTAssertTrue(waitUntilStill(app))
        XCTAssertEqual(box.frame.width, box.frame.height, accuracy: 1.5)
        snapshot(app, "adjust-6x6-square")
        app.buttons["Cancel"].tap()
    }

    /// The Instant keeps quarter turns only: no crop box, no dial, no shapes.
    func testInstantAdjustOnlyTurns() throws {
        let app = launch(["--instant"] + Self.evidenceArguments)
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 1"])
        tapDarkroom(app)
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 20))
        app.buttons["Adjust"].tap()
        XCTAssertTrue(app.buttons["darkroom-rotate-left"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["darkroom-rotate-right"].exists)
        XCTAssertFalse(cropBox(app).exists)
        XCTAssertFalse(app.descendants(matching: .any)["darkroom-straighten-dial"].exists)
        XCTAssertFalse(shape(app, "Freeform").exists)
        XCTAssertTrue(waitUntilStill(app))
        snapshot(app, "adjust-Instant-turns-only")
        app.buttons["darkroom-rotate-left"].tap()
        XCTAssertTrue(waitUntilEnabled(app.buttons["Save"]))
        XCTAssertTrue(waitUntilStill(app))
        snapshot(app, "adjust-Instant-turned-left")
        app.buttons["Cancel"].tap()
    }

    /// The straighten dial runs from -45° to +45° in tenths, and the print turns under the box as it moves.
    func testStraightenDialReachesBothEndsInTenths() throws {
        let app = launch(["--developed-photo"] + Self.evidenceArguments)
        openFilm(app)
        tapWhole(app, app.buttons["Open photo 1"])
        tapDarkroom(app)
        openAdjust(app)
        let dial = app.descendants(matching: .any)["darkroom-straighten-dial"]
        XCTAssertEqual(dial.label, "Straighten")
        XCTAssertEqual(dial.value as? String, "0.0 degrees")
        turnDial(app, by: -37)
        let angle = try XCTUnwrap(degrees(dial))
        XCTAssertGreaterThan(angle, 0, "Dragging the ruler left turns by more degrees")
        XCTAssertEqual(angle * 10, (angle * 10).rounded(), accuracy: 1e-9, "In tenths")
        XCTAssertTrue(waitUntilStill(app))
        snapshot(app, "adjust-Disposable-straighten")
        // The box still holds only picture: it keeps what straightening leaves, a crop of the print's own shape.
        XCTAssertEqual(cropBox(app).frame.width / cropBox(app).frame.height, 1.5, accuracy: 0.02)
        for _ in 0..<4 { turnDial(app, by: -250) }
        XCTAssertEqual(dial.value as? String, "45.0 degrees")
        for _ in 0..<8 { turnDial(app, by: 250) }
        XCTAssertEqual(dial.value as? String, "-45.0 degrees")
        app.buttons["Cancel"].tap()
    }

    // MARK: Helpers

    private struct Kept: Equatable, CustomStringConvertible {
        let width: Int
        let height: Int
        var description: String { "\(width)% × \(height)%" }
    }

    /// What the crop keeps of the print's width and height, as the box's VoiceOver value reads it.
    private func kept(_ box: XCUIElement) -> Kept {
        let numbers = (box.value as? String ?? "").split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return numbers.count == 2 ? Kept(width: numbers[0], height: numbers[1]) : Kept(width: -1, height: -1)
    }

    private func cropBox(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["darkroom-crop-box"] }

    private func shape(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons["darkroom-crop-shape-\(name)"]
    }

    private func degrees(_ dial: XCUIElement) -> Double? {
        (dial.value as? String)?.split(separator: " ").first.flatMap { Double($0) }
    }

    /// Opens Adjust and returns the print's region, read from the print before it.
    @discardableResult
    private func openAdjust(_ app: XCUIApplication) -> CGRect {
        XCTAssertTrue(app.sliders["Print exposure"].waitForExistence(timeout: 20))
        let print = app.images["Photo 1, print preview"]
        XCTAssertTrue(print.waitForExistence(timeout: 20))
        let region = print.frame
        app.buttons["Adjust"].tap()
        XCTAssertTrue(cropBox(app).waitForExistence(timeout: 20), "The crop box shows")
        XCTAssertTrue(waitUntilStill(app))
        return region
    }

    /// Presses a point of the box, such as a corner (0, 0) or the middle of the right edge (1, 0.5), and drags it.
    private func drag(_ app: XCUIApplication, _ box: XCUIElement, corner: CGVector, by offset: CGVector) {
        XCTAssertTrue(waitUntilStill(app))
        let start = box.coordinate(withNormalizedOffset: corner)
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(offset), withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(waitUntilStill(app))
    }

    /// Drags the straighten dial's ruler by `points`, left for more degrees.
    private func turnDial(_ app: XCUIApplication, by points: CGFloat) {
        let dial = app.descendants(matching: .any)["darkroom-straighten-dial"]
        scrollIntoBand(app, dial)
        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: points < 0 ? 0.9 : 0.1, dy: 0.7))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: points, dy: 0)), withVelocity: .default,
                    thenHoldForDuration: 0.3)
    }

    /// Taps a control in the Darkroom's band once it is whole in view.
    private func tapInBand(_ app: XCUIApplication, _ element: XCUIElement) {
        scrollIntoBand(app, element)
        element.tap()
    }

    /// Scrolls the Darkroom's band, where a large text size runs it past Reset to Original's bar, until `element` is
    /// whole in its visible part: held drags up from near that part's bottom in its leading margin, never free swipes.
    private func scrollIntoBand(_ app: XCUIApplication, _ element: XCUIElement) {
        for _ in 0..<8 where !visibleBand(app).contains(element.frame) {
            let visible = visibleBand(app)
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: visible.minX + 8, dy: visible.maxY - 16))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -60)), withVelocity: .slow,
                        thenHoldForDuration: 0.3)
        }
    }

    /// The part of the Darkroom's band a person sees, above Reset to Original's bar.
    private func visibleBand(_ app: XCUIApplication) -> CGRect {
        let reset = app.buttons["Reset to Original"]
        var frame = app.scrollViews["darkroom-control-band"].frame
        if reset.exists { frame.size.height = max(0, min(frame.maxY, reset.frame.minY - 4) - frame.minY) }
        return frame
    }

    /// Whether `element` comes to lie whole inside `container`, once any scrolling has settled.
    private func waitForWhole(_ element: XCUIElement, in container: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let whole = NSPredicate { _, _ in container.frame.insetBy(dx: -0.5, dy: -0.5).contains(element.frame) }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: whole, object: nil)], timeout: timeout) == .completed
    }

    private func isZoomed(_ element: XCUIElement) -> Bool { (element.value as? String) == "Zoomed in" }

    private func waitForZoom(_ element: XCUIElement, _ zoomed: Bool, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { object, _ in ((object as? XCUIElement)?.value as? String ?? "") == (zoomed ? "Zoomed in" : "") }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// The element's picture once two looks a quarter of a second apart agree, after a zoom has settled and any sharper
    /// picture has come.
    private func waitForStillPicture(of element: XCUIElement, timeout: TimeInterval = 15) -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        var last = element.screenshot().pngRepresentation
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.4)
            let now = element.screenshot().pngRepresentation
            if now == last { return now }
            last = now
        }
        return last
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

    /// `TEST_RUNNER_PHOTO_SOURCE` develops that photo instead of the synthetic one, and `TEST_RUNNER_CONTENT_SIZE` sets
    /// the text size, for the approval screenshots.
    private static var evidenceArguments: [String] {
        let environment = ProcessInfo.processInfo.environment
        return (environment["PHOTO_SOURCE"].map { ["--photo-source", $0] } ?? [])
            + (environment["CONTENT_SIZE"].map { ["-UIPreferredContentSizeCategoryName", $0] } ?? [])
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
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

    /// Opens the Film's first print, scrolling to it where a large text size puts it below the screen.
    private func openPhoto(_ app: XCUIApplication) {
        let open = app.buttons["Open photo 1"]
        for _ in 0..<12 where !open.exists { if !open.waitForExistence(timeout: 3) { app.swipeUp() } }
        XCTAssertTrue(open.exists, "The Film's first print")
        tapWhole(app, open)
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
