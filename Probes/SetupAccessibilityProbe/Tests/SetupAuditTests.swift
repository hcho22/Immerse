import XCTest

@MainActor
final class SetupAuditTests: XCTestCase {
    func testSystemSelectedSize() throws { try auditSetup(arguments: []) }

    func testStablePickerStyle() throws { try auditSetup(arguments: ["-stableOrientationMenu"]) }

    func testStackContainer() throws { try auditSetup(arguments: ["-stackContainer"]) }

    func testHardEdge() throws { try auditSetup(arguments: ["-hardEdge"]) }

    func testStackContainerHardEdge() throws { try auditSetup(arguments: ["-stackContainer", "-hardEdge"]) }

    func testStackSuppressedEdges() throws { try auditSetup(arguments: ["-stackContainer", "-suppressEdges"]) }

    func testStackBoundedViewport() throws { try auditSetup(arguments: ["-stackContainer", "-boundedViewport"]) }

    func testForcedLargestSize() throws {
        try auditSetup(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    private func auditSetup(arguments: [String]) throws {
        let app = XCUIApplication()
        app.launchArguments = arguments
        record("launch", detail: arguments.joined(separator: " "))
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
        record("\(name).before-snapshot")
        retain(XCTAttachment(string: app.debugDescription), name: "\(name)-before-tree")
        retain(XCTAttachment(screenshot: app.screenshot()), name: "\(name)-before-screen")
        record("\(name).audit-call")
        var callback = 0
        try app.performAccessibilityAudit { issue in
            callback += 1
            let event = "\(name).callback-\(callback)"
            self.record("\(event).enter", detail: "auditType=\(issue.auditType.rawValue)")
            self.retain(XCTAttachment(screenshot: app.screenshot()), name: "\(event)-before-query-screen")
            self.record("\(event).screenshot-returned")
            self.retain(XCTAttachment(string: app.debugDescription), name: "\(event)-before-issue-query-tree")
            self.record("\(event).tree-returned")
            self.retain(XCTAttachment(string: "\(issue.auditType): \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No element supplied")"), name: "\(name)-issue")
            self.record("\(event).issue-query-returned")
            self.retain(XCTAttachment(screenshot: app.screenshot()), name: "\(event)-after-query-screen")
            self.record("\(event).exit")
            return false
        }
        record("\(name).audit-returned")
        retain(XCTAttachment(string: app.debugDescription), name: "\(name)-after-tree")
        retain(XCTAttachment(screenshot: app.screenshot()), name: "\(name)-after-screen")
    }

    private func record(_ event: String, detail: String = "") {
        let value = "AUDIT_PROBE time=\(Date().timeIntervalSince1970) uptime=\(ProcessInfo.processInfo.systemUptime) event=\(event) \(detail)"
        print(value)
        retain(XCTAttachment(string: value), name: event)
    }

    private func retain(_ attachment: XCTAttachment, name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
