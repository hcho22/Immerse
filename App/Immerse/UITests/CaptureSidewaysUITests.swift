import XCTest

/// The shooting screen as a person holds the iPhone sideways (the captain, 2026-10-16: "Like iPhone Camera"): the screen
/// never turns, so the viewfinder keeps its size and place, and only the words and icons turn to read upright. Every other
/// screen keeps turning with the iPhone. The simulator has no camera, so the screen shows its message for the missing one,
/// and only what it draws without a lens is measured; the zoom pill, the sliders and the Disposable's cue, which a lens
/// raises, are in `CaptureSidewaysTests`. Loading uses the Debug testing unlock and answers a fresh Camera request
/// itself, and each test starts on an empty Journal and deletes the Film it loaded. One test per Camera shape, and the 6×6
/// again at the largest text size, to stay inside the per-test time allowance.
@MainActor
final class CaptureSidewaysUITests: ScreenTestCase {
    func testSixBySixShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "mediumFormat6x6", name: "6×6", fillsTheRoom: false)
    }

    /// The Instant's square viewfinder keeps the screen's full width where the room allows, so the room left over is
    /// shared above and below it.
    func testInstantShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "instant1970s", name: "Instant", fillsTheRoom: false)
    }

    /// The tallest viewfinder: the 2:3 box, with the error, the message and Resume Camera over it.
    func testDisposableShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "disposable1990s", name: "Disposable", fillsTheRoom: true)
    }

    func testSuper8ShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "super8HomeMovie", name: "Super 8", fillsTheRoom: true)
    }

    /// What the screen shows, measured in the window's own portrait frame.
    private struct Layout: Equatable {
        var window: CGRect
        var viewfinder: CGRect
        var done: CGRect
        var remaining: CGRect
        var shutter: CGRect
        /// The Switch Camera icon in the shutter bar, which is wider than it is tall.
        var switchCamera: CGRect
    }

    /// At the largest text size the header and the notices in it take more room than the screen has, so the screen
    /// scrolls, and held on its side the turned header is wider than the screen and scrolls across it. The viewfinder still
    /// keeps its size and place in every hold, and turned straight from one side to the other the header starts from Done.
    func testSixBySixShootingScreenKeepsItsViewfinderAtTheLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        defer { XCUIDevice.shared.orientation = .portrait }
        let title = try openShootingScreen(app, id: "mediumFormat6x6")
        defer { deleteFilm(titled: title, app) }
        let done = app.buttons["Done"]
        let upright = try wait(app)
        XCTAssertTrue(upright.window.contains(upright.done), "Done is on screen upright: \(upright.done)")
        retainFrames(upright, name: "6×6-largest", hold: "portrait")
        retainScreenshot(name: "6×6-largest-capture-portrait")
        // Each side twice, so the header turns straight from one side to the other both ways.
        for (orientation, side) in [(UIDeviceOrientation.landscapeLeft, "left"), (.landscapeRight, "right"), (.landscapeLeft, "left again")] {
            XCUIDevice.shared.orientation = orientation
            // Turned straight from one side to the other Done stays turned, so the turn has ended once Done is on the side
            // that is the header's top: the screen's right held on its left, its left held on its right.
            let turned = try wait(app) {
                $0.done.height > $0.done.width && (orientation == .landscapeLeft) == ($0.done.midX > $0.window.midX)
            }
            retainScreenshot(name: "6×6-largest-capture-\(side)")
            retainFrames(turned, name: "6×6-largest", hold: side)
            XCTAssertEqual(turned.window, upright.window, "The screen stays portrait held on its \(side)")
            XCTAssertEqual(turned.viewfinder, upright.viewfinder, "The viewfinder keeps its size and place held on its \(side)")
            XCTAssertEqual(turned.shutter, upright.shutter, "The shutter keeps its place held on its \(side)")
            XCTAssertTrue(turned.window.contains(turned.done), "The turned header starts from Done held on its \(side): \(turned.done)")
            // The shutter bar's top is 8 points above the shutter's frame.
            XCTAssertLessThanOrEqual(turned.done.maxY, turned.shutter.minY - 8, "Done is clear of the shutter bar held on its \(side)")
            XCTAssertTrue(done.isHittable, "Done can be tapped held on its \(side)")
        }
        XCUIDevice.shared.orientation = .portrait
        let upAgain = try wait(app) { $0.done.width > $0.done.height }
        XCTAssertEqual(upAgain.viewfinder, upright.viewfinder, "The viewfinder is where it was held upright")
        done.tap()
        XCTAssertTrue(done.isGone(within: 5), "The shooting screen closed")
    }

    /// Loads a Film in the Camera `id` with the title Load Film suggests, opens its shooting screen, waits for the camera's
    /// open to end in the missing camera's error and Resume Camera, and returns the Film's title, for the caller to delete
    /// it. The notices come in their own time and never move a frame `wait(_:until:)` reads, so its settling cannot see them.
    private func openShootingScreen(_ app: XCUIApplication, id: String) throws -> String {
        app.launchArguments += ["-ImmerseDebugTestingUnlock", "YES"]
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
        openCameraCatalog(app)
        let camera = app.buttons["camera-\(id)"]
        tapWhole(app, camera)
        XCTAssertTrue(camera.waitForNonExistence(timeout: 5))
        // Loads with the title Load Film suggests, so no keyboard covers the screen on a small iPhone.
        let field = app.textFields["film-title"]
        scrollUp(app, until: field)
        let title = try XCTUnwrap(field.value as? String)
        let load = app.buttons["load-film"]
        tapWhole(app, load)
        let detail = app.navigationBars[title]
        for _ in 0..<20 {
            if detail.exists { break }
            app.navigationBars.firstMatch.tap()
            _ = detail.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(load.waitForNonExistence(timeout: 5), "The Load screen closed")
        XCTAssertTrue(allowed, "Load Film asks for Camera access")

        tapWhole(app, app.buttons["Open Camera"])
        XCTAssertTrue(app.buttons["Done"].exists(within: 5))
        XCTAssertTrue(app.buttons["Resume Camera"].exists(within: 30), "The camera's open ended")
        return title
    }

    /// `fillsTheRoom`: the Camera's viewfinder is taller than it is wide, so the room above the shutter bar, not the screen's
    /// width, sets its size, and it ends just above the bar.
    private func check(id: String, name: String, fillsTheRoom: Bool) throws {
        let app = XCUIApplication()
        defer { XCUIDevice.shared.orientation = .portrait }
        let title = try openShootingScreen(app, id: id)
        defer { deleteFilm(titled: title, app) }
        let detail = app.navigationBars[title]
        let done = app.buttons["Done"]
        let upright = try wait(app)
        XCTAssertLessThan(upright.window.width, upright.window.height, "The shooting screen is portrait")
        XCTAssertGreaterThan(upright.remaining.width, upright.remaining.height, "Upright, the count reads across")
        XCTAssertGreaterThan(upright.switchCamera.width, upright.switchCamera.height, "Upright, Switch Camera reads across")
        try checkFits(upright, app, "upright", fillsTheRoom: fillsTheRoom)
        // Held upright, Done sits just below the status bar on every Camera and every iPhone, with the name and the count
        // right under it, whatever room the viewfinder leaves.
        XCTAssertLessThanOrEqual(upright.done.minY, upright.window.minY + 90, "Done is just below the status bar")
        XCTAssertLessThanOrEqual(upright.remaining.minY - upright.done.maxY, 70, "The name and the count follow Done closely")
        retainFrames(upright, name: name, hold: "portrait")
        retainScreenshot(name: "\(name)-capture-portrait")

        for (orientation, side) in [(UIDeviceOrientation.landscapeLeft, "left"), (.landscapeRight, "right")] {
            XCUIDevice.shared.orientation = orientation
            // The words turn with an animation, and the screen must not turn at all.
            let turned = try wait(app) { $0.remaining.height > $0.remaining.width }
            retainScreenshot(name: "\(name)-capture-\(side)")
            XCTAssertEqual(turned.window, upright.window, "The screen stays portrait held on its \(side)")
            XCTAssertEqual(turned.viewfinder, upright.viewfinder, "The viewfinder keeps its size and place held on its \(side)")
            XCTAssertEqual(turned.shutter, upright.shutter, "The shutter keeps its place held on its \(side)")
            try checkFits(turned, app, side, fillsTheRoom: fillsTheRoom)
            retainFrames(turned, name: name, hold: side)
            XCTAssertGreaterThan(turned.remaining.height, turned.remaining.width, "The count turns to read upright")
            XCTAssertGreaterThan(turned.switchCamera.height, turned.switchCamera.width,
                                 "Switch Camera, in the shutter bar, turns to read upright held on its \(side)")
            XCTAssertTrue(done.isHittable, "Done can be tapped held on its \(side)")
            XCTAssertGreaterThanOrEqual(turned.done.height, 44, "Done keeps a tap target of 44 points turned")
            XCTAssertGreaterThanOrEqual(turned.done.width, 44, "Done keeps a tap target of 44 points turned")
            for (label, frame) in [("Done", turned.done), ("count", turned.remaining)] {
                XCTAssertTrue(turned.window.contains(frame), "\(label) is on screen held on its \(side): \(frame)")
                XCTAssertFalse(frame.intersects(turned.viewfinder), "\(label) stays off the viewfinder held on its \(side)")
            }
            XCTAssertFalse(turned.done.intersects(turned.remaining), "Done and the count do not overlap held on its \(side)")
        }

        // The hold ends with the screen: Film's screen turns with the iPhone again. XCTest taps in the device's own frame, so
        // Done is tapped with the iPhone held upright.
        XCUIDevice.shared.orientation = .portrait
        let upAgain = try wait(app) { $0.remaining.width > $0.remaining.height }
        XCTAssertEqual(upAgain.viewfinder, upright.viewfinder, "The viewfinder is where it was held upright")
        done.tap()
        XCTAssertTrue(done.isGone(within: 5), "The shooting screen closed")
        XCTAssertTrue(detail.exists(within: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        let turns = NSPredicate { _, _ in window.frame.width > window.frame.height }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: turns, object: nil)], timeout: 10), .completed,
                       "The Film screen turns with the iPhone once the shooting screen is gone")
        retainScreenshot(name: "\(name)-film-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    /// What was measured, kept with the run: the viewfinder's frame and the room above the shutter bar, in each hold.
    private func retainFrames(_ layout: Layout, name: String, hold: String) {
        let text = "window \(layout.window.size.debugDescription), viewfinder \(layout.viewfinder), shutter \(layout.shutter)"
        let attachment = XCTAttachment(string: text)
        attachment.name = "frames-\(name)-\(hold)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The whole viewfinder shows above the shutter bar, and everything drawn in it, the notices and their buttons, lies
    /// within it: a frame that reaches past its box is text the box cuts off.
    private func checkFits(_ layout: Layout, _ app: XCUIApplication, _ hold: String, fillsTheRoom: Bool) throws {
        XCTAssertLessThanOrEqual(layout.viewfinder.maxY, layout.shutter.minY, "The whole viewfinder is above the shutter bar, \(hold)")
        XCTAssertGreaterThanOrEqual(layout.viewfinder.minX, layout.window.minX, "The viewfinder is within the screen, \(hold)")
        XCTAssertLessThanOrEqual(layout.viewfinder.maxX, layout.window.maxX, "The viewfinder is within the screen, \(hold)")
        if fillsTheRoom {
            // The shutter bar's top is 8 points above the shutter's frame, and the column leaves 12 above the bar.
            XCTAssertLessThanOrEqual(layout.shutter.minY - layout.viewfinder.maxY, 40,
                                     "The viewfinder takes the room above the shutter bar, \(hold)")
        }
        let viewfinder = app.otherElements["viewfinder"]
        let inside = layout.viewfinder.insetBy(dx: -1, dy: -1)
        for element in viewfinder.staticTexts.allElementsBoundByIndex + viewfinder.buttons.allElementsBoundByIndex {
            XCTAssertTrue(inside.contains(element.frame), "\(element.label) is not cut off by the viewfinder, \(hold): \(element.frame) in \(layout.viewfinder)")
        }
        XCTAssertGreaterThan(viewfinder.buttons["Resume Camera"].frame.height, 0, "Resume Camera is over the viewfinder, \(hold)")
    }

    private func layout(_ app: XCUIApplication) throws -> Layout {
        let viewfinder = app.otherElements["viewfinder"]
        XCTAssertTrue(viewfinder.exists(within: 5), "The viewfinder is on screen")
        let remaining = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " left")).firstMatch
        XCTAssertTrue(remaining.exists(within: 5), "What is left shows")
        let shutter = app.buttons["capture-shutter"]
        XCTAssertTrue(shutter.exists(within: 5))
        return Layout(window: app.windows.firstMatch.frame, viewfinder: viewfinder.frame, done: app.buttons["Done"].frame,
                      remaining: remaining.frame, shutter: shutter.frame, switchCamera: app.buttons["Switch Camera"].frame)
    }

    /// The layout once `settled` holds and two reads half a second apart agree, so a turn's animation, or the screen's
    /// own coming up, has ended. Each read used to wait a second for each of three elements that were already there, which
    /// let the screen settle by accident; the settling is asked for here instead, and the camera's open, which moves none of
    /// these frames, in `openShootingScreen`. It gives up after 30 s and returns what it last read, for the caller's
    /// assertions to fail on.
    private func wait(_ app: XCUIApplication, until settled: (Layout) -> Bool = { _ in true }) throws -> Layout {
        var latest = try layout(app)
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
            let next = try layout(app)
            if settled(next) && next == latest { return next }
            latest = next
        }
        return latest
    }

    private func retainScreenshot(name: String) {
        let attachment = XCTAttachment(image: XCUIScreen.main.uprightScreenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
