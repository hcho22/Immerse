import XCTest

/// Load Film's Film Stock choice as a person meets it (ADR 0014, PRD 2.1 FR-03): only the 6×6 Medium Format and the
/// 16mm Cinema show it, it starts on Color, Black and white can be chosen, Load Film confirms it, and the loaded Film's
/// screen names it. Loading uses the Debug testing unlock and answers a fresh Camera request itself, and each test
/// deletes the Film it loaded. One test per Camera, to stay inside the per-test time allowance.
@MainActor
final class FilmStockUITests: XCTestCase {
    func testSixBySixLoadsOnTheBlackAndWhiteFilmStock() throws {
        try loadBlackAndWhite(id: "mediumFormat6x6", name: "6×6", capacity: "Capacity, 12 exposures")
    }

    func testSixteenMillimeterLoadsOnTheBlackAndWhiteFilmStock() throws {
        try loadBlackAndWhite(id: "cinema16mm", name: "16mm", capacity: "Capacity, 2 minutes 47 seconds of film")
    }

    /// The Cameras without a Film Stock show no choice on their Load screens.
    func testNoOtherCameraOffersAFilmStock() throws {
        let app = XCUIApplication.shippingGate()
        app.launch()
        openCameraCatalog(app)
        for (id, name) in [("disposable1990s", "Disposable"), ("instant1970s", "Instant"), ("super8HomeMovie", "Super 8")] {
            let camera = app.buttons["camera-\(id)"]
            scrollUp(app, until: camera)
            camera.tap()
            XCTAssertTrue(camera.waitForNonExistence(timeout: 5))
            let load = app.buttons["load-film"]
            scrollUp(app, until: load)
            XCTAssertTrue(load.isHittable, name)
            XCTAssertFalse(app.staticTexts["Film Stock"].exists, "\(name) offers no Film Stock")
            XCTAssertFalse(app.buttons["Black and white"].exists, "\(name) offers no Film Stock")
            goBack(app, from: name, to: "Choose a Camera")
        }
    }

    private func loadBlackAndWhite(id: String, name: String, capacity: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImmerseDebugTestingUnlock", "YES"]
        // An earlier test can leave Camera declined, so Load Film asks afresh and a person allows it.
        app.resetAuthorizationStatus(for: .camera)
        var allowed = false
        let monitor = addUIInterruptionMonitor(withDescription: "Camera access request") { alert in
            let allow = alert.buttons["Allow"]
            guard alert.label.localizedCaseInsensitiveContains("Camera"), allow.exists else { return false }
            allow.tap()
            allowed = true
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        app.launch()
        openCameraCatalog(app)
        let camera = app.buttons["camera-\(id)"]
        scrollUp(app, until: camera)
        camera.tap()
        XCTAssertTrue(camera.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[capacity].exists)

        let color = app.buttons["Color"], blackAndWhite = app.buttons["Black and white"]
        scrollUp(app, until: blackAndWhite)
        XCTAssertTrue(app.staticTexts["Film Stock"].exists)
        XCTAssertTrue(color.isSelected, "Color is chosen until the person chooses")
        XCTAssertFalse(blackAndWhite.isSelected)
        retainScreenshot(app, name: "\(name)-load-film-stock-color")
        blackAndWhite.tap()
        XCTAssertTrue(blackAndWhite.isSelected)
        XCTAssertFalse(color.isSelected)
        retainScreenshot(app, name: "\(name)-load-film-stock-black-and-white")
        try audit(app, name: "\(name)-load-film-stock", for: JournalFlowTests.auditTypes)

        // Loads with the title Load Film suggests, so no keyboard covers the screen on a small iPhone.
        let field = app.textFields["film-title"]
        scrollUp(app, until: field)
        let title = try XCTUnwrap(field.value as? String)
        let load = app.buttons["load-film"]
        scrollUp(app, until: load)
        defer { deleteFilm(titled: title, app) }
        load.tap()
        // The new Film opens on top of the Journal. The monitor runs only on an interaction made while the request is
        // showing, which can appear late.
        let stock = app.staticTexts["Black and white Film Stock"]
        for _ in 0..<20 where !stock.exists {
            app.navigationBars.firstMatch.tap()
            _ = stock.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(stock.exists, "The Film screen names its Film Stock")
        XCTAssertTrue(allowed, "Load Film asks for Camera access")
        retainScreenshot(app, name: "\(name)-film-black-and-white")
    }

    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
