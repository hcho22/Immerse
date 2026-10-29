import XCTest

/// The shooting screen as a person holds the iPhone sideways (the captain, 2026-10-16: "Like iPhone Camera"): the screen
/// never turns, so the viewfinder keeps its size and place, and only the words and icons turn to read upright. The top bar
/// stays above the viewfinder with Done and the count turned in place in its corners (2026-10-29, "5A"), and the focus
/// switch sits in the control strip under the viewfinder ("4A"). The photo view turns with the iPhone; Darkroom stays
/// portrait. The simulator has no camera, so the screen shows its message for the missing one, and only what it draws
/// without a lens is measured; the Zoom Steps, the 6×6's sliders and the Disposable's cue, which a lens raises, are in
/// `CaptureSidewaysTests`. Develop at once is on for each launch, as in a Debug build by default, so the
/// Cameras it changes show its notice beside Done (`DevelopedPreviews`). Loading uses the Debug testing unlock; opening
/// the shooting screen answers fresh Camera and microphone requests, and each test starts on an empty Journal and deletes
/// the Film it loaded. Each Camera is checked at the default text size, and again at the largest size for the approval
/// screenshots; the Disposable also runs with Develop at once off, the Super 8 with microphone access denied and the 6×6
/// in Manual.
@MainActor
final class CaptureSidewaysUITests: ScreenTestCase {
    private var microphonePromptWasDeclined = false

