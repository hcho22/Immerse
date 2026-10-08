import XCTest

extension XCUIApplication {
    /// The app with the Debug-only testing unlock switched off for this launch, so a test sees
    /// the same Trial and subscription gate as a Release build. The persisted switch is unchanged.
    static func shippingGate() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ImmerseDebugTestingUnlock", "NO"]
        return app
    }
}

/// The Debug-only testing unlock as the captain meets it: the indicator on the load and plan
/// screens and the Settings switch, which holds across launches. Ends with the unlock on, the
/// Debug default.
@MainActor
final class TestingUnlockUITests: XCTestCase {
    /// One test per switch value: both together took 1 minute 26 seconds to 1 minute 35 seconds on CI, which a runner at
    /// about half speed would push past the 3-minute allowance (Evidence/NativeApp/ci-flakes-057.md). Each sets the
    /// switch from whichever state it finds, so neither depends on the other's result.
    func testUnlockIndicatorShowsAfterTheSettingsSwitchIsTurnedOn() throws {
        let app = XCUIApplication()
        setUnlock(app, on: true)
        assertLoadAndPlans(app, unlocked: true)
    }

    func testUnlockIndicatorHidesAfterTheSettingsSwitchIsTurnedOff() throws {
        let app = XCUIApplication()
        // Leaves the unlock on, the Debug default, even when an assertion below fails.
        addTeardownBlock { @MainActor in self.setUnlock(app, on: true) }
        setUnlock(app, on: false)
        assertLoadAndPlans(app, unlocked: false)
    }

    private func setUnlock(_ app: XCUIApplication, on: Bool) {
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        let toggle = app.switches["testing-unlock-switch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if (toggle.value as? String == "1") != on { toggle.switches.firstMatch.tap() }
        XCTAssertEqual(toggle.value as? String, on ? "1" : "0")
        retainScreenshot(app, name: "Settings-testing-unlock-\(on ? "on" : "off")")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 5))
        app.terminate()
    }

    /// Relaunches, so the result shows what the persisted switch gives a home-screen launch.
    private func assertLoadAndPlans(_ app: XCUIApplication, unlocked: Bool) {
        app.launch()
        openCameraCatalog(app)
        app.buttons["camera-disposable1990s"].tap()
        let load = app.buttons["load-film"]
        for _ in 0..<8 where !(load.exists && load.isHittable) { app.swipeUp() }
        XCTAssertTrue(load.isHittable)
        let notice = app.descendants(matching: .any)["testing-unlock-notice"]
        XCTAssertEqual(notice.exists, unlocked, "Load screen indicator")
        if unlocked {
            XCTAssertTrue(notice.label.contains("Testing unlock - Debug build"), notice.label)
        }
        retainScreenshot(app, name: "Load-testing-unlock-\(unlocked ? "on" : "off")")
        app.buttons["Subscription"].tap()
        XCTAssertTrue(app.navigationBars["Subscription"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["testing-unlock-notice"].exists, unlocked, "Plan screen indicator")
        XCTAssertTrue(app.staticTexts["Subscriptions are not available in this build."].exists)
        retainScreenshot(app, name: "Plans-testing-unlock-\(unlocked ? "on" : "off")")
        app.terminate()
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
