import XCTest

@MainActor
final class JournalFlowTests: XCTestCase {
    func testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        for id in ["disposable1990s", "instant1970s", "mediumFormat6x6", "super8HomeMovie", "cinema16mm"] {
            XCTAssertTrue(app.buttons["camera-\(id)"].exists)
        }
        app.buttons["camera-super8HomeMovie"].tap()
        XCTAssertTrue(app.staticTexts["3:20 of film"].exists)
        XCTAssertTrue(app.buttons["load-film"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        try audit(app, name: "Super8-load-default")
        retainScreenshot(app, name: "Super8-load-default")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Your Journal begins here"].exists)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Restoring an older backup")).firstMatch.exists)
        app.buttons["Done"].tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["No archived Films"].exists)
    }

    func testLargestDynamicTypeCatalogAndLandscapeSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
        retainScreenshot(app, name: "Catalog-accessibility-largest")
        let camera = app.buttons["camera-cinema16mm"]
        for _ in 0..<5 where !camera.isHittable { app.swipeUp() }
        XCTAssertTrue(camera.isHittable)
        camera.tap()
        XCTAssertTrue(app.staticTexts["2:45 of film"].exists)
        try app.performAccessibilityAudit()
        retainScreenshot(app, name: "16mm-load-accessibility-largest")
        let title = app.staticTexts["film-title-heading"]
        for _ in 0..<8 where !title.isHittable { app.swipeUp() }
        XCTAssertTrue(title.isHittable)
        try audit(app, name: "16mm-title-accessibility-largest")
        retainScreenshot(app, name: "16mm-title-accessibility-largest")
        let load = app.buttons["load-film"]
        for _ in 0..<8 where !load.isHittable { app.swipeUp() }
        XCTAssertTrue(load.isHittable)
        try audit(app, name: "16mm-command-accessibility-largest")
        retainScreenshot(app, name: "16mm-command-accessibility-largest")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
        retainScreenshot(app, name: "Settings-landscape-accessibility-largest")
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func audit(_ app: XCUIApplication, name: String) throws {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name)-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
        try app.performAccessibilityAudit { issue in
            let detail = XCTAttachment(string: "\(issue.auditType): \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No element supplied by auditor")")
            detail.name = "\(name)-audit-node"
            detail.lifetime = .keepAlways
            self.add(detail)
            return false
        }
    }
}
