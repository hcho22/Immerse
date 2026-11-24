import XCTest

/// Group Films in the full app (v2 Stage 2), against the Debug-only stand-in for the server's event functions
/// (`DebugGroupFilms.swift`), so no real service is reached: the Host loads a Group Film and gets its link and QR code at
/// once; a guest opens the link and joins with only a name and one tap, never asked to sign in; and the revealed album
/// shows its pictures in order with a numbered gap, each with its shooter's name in its details. The server's own rules
/// are held by Backend/tests; the whole event on real iPhones is section S of Evidence/NativeApp/manual-validation.md.
@MainActor
final class GroupFilmUITests: ScreenTestCase {
    private func app(hosting: String, scenario: String = "open", link: String? = nil) -> XCUIApplication {
        // Joining and Load Film ask once to allow "Your Film is ready"; declining blocks nothing (V2-FR-70).
        addUIInterruptionMonitor(withDescription: "Notifications") { alert in
            guard alert.buttons["Don’t Allow"].exists else { return false }
            alert.buttons["Don’t Allow"].tap()
            return true
        }
        let app = XCUIApplication()
        app.launchArguments += ["-ImmerseDebugHosting", hosting, "-ImmerseDebugGroupFilm", scenario,
                                "-KeyboardAutocorrection", "NO"]
        if let link { app.launchArguments += ["-ImmerseDebugJoinLink", link] }
        return app
    }

    func testAHostLoadsAGroupFilmAndGetsItsLinkAndQRCodeAtOnce() {
        let app = app(hosting: "signedIn")
        app.launch()
        openCameraCatalog(app)
        tapWhole(app, app.buttons["group-film"])
        let title = app.textFields["group-title"]
        XCTAssertTrue(title.exists(within: 10), "A signed-in Host goes straight to Load Film")
        title.tap()
        title.typeText("Garden Party")
        XCTAssertTrue(app.buttons["group-camera-6x6"].exists)
        XCTAssertTrue(app.buttons["group-camera-instant"].exists)
        keep(app, "GroupFilm-load")
        let load = app.buttons["group-load"]
        scrollUpUntilWhole(app, load)
        tapWhole(app, load)
        let confirm = app.buttons.matching(identifier: "confirm-group-load").firstMatch
        XCTAssertTrue(confirm.exists(within: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'cannot change after Load Film'")).firstMatch.exists)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["group-event-title"].exists(within: 10), "Load Film opens the event's page")
        XCTAssertTrue(app.images["group-qr"].exists(within: 5), "The QR code shows at once")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'https://join.immerse.test/j/'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["group-roll-counts"].exists(within: 5))
        keep(app, "GroupFilm-host-page")
    }

    /// The view-only web album's switch (v2 Stage 3, V2-FR-47): absent before the reveal, off after it until the Host
    /// turns it on, and it says that anyone with the link can then see the pictures.
    func testTheHostSwitchesTheWebAlbumOnAfterTheRevealAndOffAgain() {
        let app = app(hosting: "signedIn")
        app.launch()
        openCameraCatalog(app)
        tapWhole(app, app.buttons["group-film"])
        let title = app.textFields["group-title"]
        XCTAssertTrue(title.exists(within: 10))
        title.tap()
        title.typeText("Garden Party")
        let load = app.buttons["group-load"]
        scrollUpUntilWhole(app, load)
        tapWhole(app, load)
        let confirm = app.buttons.matching(identifier: "confirm-group-load").firstMatch
        XCTAssertTrue(confirm.exists(within: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["group-event-title"].exists(within: 10))
        XCTAssertFalse(app.switches["group-web-album"].exists, "Before the reveal there is no album to share")
        // Ending early reveals the album at once (V2-FR-40).
        let end = app.buttons["group-end-early"]
        scrollUpUntilWhole(app, end)
        tapWhole(app, end)
        let confirmEnd = app.buttons.matching(identifier: "confirm-end-early").firstMatch
        XCTAssertTrue(confirmEnd.exists(within: 5))
        confirmEnd.tap()
        let webAlbum = app.switches["group-web-album"]
        scrollUp(app) { webAlbum.exists }
        XCTAssertTrue(webAlbum.exists(within: 10), "After the reveal the Host can share the album on the web")
        scrollUpUntilWhole(app, webAlbum)
        XCTAssertEqual(webAlbum.value as? String, "0", "Off unless the Host turns it on")
        let note = app.staticTexts["group-web-album-note"]
        XCTAssertTrue(note.label.hasPrefix("Off: the pictures are seen only by the people who joined."), note.label)
        webAlbum.switches.firstMatch.exists ? webAlbum.switches.firstMatch.flipSwitch() : webAlbum.flipSwitch()
        let on = NSPredicate(format: "label BEGINSWITH %@", "Anyone with the event's link can see and save the pictures on the web")
        XCTAssertTrue(app.staticTexts.matching(on).firstMatch.exists(within: 10), "The switch says who can see the album")
        XCTAssertEqual(webAlbum.value as? String, "1")
        keep(app, "GroupFilm-web-album-on")
        webAlbum.switches.firstMatch.exists ? webAlbum.switches.firstMatch.flipSwitch() : webAlbum.flipSwitch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Off: the pictures are seen only")).firstMatch.exists(within: 10))
        XCTAssertEqual(webAlbum.value as? String, "0")
    }

    func testAGuestJoinsByTheLinkWithANameAndOneTapAndIsNeverAskedToSignIn() {
        let app = app(hosting: "signedOut", link: "https://join.immerse.test/j/OpenEventCodeForTests0")
        app.launch()
        XCTAssertTrue(app.staticTexts["join-title"].exists(within: 15), "The link opens the Join Confirmation")
        XCTAssertTrue(app.staticTexts["Hosted by Maya"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Disposable, 27 exposures'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Every picture stays sealed'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Sign in to host"].exists)
        keep(app, "GroupFilm-join-confirmation")
        let name = app.textFields["join-name"]
        name.tap()
        name.typeText("Jo")
        app.buttons["join-take-roll"].tap()
        XCTAssertTrue(app.staticTexts["group-event-title"].exists(within: 10), "Joining opens the event's page")
        XCTAssertTrue(app.staticTexts["27 of 27 exposures left"].exists(within: 5))
        XCTAssertTrue(app.buttons["group-open-camera"].exists)
        XCTAssertFalse(app.staticTexts["Hosting needs an Account"].exists)
        keep(app, "GroupFilm-guest-page")
    }

    func testTheRevealedAlbumShowsEveryPictureInOrderWithANumberedGap() {
        let app = app(hosting: "signedOut", scenario: "revealed")
        app.launch()
        let row = app.buttons.matching(identifier: "journal-group-film").element(boundBy: 0)
        XCTAssertTrue(row.exists(within: 10))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sam’s Birthday' OR label BEGINSWITH \"Sam's Birthday\"")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "group-album-picture").firstMatch.exists(within: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "group-album-picture").count, 3)
        XCTAssertTrue(app.descendants(matching: .any)["group-album-gap"].exists)
        keep(app, "GroupFilm-album")
        app.buttons["Picture 2, by Jo"].tap()
        XCTAssertTrue(app.staticTexts["group-picture-name"].exists(within: 5))
        XCTAssertTrue(app.buttons["group-picture-remove"].exists, "A guest removes their own picture")
        keep(app, "GroupFilm-picture")
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
