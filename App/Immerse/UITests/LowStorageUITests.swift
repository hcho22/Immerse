import XCTest

/// The low-storage warning as a person meets it (DEC-12): on the Load Film screen above Load Film, and on the loaded
/// Film's screen above Open Camera. A launch argument sets the free-space reading, since a test cannot fill a disk:
/// just under 2 GB (1,999,999,999 bytes) shows the warning, and exactly 2 GB, just over, and a reading that fails
/// show none. The warning stops nothing: the Film still loads. The Film screen's other readings, its warning before
/// Development and its largest text size are covered on synthetic Films by the populated Journal harness.
@MainActor
final class LowStorageUITests: XCTestCase {
    static let captureWarning = "This iPhone has less than 2 GB free, so a capture may not save. A capture that does not save uses no exposures or time, and saved captures are unchanged. Free space in iPhone Settings."

    func testLoadFilmWarnsJustUnderTwoGigabytes() throws {
        let app = launch(freeSpace: "1999999999")
        openDisposableLoadScreen(app)
        // The Camera's rows at rest, which the end of the Form puts under the navigation bar (`AuditException`).
        retainScreenshot(app, name: "Load-low-storage-top")
        // The end of the Form, where the warning and the command it comes before are on screen together.
        let warning = app.staticTexts["low-storage-warning"], load = app.buttons["load-film"]
        scrollUpUntilWhole(app, load)
        XCTAssertEqual(warning.label, Self.captureWarning)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(warning.frame), "The whole warning is on screen with Load Film")
        XCTAssertTrue(load.isHittable)
        XCTAssertTrue(load.isEnabled, "The warning stops nothing")
        XCTAssertLessThanOrEqual(warning.frame.maxY, load.frame.minY, "The warning comes before Load Film")
        try audit(app, name: "Load-low-storage", for: JournalFlowTests.auditTypes)
        retainScreenshot(app, name: "Load-low-storage")
    }

    func testLoadFilmShowsNoWarningAtExactlyTwoGigabytes() throws { assertNoWarningOnLoadFilm(freeSpace: "2000000000") }
    func testLoadFilmShowsNoWarningJustOverTwoGigabytes() throws { assertNoWarningOnLoadFilm(freeSpace: "2000000001") }
    func testLoadFilmShowsNoWarningWhenTheReadingFails() throws { assertNoWarningOnLoadFilm(freeSpace: "unreadable") }

    /// At the largest text size the warning is taller than the screen's free room, so each control is reached by
    /// scrolling and none is hidden or clipped.
    func testLoadFilmWarningAtTheLargestTextSizeHidesNoControl() throws {
        let app = launch(freeSpace: "1999999999", size: "UICTContentSizeCategoryAccessibilityXXXL")
        openDisposableLoadScreen(app)
        let warning = app.staticTexts["low-storage-warning"]
        scrollUp(app, until: warning)
        XCTAssertEqual(warning.label, Self.captureWarning)
        try audit(app, name: "Load-low-storage-accessibility-largest", for: JournalFlowTests.auditTypes)
        retainScreenshot(app, name: "Load-low-storage-accessibility-largest")
        let load = app.buttons["load-film"]
        scrollUp(app, until: load)
        XCTAssertTrue(load.isHittable)
        XCTAssertTrue(load.isEnabled)
        try audit(app, name: "Load-low-storage-command-accessibility-largest", for: JournalFlowTests.auditTypes)
        retainScreenshot(app, name: "Load-low-storage-command-accessibility-largest")
    }

    /// Loading while the warning shows still loads the Film, and its screen warns again above Open Camera.
    func testLoadingStillWorksAndTheFilmScreenWarnsBeforeOpenCamera() throws {
        try withLoadedDisposable(size: nil) { app, open, warning in
            XCTAssertTrue(warning.isHittable, "The warning is visible without scrolling")
            XCTAssertTrue(open.isHittable)
            XCTAssertTrue(open.isEnabled, "The warning stops nothing")
            XCTAssertLessThanOrEqual(warning.frame.maxY, open.frame.minY, "The warning comes before Open Camera")
            try audit(app, name: "Film-low-storage", for: JournalFlowTests.auditTypes)
            retainScreenshot(app, name: "Film-low-storage")
        }
    }

    /// At the largest text size the Film screen's warning fills the first screen, and Open Camera is reached by
    /// scrolling past it.
    func testFilmScreenWarningAtTheLargestTextSizeHidesNoControl() throws {
        try withLoadedDisposable(size: "UICTContentSizeCategoryAccessibilityXXXL") { app, open, warning in
            scrollUp(app, until: warning)
            try audit(app, name: "Film-low-storage-accessibility-largest", for: JournalFlowTests.auditTypes)
            retainScreenshot(app, name: "Film-low-storage-accessibility-largest")
            scrollUp(app, until: open)
            XCTAssertTrue(open.isHittable)
            XCTAssertTrue(open.isEnabled, "The warning stops nothing")
            XCTAssertLessThanOrEqual(warning.frame.maxY, open.frame.minY, "The warning comes before Open Camera")
            try audit(app, name: "Film-low-storage-command-accessibility-largest", for: JournalFlowTests.auditTypes)
            retainScreenshot(app, name: "Film-low-storage-command-accessibility-largest")
        }
    }

    /// Loads a Disposable Film with free space reading just under 2 GB, hands `check` its screen's Open Camera and
    /// warning, and deletes the Film afterwards.
    private func withLoadedDisposable(size: String?,
                                      _ check: (XCUIApplication, XCUIElement, XCUIElement) throws -> Void) throws {
        let app = configured(freeSpace: "1999999999", size: size, unlocked: true)
        // An earlier test can leave Camera declined, so Load Film asks afresh and a person allows it.
        app.resetAuthorizationStatus(for: .camera)
        let monitor = addUIInterruptionMonitor(withDescription: "Camera access request") { alert in
            let allow = alert.buttons["Allow"]
            guard alert.label.localizedCaseInsensitiveContains("Camera"), allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        app.launch()
        openDisposableLoadScreen(app)
        // Loads with the title Load Film suggests, so no keyboard covers the screen on a small iPhone.
        let field = app.textFields["film-title"]
        scrollUp(app, until: field)
        let title = try XCTUnwrap(field.value as? String)
        let load = app.buttons["load-film"]
        scrollUp(app, until: load)
        XCTAssertTrue(app.staticTexts["low-storage-warning"].exists)
        defer { deleteFilm(titled: title, app) }
        load.tap()
        // The new Film opens on top of the Journal. The monitor runs only on an interaction made while the request is
        // showing, which can appear late.
        let actions = app.buttons["Film actions"]
        for _ in 0..<20 where !actions.exists {
            app.navigationBars.firstMatch.tap()
            _ = actions.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(actions.exists, "The Film loads while the warning shows")
        let warning = app.staticTexts["low-storage-warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertEqual(warning.label, Self.captureWarning)
        try check(app, app.buttons["Open Camera"], warning)
    }

    private func assertNoWarningOnLoadFilm(freeSpace: String) {
        let app = launch(freeSpace: freeSpace)
        openDisposableLoadScreen(app)
        let load = app.buttons["load-film"]
        // The warning's row sits just above Load Film, so the whole Form has been laid out once Load Film is reached.
        scrollUp(app, until: load)
        XCTAssertTrue(load.isHittable)
        XCTAssertFalse(app.staticTexts["low-storage-warning"].exists, "No warning with \(freeSpace) free")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "2 GB")).firstMatch.exists)
    }

    private func launch(freeSpace: String, size: String? = nil) -> XCUIApplication {
        let app = configured(freeSpace: freeSpace, size: size)
        app.launch()
        return app
    }

    /// The app with its free-space reading set, behind the shipping gate unless a test loads a Film with the unlock.
    private func configured(freeSpace: String, size: String? = nil, unlocked: Bool = false) -> XCUIApplication {
        let app = unlocked ? XCUIApplication() : XCUIApplication.shippingGate()
        if unlocked { app.launchArguments += ["-ImmerseDebugTestingUnlock", "YES"] }
        app.launchArguments += ["-ImmerseDebugFreeSpace", freeSpace]
        if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
        return app
    }

    private func openDisposableLoadScreen(_ app: XCUIApplication) {
        openCameraCatalog(app)
        let camera = app.buttons["camera-disposable1990s"]
        scrollUp(app, until: camera)
        camera.tap()
        // The screen is checked only once the tapped row has left the tree, after the push
        // (Evidence/NativeApp/push-audit-055.md).
        XCTAssertTrue(camera.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Disposable"].exists)
    }

    /// Scrolls until the whole element, not just its center, is on screen with room below it, finishing in short drags.
    private func scrollUpUntilWhole(_ app: XCUIApplication, _ element: XCUIElement) {
        let window = app.windows.firstMatch.frame
        scrollUp(app, until: element)
        scrollUp(app, by: 100) { element.frame.maxY <= window.maxY - 40 }
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
