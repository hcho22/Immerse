import XCTest

@MainActor final class ReceiptProcessExitTests: XCTestCase {
    func testPhotoCheckpointProcessExits() throws { try run(camera: "disposable1990s") }
    func testSuper8CheckpointProcessExits() throws { try run(camera: "super8HomeMovie") }
    func test16mmCheckpointProcessExits() throws { try run(camera: "cinema16mm") }

    private func run(camera: String) throws {
        continueAfterFailure = false
        for boundary in ["prepared", "receiptResolved", "projected"] {
            let run = UUID().uuidString
            let app = XCUIApplication()
            app.launchArguments = ["--receipt-run", run, "--camera", camera,
                "--backend", "injectedFile", "--fault", "none", "--boundary", boundary]
            app.launch()
            XCTAssertTrue(app.buttons["prepare"].waitForExistence(timeout: 10))
            app.buttons["prepare"].tap()
            waitStatus("prepare-ok", app)
            app.buttons["commit"].tap()
            let phase = app.staticTexts["phase"]
            XCTAssertTrue(NSPredicate(format: "label == %@", "paused-\(boundary)").evaluateWithWait(on: phase, timeout: 15))
            app.buttons["inspect"].tap()
            waitStatus("inspect-ok", app)
            let before = app.staticTexts["inventory"].label
            XCTAssertTrue(before.contains("saved=\(boundary == "projected" ? 1 : 0)"))
            XCTAssertTrue(before.contains("consumed=\(boundary != "prepared")"))
            XCTAssertTrue(before.contains("pending=true"))
            retain(app, "\(run)-\(camera)-\(boundary)-before-exit")
            app.buttons["terminate"].tap()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "Explicit boundary _exit must terminate this process")
            app.launch()
            XCTAssertTrue(app.buttons["recover"].waitForExistence(timeout: 10))
            app.buttons["recover"].tap()
            waitStatus("recover-ok", app)
            XCTAssertEqual(app.staticTexts["inventory"].label, "films=1;saved=1;pending=false;consumed=true;hash=true")
            retain(app, "\(run)-\(camera)-\(boundary)-recovered")
            app.terminate()
        }
    }
    private func waitStatus(_ value: String, _ app: XCUIApplication) {
        XCTAssertTrue(NSPredicate(format: "label == %@", value).evaluateWithWait(on: app.staticTexts["status"], timeout: 20), app.staticTexts["status"].label)
    }
    private func retain(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

private extension NSPredicate {
    @MainActor func evaluateWithWait(on object: Any, timeout: TimeInterval) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: self, object: object)], timeout: timeout) == .completed
    }
}
