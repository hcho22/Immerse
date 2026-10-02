import XCTest

@MainActor final class DevelopmentProcessExitUITests: XCTestCase {
    func testPhotoExitAfterRendering() { run(camera: "disposable1990s", boundary: "afterRendering", count: 1) }
    func testInstantExitBeforeSecondReveal() { run(camera: "instant1970s", boundary: "beforeReveal", count: 2) }
    func testMovieExitAfterClipPersistence() { run(camera: "cinema16mm", boundary: "afterPersistence", count: 1) }
    func testMovieDiscardExitAfterAssignments() { run(camera: "super8HomeMovie", boundary: "afterAssignments", count: 2, discard: true) }

    private func run(camera: String, boundary: String, count: Int, discard: Bool = false) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--development-run", UUID().uuidString, "--camera", camera, "--boundary", boundary]
            + (discard ? ["--discard-first"] : [])
        app.launch(); wait("opened", app)
        command("prepare", app)
        retain(app, "prepared-\(camera)-\(boundary)")
        app.buttons["development-start"].tap()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 30))
        app.launch(); wait("opened", app)
        command("recover", app)
        retain(app, "recovered-not-resumed-\(camera)-\(boundary)")
        command("resume", app)
        let expected = "saved=\(count);revealed=\(discard ? count - 1 : count);sources=0"
        XCTAssertEqual(app.staticTexts["development-summary"].label, expected)
        retain(app, "resumed-\(camera)-\(boundary)")
        command("repeat", app)
        XCTAssertEqual(app.staticTexts["development-summary"].label, expected)
        app.terminate()
    }
    private func command(_ name: String, _ app: XCUIApplication) {
        app.buttons["development-\(name)"].tap(); wait("\(name)-ok", app)
    }
    private func wait(_ value: String, _ app: XCUIApplication) {
        let status = app.staticTexts["development-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: 30), .completed, status.label)
    }
    private func retain(_ app: XCUIApplication, _ name: String) {
        for attachment in [XCTAttachment(screenshot: app.screenshot()), XCTAttachment(string: app.debugDescription)] {
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
}
