import XCTest

/// The shooting screen as a person holds the iPhone sideways (the captain, 2026-10-16: "Like iPhone Camera"): the screen
/// never turns, so the viewfinder keeps its size and place, and only the words and icons turn to read upright. Every other
/// screen keeps turning with the iPhone. The simulator has no camera, so the screen shows its message for the missing one,
/// and only what it draws without a lens is measured; the zoom pill, the sliders and the Disposable's cue, which a lens
/// raises, are in `CaptureSidewaysTests`. Develop at once is on for each launch, as in a Debug build by default, so the
/// Cameras it changes show its notice beside Done (`DevelopedPreviews`). Loading uses the Debug testing unlock and answers a fresh Camera request
/// itself, and each test starts on an empty Journal and deletes the Film it loaded. One test per Camera, the 6×6
/// again at the largest text size and the Disposable with Develop at once off, to stay inside the per-test time allowance.
@MainActor
final class CaptureSidewaysUITests: ScreenTestCase {
    func testSixBySixShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "mediumFormat6x6", name: "6×6")
    }

    func testDisposableFocusSwitchShowsAutoAndFixedInsideTheViewfinderBand() throws {
        let app = XCUIApplication()
        let title = try openShootingScreen(app, id: "disposable1990s", developsAtOnce: false)
        defer { deleteFilm(titled: title, app) }

        let focusMode = app.segmentedControls["capture-focus-mode"]
        XCTAssertTrue(focusMode.exists(within: 10), "The Disposable offers its per-Film focus switch")
        let layout = try wait(app)
        XCTAssertTrue(layout.viewfinder.contains(focusMode.frame), "The focus switch stays in the floating control band")
        let automatic = focusMode.buttons["Auto"]
        let fixed = focusMode.buttons["Fixed"]
        XCTAssertTrue(automatic.exists)
        XCTAssertTrue(fixed.exists)
        XCTAssertEqual(focusMode.value as? String, "Auto", "A new Film starts on Auto")

        tapWhole(app, fixed)
        let selectedFixed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Fixed"), object: focusMode)
        XCTAssertEqual(XCTWaiter().wait(for: [selectedFixed], timeout: 5), .completed,
                       "The Film keeps the selected Fixed mode")
    }

    func testInstantShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "instant1970s", name: "Instant", showsNotice: false)
    }

    func testDisposableShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "disposable1990s", name: "Disposable")
    }

    func testSuper8ShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "super8HomeMovie", name: "Super 8")
    }

    func testSixteenMillimeterShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "cinema16mm", name: "16mm")
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
        /// Develop at once's notice, where it shows.
        var notice: CGRect?
    }

    /// At the largest text size the one-line header stays fixed while the full Viewfinder area keeps its size and place.
    /// Held on its side, the header turns across the Viewfinder area, and turned straight from one side to the other it
    /// starts from Done.
    func testSixBySixShootingScreenKeepsItsViewfinderAtTheLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        defer { XCUIDevice.shared.orientation = .portrait }
        let title = try openShootingScreen(app, id: "mediumFormat6x6", developsAtOnce: false)
        defer { deleteFilm(titled: title, app) }
        let done = app.buttons["Done"]
        let upright = try wait(app)
        XCTAssertEqual(app.descendants(matching: .any)["capture-header-status"].label, "6 by 6, 12 exposures left")
        XCTAssertTrue(upright.window.contains(upright.done), "Done is on screen upright: \(upright.done)")
        XCTAssertTrue(upright.window.contains(upright.remaining), "The Camera name and count are on screen upright")
        checkNotice(upright, shows: false, "upright at the largest text size")
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
            XCTAssertTrue(turned.window.contains(turned.remaining), "The Camera name and count stay visible held on its \(side)")
            XCTAssertTrue(turned.remaining.intersects(turned.viewfinder), "The one-line header extends along the fixed Viewfinder area")
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

    /// With Develop at once off, as the captain turns it off in Settings to test the real experience, the shooting screen
    /// has no notice, as in a Release build; turned on again it shows the notice, and the viewfinder is where it was.
    func testTheDevelopAtOnceNoticeShowsOnlyWhileTheSwitchIsOnAndLeavesTheViewfinderInPlace() throws {
        let app = XCUIApplication()
        let title = try openShootingScreen(app, id: "disposable1990s", developsAtOnce: false)
        defer { deleteFilm(titled: title, app) }
        let off = try wait(app)
        checkNotice(off, shows: false, "with the switch off")
        retainScreenshot(name: "Disposable-develop-at-once-off")

        app.terminate()
        let flag = try XCTUnwrap(app.launchArguments.firstIndex(of: "-ImmerseDebugDevelopedPreview"))
        app.launchArguments[flag + 1] = "YES"
        app.launch()
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.exists(within: 10), "The Film is in the Journal")
        tapWhole(app, row)
        XCTAssertTrue(row.isGone(within: 10), "The Film's screen opened")
        openCamera(app)
        let on = try wait(app)
        checkNotice(on, shows: true, "with the switch on")
        retainScreenshot(name: "Disposable-develop-at-once-on")
        XCTAssertEqual(on.viewfinder, off.viewfinder, "The notice leaves the viewfinder where it is")
        XCTAssertEqual(on.done, off.done, "The notice leaves Done where it is")
        XCTAssertEqual(on.remaining, off.remaining, "The notice leaves the count where it is")
    }

    /// Loads a Film in the Camera `id` with the title Load Film suggests, with Develop at once on or off for the launch as
    /// `developsAtOnce` says, whatever Settings holds, opens its shooting screen, waits for the camera's open to end in the
    /// missing camera's "Camera unavailable." error, and returns the Film's title, for the caller to delete it. Resume
    /// Camera shows from the screen's first frame, before the open ends, so only the error marks that end.
    /// Over the viewfinder the error moves no frame `wait(_:until:)` reads, and the one-line header never moves the area,
    /// so in both the screen is read only after the camera's open ends.
    private func openShootingScreen(_ app: XCUIApplication, id: String, developsAtOnce: Bool = true) throws -> String {
        app.launchArguments += ["-ImmerseDebugTestingUnlock", "YES",
                                "-ImmerseDebugDevelopedPreview", developsAtOnce ? "YES" : "NO"]
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
        openCamera(app)
        return title
    }

    /// Opens the shooting screen from the Film's screen and waits for the camera's open to end in the missing camera's
    /// "Camera unavailable." error.
    private func openCamera(_ app: XCUIApplication) {
        let open = app.buttons["Open Camera"]
        XCTAssertTrue(open.exists(within: 10), "The Film's screen offers Open Camera")
        tapWhole(app, open)
        XCTAssertTrue(app.buttons["Done"].exists(within: 5))
        let unavailable = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Camera unavailable.")).firstMatch
        XCTAssertTrue(unavailable.exists(within: 30), "The camera's open ended")
    }

    private func check(id: String, name: String, showsNotice: Bool = true) throws {
        let app = XCUIApplication()
        defer { XCUIDevice.shared.orientation = .portrait }
        let title = try openShootingScreen(app, id: id)
        defer { deleteFilm(titled: title, app) }
        let detail = app.navigationBars[title]
        let done = app.buttons["Done"]
        let upright = try wait(app)
        let oldName = switch id {
        case "disposable1990s": "1990s Disposable"
        case "instant1970s": "1970s Instant"
        case "mediumFormat6x6": "6×6 Medium Format"
        case "super8HomeMovie": "1960s Super 8 Home Movie"
        default: "16mm Cinema"
        }
        let headerStatus = app.descendants(matching: .any)["capture-header-status"]
        XCTAssertTrue(headerStatus.exists, "The one-line Camera name and count show")
        XCTAssertEqual(headerStatus.label, expectedSpokenHeader(for: id), "VoiceOver gets the Camera name and full count")
        XCTAssertFalse(headerStatus.label.contains(oldName), "The shooting screen does not speak the stored package name")
        XCTAssertLessThan(upright.window.width, upright.window.height, "The shooting screen is portrait")
        XCTAssertGreaterThan(upright.remaining.width, upright.remaining.height, "Upright, the count reads across")
        XCTAssertGreaterThan(upright.switchCamera.width, upright.switchCamera.height, "Upright, Switch Camera reads across")
        try checkFits(upright, app, "upright")
        checkNotice(upright, shows: showsNotice, "upright")
        // Held upright, Done, the Camera name and its count share one line below the status bar.
        XCTAssertLessThanOrEqual(upright.done.minY, upright.window.minY + 90, "Done is just below the status bar")
        XCTAssertEqual(upright.remaining.midY, upright.done.midY, accuracy: 12, "The count shares Done's header line")
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
            try checkFits(turned, app, side)
            checkNotice(turned, shows: showsNotice, "held on its \(side)")
            retainFrames(turned, name: name, hold: side)
            XCTAssertGreaterThan(turned.remaining.height, turned.remaining.width, "The count turns to read upright")
            XCTAssertTrue(turned.remaining.intersects(turned.viewfinder),
                          "The one-line header extends along the fixed Viewfinder area, held on its \(side)")
            XCTAssertGreaterThan(turned.switchCamera.height, turned.switchCamera.width,
                                 "Switch Camera, in the shutter bar, turns to read upright held on its \(side)")
            XCTAssertTrue(done.isHittable, "Done can be tapped held on its \(side)")
            XCTAssertGreaterThanOrEqual(turned.done.height, 44, "Done keeps a tap target of 44 points turned")
            XCTAssertGreaterThanOrEqual(turned.done.width, 44, "Done keeps a tap target of 44 points turned")
            for (label, frame) in [("Done", turned.done), ("count", turned.remaining)] {
                XCTAssertTrue(turned.window.contains(frame), "\(label) is on screen held on its \(side): \(frame)")
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

    /// The area is full width and four thirds as tall on every Camera and in every hold. Notices and buttons drawn over it
    /// remain inside its frame.
    private func checkFits(_ layout: Layout, _ app: XCUIApplication, _ hold: String) throws {
        XCTAssertEqual(layout.viewfinder.minX, layout.window.minX, accuracy: 1,
                       "The viewfinder area starts at the screen edge, \(hold)")
        XCTAssertEqual(layout.viewfinder.width, layout.window.width, accuracy: 1,
                       "The viewfinder area is full width, \(hold)")
        XCTAssertEqual(layout.viewfinder.height, layout.window.width * 4 / 3, accuracy: 1,
                       "The viewfinder area is four thirds as tall as it is wide, \(hold)")
        XCTAssertLessThanOrEqual(layout.viewfinder.maxY, layout.shutter.minY,
                                 "The visible viewfinder area ends above the shutter bar, \(hold)")
        let viewfinder = app.otherElements["viewfinder"]
        let inside = layout.viewfinder.insetBy(dx: -1, dy: -1)
        for element in viewfinder.staticTexts.allElementsBoundByIndex + viewfinder.buttons.allElementsBoundByIndex {
            XCTAssertTrue(inside.contains(element.frame), "\(element.label) is not cut off by the viewfinder, \(hold): \(element.frame) in \(layout.viewfinder)")
        }
        XCTAssertGreaterThan(viewfinder.buttons["Resume Camera"].frame.height, 0, "Resume Camera is over the viewfinder, \(hold)")
    }

    /// Develop at once's notice stays beside Done in the one-line header, clear of the shutter bar's buttons and the
    /// Camera name and count.
    private func checkNotice(_ layout: Layout, shows: Bool, _ hold: String) {
        guard shows else { return XCTAssertNil(layout.notice, "No Develop at once notice, \(hold)") }
        guard let notice = layout.notice else { return XCTFail("The Develop at once notice shows, \(hold)") }
        XCTAssertTrue(layout.window.contains(notice), "The notice is on screen, \(hold): \(notice)")
        for (label, frame) in [("shutter", layout.shutter), ("Switch Camera", layout.switchCamera),
                               ("Done", layout.done), ("Camera name and count", layout.remaining)] {
            XCTAssertFalse(notice.intersects(frame), "The notice is clear of the \(label), \(hold): \(notice) and \(frame)")
        }
    }

    private func layout(_ app: XCUIApplication) throws -> Layout {
        let viewfinder = app.otherElements["viewfinder"]
        XCTAssertTrue(viewfinder.exists(within: 5), "The viewfinder is on screen")
        let remaining = app.descendants(matching: .any)["capture-header-status"]
        XCTAssertTrue(remaining.exists(within: 5), "The Camera name and count show")
        let shutter = app.buttons["capture-shutter"]
        XCTAssertTrue(shutter.exists(within: 5))
        let notice = app.descendants(matching: .any)["develop-at-once-notice"]
        return Layout(window: app.windows.firstMatch.frame, viewfinder: viewfinder.frame, done: app.buttons["Done"].frame,
                      remaining: remaining.frame, shutter: shutter.frame, switchCamera: app.buttons["Switch Camera"].frame,
                      notice: notice.exists ? notice.frame : nil)
    }

    private func expectedSpokenHeader(for id: String) -> String {
        switch id {
        case "disposable1990s": "Disposable, 27 exposures left"
        case "instant1970s": "Instant, 10 exposures left"
        case "mediumFormat6x6": "6 by 6, 12 exposures left"
        case "super8HomeMovie": "Super 8, 3 minutes 20 seconds left"
        default: "16mm, 2 minutes 47 seconds left"
        }
    }

    /// The layout once `settled` holds and two reads half a second apart agree, so a turn's animation, or the screen's
    /// own coming up, has ended. Each read used to wait a second for each of three elements that were already there, which
    /// let the screen settle by accident; the settling is asked for here instead, and the end of the camera's open in
    /// `openShootingScreen`, since two equal reads can both come before it. It gives up after 30 s and returns what it last
    /// read, for the caller's assertions to fail on.
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
