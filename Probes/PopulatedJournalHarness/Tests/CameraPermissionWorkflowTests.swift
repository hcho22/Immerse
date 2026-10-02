import XCTest

/// The harness declares a Camera usage key only so this test can answer the actual system
/// Camera request. Nothing is captured: the simulator has no camera.
@MainActor final class CameraPermissionWorkflowTests: XCTestCase {
    func testDeniedCameraOnReopenShowsGuidanceAndLeavesFilmUnchanged() throws {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .camera)
        app.launchArguments = ["--hide-inspection-bar"]
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60))
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Private synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["25 exposures left"].exists)

        // Decline the actual request as a person would. Without this monitor, XCTest allows it.
        var declined = false
        let monitor = addUIInterruptionMonitor(withDescription: "Camera access request") { alert in
            let deny = alert.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Don")).firstMatch
            guard alert.label.localizedCaseInsensitiveContains("Camera"), deny.exists else { return false }
            deny.tap()
            declined = true
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        app.buttons["Open Camera"].tap()
        let guidance = app.staticTexts["Camera access is off. Allow Camera for Immerse in iPhone Settings. Saved captures are unchanged."]
        // The monitor runs only on an interaction made while the request is showing, which can appear late.
        for _ in 0..<20 where !guidance.exists {
            app.navigationBars.firstMatch.tap()
            _ = guidance.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(guidance.exists)
        XCTAssertTrue(guidance.isHittable, "The guidance is visible without scrolling")
        XCTAssertTrue(declined, "Opening the camera must ask for Camera access")
        let shutter = app.buttons["capture-shutter"]
        XCTAssertFalse(shutter.isEnabled, "No capture without Camera access")
        XCTAssertLessThanOrEqual(shutter.frame.maxY, app.windows.firstMatch.frame.maxY, "The shutter must be on screen without scrolling")
        XCTAssertTrue(app.buttons["Open iPhone Settings"].isHittable, "Denied guidance links to iPhone Settings")
        XCTAssertTrue(app.buttons["Resume Camera"].exists)
        snapshot(app, "capture-camera-denied")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["25 exposures left"].exists)
        XCTAssertTrue(app.buttons["Open Camera"].exists)
        XCTAssertFalse(app.buttons["Open photo 1"].exists, "Declining Camera access reveals nothing")
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
