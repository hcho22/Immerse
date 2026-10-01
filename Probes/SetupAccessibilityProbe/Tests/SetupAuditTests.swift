import XCTest

@MainActor
final class SetupAuditTests: XCTestCase {
    func testSystemSelectedSize() throws { try auditSetup(arguments: []) }

    func testStablePickerStyle() throws { try auditSetup(arguments: ["-stableOrientationMenu"]) }

    func testForcedLargestSize() throws {
        try auditSetup(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    private func auditSetup(arguments: [String]) throws {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["16mm"].waitForExistence(timeout: 5))
        try audit(app, name: "top")
        let title = app.staticTexts["film-title-heading"]
        for _ in 0..<8 where !title.isHittable { app.swipeUp() }
        XCTAssertTrue(title.isHittable)
        try audit(app, name: "title")
        let command = app.buttons["load-film"]
        for _ in 0..<8 where !command.isHittable { app.swipeUp() }
        XCTAssertTrue(command.isHittable)
        try audit(app, name: "command")
    }

    private func audit(_ app: XCUIApplication, name: String) throws {
        retain(XCTAttachment(string: app.debugDescription), name: "\(name)-before-tree")
        retain(XCTAttachment(screenshot: app.screenshot()), name: "\(name)-before-screen")
        try app.performAccessibilityAudit { issue in
            self.retain(XCTAttachment(string: "\(issue.auditType): \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No element supplied")"), name: "\(name)-issue")
            return false
        }
        retain(XCTAttachment(string: app.debugDescription), name: "\(name)-after-tree")
        retain(XCTAttachment(screenshot: app.screenshot()), name: "\(name)-after-screen")
    }

    private func retain(_ attachment: XCTAttachment, name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
