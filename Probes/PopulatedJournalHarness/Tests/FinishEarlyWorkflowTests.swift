import XCTest

/// The early-finish action in the Film actions menu, on synthetic Films with saved captures, which the app's own screen
/// tests cannot make: the Disposable and the 6×6 offer "Finish & Develop Early" (renamed from "Rewind & Develop Early"
/// on 2026-10-28) with the skip-to-end symbol, at the default text size and at AX XXXL, whole inside the screen, and the
/// Movie Cameras keep "Stop & Develop Early" with the skip-back symbol. The menu is the system's, so the frame and a
/// screenshot are kept for each size rather than its text's ink.
@MainActor final class FinishEarlyWorkflowTests: HarnessTestCase {
    private static let finish = "Finish & Develop Early"

    func testFinishAndDevelopEarlyAtDefaultSize() throws { check("L") }
    func testFinishAndDevelopEarlyAtAccessibilityExtraExtraExtraLarge() throws { check("AccessibilityXXXL") }

    func testMovieKeepsStopAndDevelopEarly() throws {
        let app = launch(["--movie", "--open-film"])
        openActions(app)
        let action = app.buttons["Stop & Develop Early"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertEqual(action.identifier, "backward.end", "The system menu names an item's symbol in its identifier")
        XCTAssertFalse(app.buttons[Self.finish].exists)
        XCTAssertFalse(app.buttons["Rewind & Develop Early"].exists)
        snapshot(app, "Movie-film-actions")
    }

    /// The Disposable, then the 6×6, at one text size.
    private func check(_ category: String) {
        for (camera, arguments) in [("Disposable", [String]()), ("6x6", ["--medium-format", "--open-film"])] {
            let app = launch(arguments + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"])
            let window = app.windows.firstMatch.frame
            openActions(app)
            let action = app.buttons[Self.finish]
            XCTAssertTrue(action.waitForExistence(timeout: 5), "\(camera) \(category)")
            XCTAssertFalse(app.buttons["Rewind & Develop Early"].exists, "\(camera) \(category)")
            XCTAssertEqual(action.identifier, "forward.end", "The skip-to-end symbol: \(camera) \(category)")
            XCTAssertTrue(action.isEnabled, "A Film with saved captures can finish early: \(camera) \(category)")
            XCTAssertTrue(action.isHittable, "\(camera) \(category)")
            XCTAssertTrue(window.contains(action.frame), "\(camera) \(category): \(action.frame) inside \(window)")
            snapshot(app, "\(camera)-film-actions-\(category)")
            app.terminate()
        }
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--hide-inspection-bar"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 60))
        XCTAssertFalse(app.staticTexts["fixture-failed"].exists)
        return app
    }

    private func openActions(_ app: XCUIApplication) {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Private synthetic Film")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Private synthetic Film"].waitForExistence(timeout: 5))
        app.buttons["Film actions"].tap()
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
