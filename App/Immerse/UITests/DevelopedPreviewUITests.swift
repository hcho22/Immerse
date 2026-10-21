import XCTest

/// The Debug-only switch for previewing each saved capture, as the captain meets it in Settings: on in a Debug build,
/// holding across launches, and off for one launch with `-ImmerseDebugDevelopedPreview NO`, the argument a screen test
/// passes where a preview would change its screen. The simulator has no camera, so a preview itself is shown by the
/// hosted `DevelopedPreviewsTests`, and the shooting screen's notice that the switch is on by `CaptureSidewaysUITests`.
/// Ends with the switch on, the Debug default.
@MainActor
final class DevelopedPreviewUITests: ScreenTestCase {
    func testTheSettingsSwitchHoldsAcrossLaunchesAndTheLaunchArgumentTurnsItOffForOneLaunch() throws {
        let app = XCUIApplication()
        // Leaves the switch on, the Debug default, even when an assertion below fails.
        addTeardownBlock { @MainActor in self.setSwitch(app, on: true) }
        setSwitch(app, on: false)
        XCTAssertEqual(switchValue(app), "0", "Off holds on the next launch")
        app.terminate()
        setSwitch(app, on: true)
        XCTAssertEqual(switchValue(app), "1", "On holds on the next launch")
        retainScreenshot(app, name: "Settings-develop-at-once-on")
        app.terminate()

        let turnedOff = XCUIApplication()
        turnedOff.launchArguments += ["-ImmerseDebugDevelopedPreview", "NO"]
        XCTAssertEqual(switchValue(turnedOff), "0", "The launch argument turns previews off")
        turnedOff.terminate()
        XCTAssertEqual(switchValue(app), "1", "and leaves the persisted switch on")
        app.terminate()
    }

    /// Launches, flips the switch in Settings to `on` if it is not, and quits.
    private func setSwitch(_ app: XCUIApplication, on: Bool) {
        let toggle = openSettingsSwitch(app)
        if (toggle.value as? String == "1") != on { toggle.switches.firstMatch.flipSwitch() }
        XCTAssertEqual(toggle.value as? String, on ? "1" : "0")
        app.terminate()
    }

    /// Launches and reads the switch in Settings, leaving Settings open.
    private func switchValue(_ app: XCUIApplication) -> String? {
        openSettingsSwitch(app).value as? String
    }

    private func openSettingsSwitch(_ app: XCUIApplication) -> XCUIElement {
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        let toggle = app.switches["developed-preview-switch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Develop at once - Debug build")
        return toggle
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
