import XCTest

@MainActor final class ExportProcessExitTests: XCTestCase {
    func testPhotoUnknownReplyReentry() { run(camera: "disposable1990s", sources: 1) }
    func testMovieUnknownReplyReentry() { run(camera: "cinema16mm", sources: 2) }

    private func run(camera: String, sources: Int) {
        continueAfterFailure = false
        for boundary in ["beforeCopy", "beforeReply"] {
            let run = UUID().uuidString
            let app = XCUIApplication()
            app.launchArguments = ["--export-run", run, "--camera", camera, "--boundary", boundary]
            app.launch()
            XCTAssertTrue(app.buttons["prepare"].waitForExistence(timeout: 10))
            app.buttons["prepare"].tap(); wait("prepare-ok", app)
            XCTAssertEqual(app.staticTexts["inventory"].label, "films=1;sources=\(sources);copies=0")
            app.buttons["start"].tap()
            let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "paused-\(boundary)"), object: app.staticTexts["phase"])
            XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 20), .completed)
            app.buttons["inspect"].tap(); wait("inspect-ok", app)
            let copies = boundary == "beforeReply" ? 1 : 0
            XCTAssertEqual(app.staticTexts["inventory"].label, "films=1;sources=\(sources);copies=\(copies)")
            retain(app, "\(run)-\(camera)-\(boundary)-before-exit")
            app.buttons["terminate"].tap()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
            app.launch()
            XCTAssertTrue(app.buttons["recover"].waitForExistence(timeout: 10))
            app.buttons["recover"].tap(); wait("recover-ok", app)
            XCTAssertEqual(app.staticTexts["inventory"].label, "films=1;sources=\(sources);copies=\(copies)")
            retain(app, "\(run)-\(camera)-\(boundary)-recovered-no-auto-export")
            app.buttons["retry"].tap(); wait("retry-ok", app)
            XCTAssertEqual(app.staticTexts["inventory"].label, "films=1;sources=\(sources - 1);copies=\(copies + 1)")
            retain(app, "\(run)-\(camera)-\(boundary)-explicit-retry")
            app.terminate()
        }
    }
    private func wait(_ value: String, _ app: XCUIApplication) {
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: app.staticTexts["status"])
        XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: 20), .completed, app.staticTexts["status"].label)
    }
    private func retain(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
