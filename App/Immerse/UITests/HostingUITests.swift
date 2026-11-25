import XCTest

/// Hosting's way in (v2 Stage 1; V2-FR-01 to V2-FR-05): a build with no server shows nothing of it; with one, Group Film
/// under Start a Film is the only place that asks a signed-out person to sign in, behind the age 13-or-over
/// confirmation; and Delete Account is two taps from the Journal's Settings. A Debug launch argument stands a stand-in
/// server and sign-in in for Clerk and Convex (`DebugHosting.swift`), so no real service is reached; signing in with the
/// real services is a manual check (`Evidence/NativeApp/manual-validation.md`, section V).
@MainActor
final class HostingUITests: ScreenTestCase {
    private func app(hosting start: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        if let start { app.launchArguments += ["-ImmerseDebugHosting", start] }
        return app
    }

    func testABuildWithNoServerShowsNothingOfHosting() {
        let app = app()
        app.launch()
        openCameraCatalog(app)
        XCTAssertFalse(app.buttons["group-film"].exists, "Group Film shows only where the app has a server")
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["delete-account"].exists)
        XCTAssertFalse(app.buttons["sign-out"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'No Accounts, sign-in'")).firstMatch.exists)
    }

    func testSignedOutSettingsHasNoAccountHeading() {
        let app = app(hosting: "signedOut")
        app.launch()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(heading("Privacy", app).exists(within: 5), "Settings' own headings show")
        XCTAssertFalse(heading("Account", app).exists, "Signed out, Settings has no Account heading with nothing under it")
        XCTAssertFalse(app.buttons["sign-out"].exists)
        keep(app, "Settings-signed-out")
    }

    func testPersonalFilmsNeverAskForSignIn() {
        let app = app(hosting: "signedOut")
        app.launch()
        openCameraCatalog(app)
        XCTAssertTrue(app.buttons["group-film"].exists(within: 5), "Group Film is offered where the app has a server")
        keep(app, "Catalog-group-film")
        chooseCamera("disposable1990s", app)
        let load = app.buttons["load-film"]
        XCTAssertTrue(load.exists(within: 10), "A personal Film goes straight to Load Film")
        XCTAssertFalse(app.staticTexts["Hosting needs an Account"].exists)
        XCTAssertFalse(app.staticTexts["Sign in to host"].exists)
    }

    func testAPersonUnder13IsNotSignedUpAndStaysSignedOut() throws {
        let app = app(hosting: "signedOut")
        app.launch()
        openCameraCatalog(app)
        tapWhole(app, app.buttons["group-film"])
        XCTAssertTrue(app.staticTexts["Hosting needs an Account"].exists(within: 10))
        let continueButton = app.buttons["age-continue"]
        XCTAssertFalse(continueButton.isEnabled, "No answer is chosen for the person")
        choose(month: "January", year: String(Calendar.current.component(.year, from: .now) - 10), app)
        keep(app, "Hosting-age")
        try audit(app, name: "Hosting-age", for: JournalFlowTests.auditTypes)
        continueButton.tap()
        XCTAssertTrue(app.staticTexts["You can't sign in yet"].exists(within: 5))
        keep(app, "Hosting-too-young")
        app.buttons["too-young-back"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5))
        // Going back does not offer the question again straight away.
        tapWhole(app, app.buttons["group-film"])
        XCTAssertTrue(app.staticTexts["You can't sign in yet"].exists(within: 5))
        app.buttons["too-young-back"].tap()
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sign-out"].exists, "Nobody was signed in")
    }

    func testSigningInMakesTheAccountAndDeleteAccountIsTwoTapsFromSettings() throws {
        let app = app(hosting: "signedOut")
        app.launch()
        openCameraCatalog(app)
        tapWhole(app, app.buttons["group-film"])
        XCTAssertTrue(app.staticTexts["Hosting needs an Account"].exists(within: 10))
        choose(month: "March", year: "2000", app)
        app.buttons["age-continue"].tap()
        XCTAssertTrue(app.staticTexts["Sign in to host"].exists(within: 5))
        XCTAssertTrue(app.buttons["sign-in-apple"].exists, "Sign in with Apple is offered")
        XCTAssertTrue(app.buttons["sign-in-google"].exists)
        keep(app, "Hosting-sign-in")
        try audit(app, name: "Hosting-sign-in", for: JournalFlowTests.auditTypes)
        app.buttons["sign-in-email"].tap()
        let address = app.textFields["email-address"]
        XCTAssertTrue(address.exists(within: 5))
        address.tap()
        address.typeText("host@example.com")
        app.buttons["email-send"].tap()
        let code = app.textFields["email-code"]
        XCTAssertTrue(code.exists(within: 5))
        code.tap()
        code.typeText("424242")
        app.buttons["email-verify"].tap()
        XCTAssertTrue(app.textFields["group-title"].exists(within: 10), "Signed in, with an Account, at Load Film")
        keep(app, "Hosting-signed-in")
        app.navigationBars["Group Film"].buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()

        // Two taps: Settings, then Delete Account; the confirmation follows.
        app.buttons["Settings"].tap()
        let delete = app.buttons["delete-account"]
        XCTAssertTrue(delete.exists(within: 5))
        XCTAssertTrue(app.staticTexts["account-name"].exists)
        scrollUpUntilWhole(app, delete)
        keep(app, "Settings-account")
        try audit(app, name: "Settings-account", for: JournalFlowTests.auditTypes)
        tapWhole(app, delete)
        let confirm = app.buttons.matching(identifier: "confirm-delete-account").firstMatch
        XCTAssertTrue(confirm.exists(within: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'cannot be recalled'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'personal Films stay on this iPhone'")).firstMatch.exists)
        keep(app, "Delete-account-confirmation")
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["account-deleted"].exists(within: 10))
        XCTAssertTrue(app.buttons["delete-account"].isGone(within: 5))
        XCTAssertFalse(app.buttons["sign-out"].exists)
    }

    func testASignedInHostSeesTheServersPrivacyWordsAndCanSignOut() {
        let app = app(hosting: "signedIn")
        app.launch()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Your personal Films stay on this iPhone'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'No Accounts'")).firstMatch.exists)
        let signOut = app.buttons["sign-out"]
        XCTAssertTrue(signOut.exists(within: 5))
        XCTAssertTrue(heading("Account", app).exists, "Signed in, the Account has its heading")
        tapWhole(app, signOut)
        XCTAssertTrue(signOut.isGone(within: 5))
        XCTAssertTrue(heading("Account", app).isGone(within: 5), "Signed out, the Account's heading goes with it")
    }

    /// A section heading (`OrbitSectionLabel`), drawn in capitals and labeled as written.
    private func heading(_ label: String, _ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func choose(month: String, year: String, _ app: XCUIApplication) {
        app.buttons["birth-month"].tap()
        let monthButton = app.buttons[month]
        XCTAssertTrue(monthButton.exists(within: 5))
        monthButton.tap()
        let yearField = app.textFields["birth-year"]
        XCTAssertTrue(yearField.exists(within: 5))
        yearField.tap()
        yearField.typeText(year)
        XCTAssertTrue(app.buttons["age-continue"].isEnabled)
    }
}
