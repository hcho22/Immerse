import XCTest

/// The shooting screen as a person holds the iPhone sideways (the captain, 2026-10-16: "Like iPhone Camera"): the screen
/// never turns, so the viewfinder keeps its size and place, and only the words and icons turn to read upright. Every other
/// screen keeps turning with the iPhone. The simulator has no camera, so the screen shows its message for the missing one,
/// and only what it draws without a lens is measured; the zoom pill, the sliders and the Disposable's cue, which a lens
/// raises, are in `CaptureSidewaysTests`. Loading uses the Debug testing unlock and answers a fresh Camera request
/// itself, and each test starts on an empty Journal and deletes the Film it loaded. One test per Camera shape, to stay
/// inside the per-test time allowance.
@MainActor
final class CaptureSidewaysUITests: XCTestCase {
    func testSixBySixShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "mediumFormat6x6", name: "6×6")
    }

    func testDisposableShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "disposable1990s", name: "Disposable")
    }

    func testSuper8ShootingScreenKeepsItsLayoutHeldSideways() throws {
        try check(id: "super8HomeMovie", name: "Super 8")
    }

    /// What the screen shows, measured in the window's own portrait frame.
    private struct Layout {
        var window: CGRect
        var viewfinder: CGRect
        var done: CGRect
        var remaining: CGRect
        var shutter: CGRect
    }

    private func check(id: String, name: String) throws {
        let app = XCUIApplication()
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
        defer { XCUIDevice.shared.orientation = .portrait }
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
        defer { deleteFilm(titled: title, app) }
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
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        let upright = try layout(app)
        XCTAssertLessThan(upright.window.width, upright.window.height, "The shooting screen is portrait")
        XCTAssertGreaterThan(upright.remaining.width, upright.remaining.height, "Upright, the count reads across")
        retainScreenshot(name: "\(name)-capture-portrait")

        for (orientation, side) in [(UIDeviceOrientation.landscapeLeft, "left"), (.landscapeRight, "right")] {
            XCUIDevice.shared.orientation = orientation
            // The words turn with an animation, and the screen must not turn at all.
            let turned = try wait(app) { $0.remaining.height > $0.remaining.width }
            retainScreenshot(name: "\(name)-capture-\(side)")
            XCTAssertEqual(turned.window, upright.window, "The screen stays portrait held on its \(side)")
            XCTAssertEqual(turned.viewfinder, upright.viewfinder, "The viewfinder keeps its size and place held on its \(side)")
            XCTAssertEqual(turned.shutter, upright.shutter, "The shutter keeps its place held on its \(side)")
            XCTAssertGreaterThan(turned.remaining.height, turned.remaining.width, "The count turns to read upright")
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
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "The shooting screen closed")
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        let turns = NSPredicate { _, _ in window.frame.width > window.frame.height }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: turns, object: nil)], timeout: 10), .completed,
                       "The Film screen turns with the iPhone once the shooting screen is gone")
        retainScreenshot(name: "\(name)-film-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    private func layout(_ app: XCUIApplication) throws -> Layout {
        let viewfinder = app.otherElements["viewfinder"]
        XCTAssertTrue(viewfinder.waitForExistence(timeout: 5), "The viewfinder is on screen")
        let remaining = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " left")).firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5), "What is left shows")
        let shutter = app.buttons["capture-shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        return Layout(window: app.windows.firstMatch.frame, viewfinder: viewfinder.frame, done: app.buttons["Done"].frame,
                      remaining: remaining.frame, shutter: shutter.frame)
    }

    /// The layout once `settled` holds, read until the turn's animation ends.
    private func wait(_ app: XCUIApplication, until settled: (Layout) -> Bool) throws -> Layout {
        var latest = try layout(app)
        for _ in 0..<20 where !settled(latest) {
            Thread.sleep(forTimeInterval: 0.25)
            latest = try layout(app)
        }
        Thread.sleep(forTimeInterval: 0.5)
        return try layout(app)
    }

    private func retainScreenshot(name: String) {
        let attachment = XCTAttachment(image: XCUIScreen.main.uprightScreenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
