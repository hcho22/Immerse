import XCTest

/// The captain's 16mm Development of 2026-10-28, on the Film screen: a 16mm Film on the color Film Stock with one
/// Recorded Clip with Live Audio, stopped early with Stop & Develop Early and developed, with the iPhone locked partway,
/// as an auto-lock does. Development stops when the app leaves the screen; on return the alert says so and names no
/// storage, the Film still reads Developing, and Resume Development finishes the Movie with its recorded sound. The
/// simulator keeps the video encoder that iOS takes from an app in the background, so this shows the stop and what the
/// person sees of it, and `DevelopmentStopTests` the stop's failure as iOS makes it (Evidence/NativeApp/development-stop-079.md).
@MainActor final class DevelopmentStopWorkflowTests: HarnessTestCase {
    func testLockingTheIPhoneDuringDevelopmentSaysSoAndResumeDevelopmentFinishes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--hide-inspection-bar", "--movie", "--open-film", "--recorded-sound"]
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60))
        XCTAssertFalse(app.staticTexts["fixture-failed"].exists)
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Private synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Color Film Stock"].exists)
        app.buttons["Film actions"].tap()
        app.buttons["Stop & Develop Early"].tap()
        let complete = app.buttons["Complete Film"]
        XCTAssertTrue(complete.waitForExistence(timeout: 10))
        complete.tap()
        let remove = app.buttons["Remove originals after verified Development"]
        XCTAssertTrue(remove.waitForExistence(timeout: 20))
        remove.tap()
        app.buttons["confirm-original-choice"].tap()

        // Lock the iPhone while it develops, and unlock it a few seconds later.
        XCTAssertTrue(app.descendants(matching: .any)["processing-film"].waitForExistence(timeout: 20), "Development began")
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        Thread.sleep(forTimeInterval: 4)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        XCUIDevice.shared.press(.home)
        app.activate()

        let alert = app.alerts["Could not finish"]
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "The stop is reported: \(app.debugDescription)")
        let message = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        XCTAssertTrue(message.contains("Development stopped because Immerse left the screen."), message)
        XCTAssertFalse(message.contains("storage"), message)
        keep(app, "stopped-alert")
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Developing"].waitForExistence(timeout: 10))
        let resume = app.buttons["Resume Development"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        keep(app, "stopped-film")

        resume.tap()
        XCTAssertTrue(app.staticTexts["Developed"].waitForExistence(timeout: 120), "Resume Development finishes it")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Movie sound: Recorded sound"].waitForExistence(timeout: 10),
                      "The Movie plays the clip's recorded sound")
        keep(app, "developed-film")
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