    func testSixBySixShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "mediumFormat6x6", name: "6×6")
    }

    func testDisposableFocusSwitchShowsAutoAndFixedInTheStripUnderTheViewfinder() throws {
        let app = XCUIApplication()
        let title = try openShootingScreen(app, id: "disposable1990s", developsAtOnce: false)
        defer { deleteFilm(titled: title, app) }

        let focusMode = app.descendants(matching: .any)["capture-focus-mode"]
        XCTAssertTrue(focusMode.exists(within: 10), "The Disposable offers its per-Film focus switch")
        let layout = try wait(app)
        checkFocusSwitch(layout, app, "upright")
        // VoiceOver reads it as one control, "Focus, Auto" (FR-25).
        XCTAssertEqual(focusMode.label, "Focus")
        XCTAssertEqual(focusMode.value as? String, "Auto", "A new Film starts on Auto")
        retainScreenshot(name: "focus-switch-placement-Disposable-Auto")

        // A touch on each half chooses its setting.
        focusMode.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        let selectedFixed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Fixed"), object: focusMode)
        XCTAssertEqual(XCTWaiter().wait(for: [selectedFixed], timeout: 5), .completed,
                       "The Film keeps the selected Fixed mode")
        focusMode.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        let selectedAuto = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Auto"), object: focusMode)
        XCTAssertEqual(XCTWaiter().wait(for: [selectedAuto], timeout: 5), .completed, "Auto can be chosen again")
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

    func testDisposableShootingScreenKeepsItsLayoutAtTheLargestTextSize() throws {
        try check(id: "disposable1990s", name: "Disposable", largest: true)
    }

    func testInstantShootingScreenKeepsItsLayoutAtTheLargestTextSize() throws {
        try check(id: "instant1970s", name: "Instant", showsNotice: false, largest: true)
    }

    func testSuper8ShootingScreenKeepsItsLayoutAtTheLargestTextSize() throws {
        try check(id: "super8HomeMovie", name: "Super 8", largest: true)
    }

    func testSixteenMillimeterShootingScreenKeepsItsLayoutAtTheLargestTextSize() throws {
        try check(id: "cinema16mm", name: "16mm", largest: true)
    }

    func testNewSuper8AsksForMicrophoneAndDecliningShowsThatClipsWillBeSilent() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        let title = try openShootingScreen(app, id: "super8HomeMovie", developsAtOnce: false, declineMicrophone: true)
        defer { deleteFilm(titled: title, app) }
        XCTAssertTrue(microphonePromptWasDeclined, "Opening the new Movie Camera asks for microphone access")
        let note = app.descendants(matching: .any)["microphone-permission-note"]
        XCTAssertTrue(note.exists(within: 10), "The microphone denial is a notice over the fixed Viewfinder area")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(note.frame), "The silent-recording notice fits at the largest text size")
        try checkNoticeShowsWholeInEveryHold(app, name: "Super8-microphone-declined")
    }

    /// In Manual the 6×6 adds its Focus button beside the switch. At the largest text size the switch stays in the strip
    /// and the camera's notice still shows whole over the area in every hold.
    func testSixBySixInManualShowsTheWholeNoticeAtTheLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        defer { XCUIDevice.shared.orientation = .portrait }
        let title = try openShootingScreen(app, id: "mediumFormat6x6")
        defer { deleteFilm(titled: title, app) }
        let focusMode = app.descendants(matching: .any)["capture-focus-mode"]
        XCTAssertTrue(focusMode.exists(within: 10), "The 6×6 offers its focus switch")
        focusMode.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        let manual = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Manual"), object: focusMode)
        XCTAssertEqual(XCTWaiter().wait(for: [manual], timeout: 5), .completed, "The Film is in Manual")
        try checkNoticeShowsWholeInEveryHold(app, name: "6×6-Manual-largest")
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
        /// The focus switch, on the Cameras that have one.
        var focusSwitch: CGRect?
    }

    /// At the largest text size the top bar stays fixed while the full Viewfinder area keeps its size and place. Held on its
    /// side, Done and the count turn in place in the bar's corners, also turned straight from one side to the other.
    func testSixBySixShootingScreenKeepsItsViewfinderAtTheLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        defer { XCUIDevice.shared.orientation = .portrait }
        let title = try openShootingScreen(app, id: "mediumFormat6x6")
        defer { deleteFilm(titled: title, app) }
        let done = app.buttons["Done"]
        let upright = try wait(app)
        XCTAssertEqual(app.descendants(matching: .any)["capture-header-status"].label, "6 by 6, 12 exposures left")
        XCTAssertTrue(upright.window.contains(upright.done), "Done is on screen upright: \(upright.done)")
        XCTAssertTrue(upright.window.contains(upright.remaining), "The Camera name and count are on screen upright")
        checkNotice(upright, shows: true, "upright at the largest text size")
        checkNoticeShowsWhole(upright, app, "upright at the largest text size")
        retainFrames(upright, name: "6×6-largest", hold: "portrait")
        retainScreenshot(name: "6×6-largest-capture-portrait")
        // Each side twice, so the header turns straight from one side to the other both ways.
        for (orientation, side) in [(UIDeviceOrientation.landscapeLeft, "left"), (.landscapeRight, "right"), (.landscapeLeft, "left again")] {
            XCUIDevice.shared.orientation = orientation
            // Turned straight from one side to the other the count stays turned, so the reads that agree are taken after
            // the turn has ended.
            let turned = try wait(app) { $0.remaining.height > $0.remaining.width }
            retainScreenshot(name: "6×6-largest-capture-\(side)")
            retainFrames(turned, name: "6×6-largest", hold: side)
            XCTAssertEqual(turned.window, upright.window, "The screen stays portrait held on its \(side)")
            XCTAssertEqual(turned.viewfinder, upright.viewfinder, "The viewfinder keeps its size and place held on its \(side)")
            XCTAssertEqual(turned.shutter, upright.shutter, "The shutter keeps its place held on its \(side)")
            checkTopBar(turned, upright: upright, "held on its \(side) at the largest text size")
            XCTAssertEqual(turned.focusSwitch, upright.focusSwitch, "The focus switch keeps its place held on its \(side)")
            XCTAssertTrue(done.isHittable, "Done can be tapped held on its \(side)")
            checkNoticeShowsWhole(turned, app, "held on its \(side) at the largest text size")
        }
        XCUIDevice.shared.orientation = .portrait
        let upAgain = try wait(app) { $0.remaining.width > $0.remaining.height }
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
        // Held on its side the notice is its hammer alone, turned in place beside Done in the top bar.
        for (orientation, side) in [(UIDeviceOrientation.landscapeLeft, "left"), (.landscapeRight, "right")] {
            XCUIDevice.shared.orientation = orientation
            let turned = try wait(app) { $0.remaining.height > $0.remaining.width }
            retainScreenshot(name: "Disposable-develop-at-once-on-\(side)")
            checkNotice(turned, shows: true, "held on its \(side)")
            checkTopBar(turned, upright: on, "held on its \(side) with Develop at once on")
        }
        XCUIDevice.shared.orientation = .portrait
        _ = try wait(app) { $0.remaining.width > $0.remaining.height }
    }

    /// Loads a Film in the Camera `id` with the title Load Film suggests, with Develop at once on or off for the launch as
    /// `developsAtOnce` says, whatever Settings holds, opens its shooting screen, and waits for startup to finish in either
    /// the simulator's unavailable-camera error or an enabled shutter. It returns the Film's title for the caller to delete it.
    /// Over the viewfinder the error moves no frame `wait(_:until:)` reads, and the one-line header never moves the area,
    /// so in both the screen is read only after the camera's open ends.
    private func openShootingScreen(_ app: XCUIApplication, id: String, developsAtOnce: Bool = true,
                                   declineMicrophone: Bool = false) throws -> String {
        app.launchArguments += ["-ImmerseDebugTestingUnlock", "YES",
                                "-ImmerseDebugDevelopedPreview", developsAtOnce ? "YES" : "NO"]
        app.resetAuthorizationStatus(for: .camera)
        app.resetAuthorizationStatus(for: .microphone)
        var cameraAllowed = false
        microphonePromptWasDeclined = false
        let monitor = addUIInterruptionMonitor(withDescription: "Camera and microphone requests") { [weak self] alert in
            let allow = alert.buttons["Allow"]
            if alert.label.localizedCaseInsensitiveContains("Camera"), allow.exists {
                allow.tap()
                cameraAllowed = true
                return true
            }
            guard alert.label.localizedCaseInsensitiveContains("Microphone") else { return false }
            if declineMicrophone {
                let deny = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Don't Allow")).firstMatch
                guard deny.exists else { return false }
                deny.tap()
                self?.microphonePromptWasDeclined = true
            } else {
                guard allow.exists else { return false }
                allow.tap()
            }
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
        let movieCameraRequestsMicrophone = id == "super8HomeMovie" || id == "cinema16mm"
        openCamera(app, resolveMicrophonePrompt: declineMicrophone,
                   expectsMicrophonePrompt: movieCameraRequestsMicrophone)
        XCTAssertTrue(cameraAllowed, "Opening the shooting screen asks for Camera access")
        return title
    }

    /// Opens the shooting screen, handles its microphone prompt, resumes if the permission sheet paused the Camera, and
    /// waits for startup to finish in either the simulator's unavailable-camera error or an enabled shutter.
    private func openCamera(_ app: XCUIApplication, resolveMicrophonePrompt: Bool = false,
                            expectsMicrophonePrompt: Bool = false) {
        let open = app.buttons["Open Camera"]
        XCTAssertTrue(open.exists(within: 10), "The Film's screen offers Open Camera")
        tapWhole(app, open)
        if expectsMicrophonePrompt {
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let alert = springboard.alerts.firstMatch
            XCTAssertTrue(alert.exists(within: 30), "The first shooting-screen open asks for microphone access")
            XCTAssertTrue(alert.label.localizedCaseInsensitiveContains("Microphone"), alert.label)
            if resolveMicrophonePrompt {
                let deny = alert.buttons.matching(NSPredicate(
                    format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Don't Allow", "Don’t Allow"
                )).firstMatch
                XCTAssertTrue(deny.exists, "The microphone prompt offers Don't Allow")
                deny.tap()
                microphonePromptWasDeclined = true
            } else {
                let allow = alert.buttons["Allow"]
                XCTAssertTrue(allow.exists, "The microphone prompt offers Allow")
                allow.tap()
            }
        }
        XCTAssertTrue(app.buttons["Done"].exists(within: 5))
        let unavailable = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Camera unavailable.")).firstMatch
        let shutter = app.buttons["capture-shutter"]
        let openEnded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            unavailable.exists || (shutter.exists && shutter.isEnabled)
        }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [openEnded], timeout: 30), .completed,
                       "The camera's open ended in an error or a usable shutter")
        if expectsMicrophonePrompt {
            // iOS makes the app inactive while it asks, which pauses the camera; the open that asked goes on to start
            // the camera after the answer (S1), so it ends on the simulator's missing camera, never on a paused one.
            XCTAssertTrue(unavailable.exists, "The open went on to start the camera after the microphone question")
            let paused = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Camera paused")).firstMatch
            XCTAssertFalse(paused.exists, "The microphone question does not leave the camera paused")
        }
    }

    private func check(id: String, name: String, showsNotice: Bool = true, largest: Bool = false) throws {
        let app = XCUIApplication()
        if largest { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
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
        checkFocusSwitch(upright, app, "upright")
        checkNoticeShowsWhole(upright, app, "upright")
        // Held upright, Done, the Camera name and its count share the top bar below the status bar.
        XCTAssertLessThanOrEqual(upright.done.minY, upright.window.minY + 90, "Done is just below the status bar")
        XCTAssertLessThanOrEqual(upright.done.maxY, upright.viewfinder.minY + 0.5, "Done stays in the top bar, above the area")
        XCTAssertEqual(upright.remaining.midY, upright.done.midY, accuracy: 12, "The count shares Done's header line")
        XCTAssertGreaterThanOrEqual(upright.remaining.width, 40,
                                    "The Camera name and count remain visible on one line at every text size")
        let screenshotName = "\(name)-\(largest ? "largest" : "default")"
        retainFrames(upright, name: screenshotName, hold: "portrait")
        retainScreenshot(name: "\(screenshotName)-capture-portrait")

        for (orientation, side) in [(UIDeviceOrientation.landscapeLeft, "left"), (.landscapeRight, "right")] {
            XCUIDevice.shared.orientation = orientation
            // The words turn with an animation, and the screen must not turn at all.
            let turned = try wait(app) { $0.remaining.height > $0.remaining.width }
            retainScreenshot(name: "\(screenshotName)-capture-\(side)")
            XCTAssertEqual(turned.window, upright.window, "The screen stays portrait held on its \(side)")
            XCTAssertEqual(turned.viewfinder, upright.viewfinder, "The viewfinder keeps its size and place held on its \(side)")
            XCTAssertEqual(turned.shutter, upright.shutter, "The shutter keeps its place held on its \(side)")
            try checkFits(turned, app, side)
            checkNotice(turned, shows: showsNotice, "held on its \(side)")
            retainFrames(turned, name: screenshotName, hold: side)
            XCTAssertEqual(headerStatus.label, expectedSpokenHeader(for: id),
                           "VoiceOver still gets the Camera name and full count held on its \(side)")
            checkTopBar(turned, upright: upright, "held on its \(side)")
            XCTAssertEqual(turned.focusSwitch, upright.focusSwitch, "The focus switch keeps its place held on its \(side)")
            XCTAssertGreaterThan(turned.switchCamera.height, turned.switchCamera.width,
                                 "Switch Camera, in the shutter bar, turns to read upright held on its \(side)")
            XCTAssertTrue(done.isHittable, "Done can be tapped held on its \(side)")
            checkFocusSwitch(turned, app, "held on its \(side)")
            checkNoticeShowsWhole(turned, app, "held on its \(side)")
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
        retainScreenshot(name: "\(screenshotName)-film-landscape")
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

    /// The focus switch sits in the control strip between the Viewfinder area and the shutter bar, in the same place in
    /// every hold. An iPhone at least 390 points wide, as this test's iPhone 17 Pro is, has room for the strip under the
    /// area; a narrower one, as the iPhone SE, has the strip over the area's bottom edge.
    private func checkFocusSwitch(_ layout: Layout, _ app: XCUIApplication, _ hold: String) {
        guard let focusSwitch = layout.focusSwitch else { return }
        // The shutter bar's top is 4 points above the shutter's frame.
        XCTAssertLessThanOrEqual(focusSwitch.maxY, layout.shutter.minY - 4, "The focus switch is above the shutter bar, \(hold)")
        XCTAssertGreaterThanOrEqual(focusSwitch.height, 44, "The switch is a full tap target tall, \(hold)")
        if layout.window.width >= 390 {
            XCTAssertGreaterThanOrEqual(focusSwitch.minY, layout.viewfinder.maxY - 0.5,
                                        "The focus switch is under the Viewfinder area, \(hold): \(focusSwitch)")
        } else {
            XCTAssertGreaterThan(focusSwitch.minY, layout.viewfinder.midY, "The strip is over the area's bottom, \(hold)")
        }
        // The notices over the area (the camera's error, Resume Camera) stay clear of it at every text size.
        let viewfinder = app.otherElements["viewfinder"]
        for element in viewfinder.staticTexts.allElementsBoundByIndex + viewfinder.buttons.allElementsBoundByIndex {
            XCTAssertFalse(focusSwitch.intersects(element.frame),
                           "\(element.label) is clear of the focus switch, \(hold): \(element.frame) and \(focusSwitch)")
        }
        for (label, frame) in [("Done", layout.done), ("Camera name and count", layout.remaining)] {
            XCTAssertFalse(focusSwitch.intersects(frame), "The focus switch is clear of \(label), \(hold)")
        }
    }

    /// Held sideways the top bar stays above the Viewfinder area as it is upright: Done, a 44-point round button, turned
    /// in place in its corner, and the count turned to read upright in the other, without the Camera's name, and nothing
    /// of the bar over the area (the captain, 2026-10-29, "5A").
    private func checkTopBar(_ turned: Layout, upright: Layout, _ hold: String) {
        XCTAssertGreaterThan(turned.remaining.height, turned.remaining.width, "The count turns to read upright, \(hold)")
        XCTAssertGreaterThanOrEqual(turned.done.height, 44, "Done keeps a tap target of 44 points turned, \(hold)")
        XCTAssertGreaterThanOrEqual(turned.done.width, 44, "Done keeps a tap target of 44 points turned, \(hold)")
        for (label, frame) in [("Done", turned.done), ("The count", turned.remaining)] + (turned.notice.map { [("The notice", $0)] } ?? []) {
            XCTAssertTrue(turned.window.contains(frame), "\(label) is on screen, \(hold): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxY, turned.viewfinder.minY + 0.5,
                                     "\(label) stays in the top bar, above the area, \(hold): \(frame)")
            XCTAssertGreaterThanOrEqual(frame.minY, upright.done.minY - 0.5, "\(label) stays below the status bar, \(hold)")
        }
        XCTAssertEqual(turned.done.midY, upright.done.midY, accuracy: 1, "Done turns in place, \(hold)")
        XCTAssertEqual(turned.done.minX, upright.done.minX, accuracy: 2, "Done stays in its corner, \(hold)")
        XCTAssertEqual(turned.remaining.maxX, upright.remaining.maxX, accuracy: 2, "The count stays in the other corner, \(hold)")
        XCTAssertLessThan(turned.remaining.width, upright.remaining.width, "The Camera's name is hidden, \(hold)")
        XCTAssertFalse(turned.done.intersects(turned.remaining), "Done and the count do not overlap, \(hold)")
    }

    /// The camera's notice over the area (its error, the microphone note and the whole Resume Camera button) shows whole
    /// without scrolling: each part lies inside the Viewfinder area and inside any scroll view it is in, so none of it is
    /// cut at that view's edge or out of view, and clear of the focus switch and the header. A part scrolled past its room
    /// keeps its whole frame, so a cut part lies outside its scroll view's frame.
    private func checkNoticeShowsWhole(_ layout: Layout, _ app: XCUIApplication, _ hold: String) {
        let viewfinder = app.otherElements["viewfinder"]
        let resume = viewfinder.buttons["Resume Camera"]
        XCTAssertTrue(resume.exists, "Resume Camera shows over the area, \(hold)")
        let parts = [resume] + viewfinder.staticTexts.allElementsBoundByIndex.filter {
            $0.label.hasPrefix("Camera unavailable") || $0.identifier == "microphone-permission-note"
        }
        let header = [layout.done, layout.remaining] + [layout.notice].compactMap { $0 }
        for part in parts where part.exists {
            let frame = part.frame
            XCTAssertTrue(layout.viewfinder.insetBy(dx: -1, dy: -1).contains(frame),
                          "\(part.label) is whole inside the Viewfinder area, \(hold): \(frame) in \(layout.viewfinder)")
            for room in viewfinder.scrollViews.containing(NSPredicate(format: "label == %@", part.label)).allElementsBoundByIndex {
                XCTAssertTrue(room.frame.insetBy(dx: -1, dy: -1).contains(frame),
                              "\(part.label) shows whole without scrolling, \(hold): \(frame) in \(room.frame)")
            }
            if let focusSwitch = layout.focusSwitch {
                XCTAssertFalse(frame.intersects(focusSwitch),
                               "\(part.label) is clear of the focus switch, \(hold): \(frame) and \(focusSwitch)")
            }
            for other in header {
                XCTAssertFalse(frame.intersects(other), "\(part.label) is clear of the header, \(hold): \(frame) and \(other)")
            }
        }
    }

    /// The camera's notice shows whole upright and held on each side, with the focus switch in the strip, and the
    /// Viewfinder area keeps its place; each hold's screenshot is kept under `name`.
    private func checkNoticeShowsWholeInEveryHold(_ app: XCUIApplication, name: String) throws {
        let upright = try wait(app)
        for (orientation, side) in [(UIDeviceOrientation.portrait, "portrait"), (.landscapeLeft, "left"), (.landscapeRight, "right")] {
            XCUIDevice.shared.orientation = orientation
            let layout = try wait(app) {
                orientation == .portrait ? $0.remaining.width > $0.remaining.height : $0.remaining.height > $0.remaining.width
            }
            retainScreenshot(name: "\(name)-capture-\(side)")
            XCTAssertEqual(layout.viewfinder, upright.viewfinder, "The viewfinder keeps its size and place, \(side)")
            checkFocusSwitch(layout, app, side)
            checkNoticeShowsWhole(layout, app, side)
        }
        XCUIDevice.shared.orientation = .portrait
        _ = try wait(app) { $0.remaining.width > $0.remaining.height }
    }

    /// Develop at once's notice stays beside Done in the top bar, above the Viewfinder area, clear of the shutter bar's
    /// buttons and the Camera name and count.
    private func checkNotice(_ layout: Layout, shows: Bool, _ hold: String) {
        guard shows else { return XCTAssertNil(layout.notice, "No Develop at once notice, \(hold)") }
        guard let notice = layout.notice else { return XCTFail("The Develop at once notice shows, \(hold)") }
        XCTAssertTrue(layout.window.contains(notice), "The notice is on screen, \(hold): \(notice)")
        XCTAssertLessThanOrEqual(notice.maxY, layout.viewfinder.minY + 0.5, "The notice is above the area, \(hold): \(notice)")
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
        let focusSwitch = app.descendants(matching: .any)["capture-focus-mode"]
        return Layout(window: app.windows.firstMatch.frame, viewfinder: viewfinder.frame, done: app.buttons["Done"].frame,
                      remaining: remaining.frame, shutter: shutter.frame, switchCamera: app.buttons["Switch Camera"].frame,
                      notice: notice.exists ? notice.frame : nil, focusSwitch: focusSwitch.exists ? focusSwitch.frame : nil)
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
