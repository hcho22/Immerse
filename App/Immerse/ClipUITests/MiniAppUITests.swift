import XCTest

/// The mini-app (v2 Stage 3, V2-FR-19 to V2-FR-21, V2-FR-35, V2-FR-71): the App Clip, opened in the simulator by an
/// event's link handed to it as it starts, against the Debug-only stand-in for the server's event functions, so no real service is reached. A guest goes from
/// the link to the shooting screen with only a name and one tap and is never asked to sign in; everyone who cannot join
/// is told why; a picture that waits is never called sent; and the revealed album shows with the invitation to install
/// the full app and saves one picture through the share sheet.
///
/// What no simulator shows: the App Clip card and a scanned QR code opening the mini-app (they need a released build and
/// the associated domain), the time from scan to shooting screen (measure M-2), the camera itself, and what the share
/// sheet may save to Photos on an iPhone (open check OC-6). Those are section J of Evidence/NativeApp/manual-validation.md.
@MainActor
final class MiniAppUITests: ScreenTestCase {
    private static let link = "https://join.immerse.test/j/OpenEventCodeForTests0"
    /// Every audit but the Dynamic Type one, which no audit runs (Evidence/NativeApp/qa13-audit-exceptions-052.md).
    private let auditTypes = XCUIAccessibilityAuditType.all.subtracting(.dynamicType)

    /// Launches the mini-app, by an event's link when one is given: XCTest hands the link to the App Clip as it starts,
    /// which is the invocation a test can make. (`_XCAppClipURL` is honoured only by Xcode's own Run action.)
    private func launchMiniApp(_ scenario: String = "open", link: String? = MiniAppUITests.link) -> XCUIApplication {
        let app = XCUIApplication()
        // The note before the first save shows in every run, whatever an earlier run left on the simulator.
        app.launchArguments += ["-ImmerseDebugHosting", "signedOut", "-ImmerseDebugGroupFilm", scenario,
                                "-KeyboardAutocorrection", "NO", "-ImmerseSavedCopiesNoteShown", "NO"]
        if let link, let url = URL(string: link) { app.open(url) } else { app.launch() }
        return app
    }

    private func text(_ app: XCUIApplication, containing words: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    func testAGuestGoesFromTheLinkToTheShootingScreenWithANameAndOneTapAndIsNeverAskedToSignIn() throws {
        let app = launchMiniApp()
        XCTAssertTrue(app.staticTexts["join-title"].exists(within: 15), "The link opens the Join Confirmation")
        XCTAssertEqual(app.staticTexts["join-title"].label, "Ana & Leo")
        XCTAssertTrue(app.staticTexts["Hosted by Maya"].exists)
        XCTAssertTrue(text(app, containing: "Disposable, 27 exposures").exists)
        XCTAssertTrue(text(app, containing: "Shooting ends").exists)
        XCTAssertTrue(text(app, containing: "The album reveals").exists)
        XCTAssertTrue(text(app, containing: "Every picture stays sealed until the reveal, yours included.").exists)
        XCTAssertFalse(text(app, containing: "Sign in").exists, "Nobody is asked to sign in")
        XCTAssertFalse(app.buttons["Cancel"].exists, "The confirmation is the whole screen")
        keep(app, "MiniApp-join-confirmation")
        // Take a Roll is dimmed until there is a name, so its contrast is read on the event's page, at rest.
        XCTAssertEqual(try audit(app, name: "mini-app-join", for: auditTypes.subtracting(.contrast)), [])

        let name = app.textFields["join-name"]
        name.tap()
        name.typeText("Jo")
        // The one tap.
        app.buttons["join-take-roll"].tap()
        // iOS asks for the camera the first time, as for any camera; the question is the system's, not a step of joining.
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        // The shooting screen of the event's Camera is up; the simulator has no camera to show in it.
        XCTAssertTrue(app.buttons["capture-shutter"].exists(within: 20), "Taking a Roll opens the shooting screen")
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertFalse(app.staticTexts["group-event-title"].isHittable, "The camera is over the event's page")
        keep(app, "MiniApp-shooting-screen")

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["group-event-title"].exists(within: 10))
        XCTAssertTrue(app.staticTexts["27 of 27 exposures left"].exists(within: 5))
        XCTAssertTrue(app.buttons["group-open-camera"].exists)
        XCTAssertTrue(text(app, containing: "Installing Immerse keeps your place").exists, "An unsigned mini-app guest is told where their place lives")
        XCTAssertFalse(app.buttons["group-claim"].exists, "Signing in is the full app's")
        XCTAssertFalse(text(app, containing: "Your Group Film").exists, "Hosting is the full app's")
        keep(app, "MiniApp-event-page")
        XCTAssertEqual(try audit(app, name: "mini-app-event", for: auditTypes), [])
    }

    func testEveryoneWhoCannotJoinNowIsToldWhy() {
        for (scenario, words) in [("paused", "Joining is paused for now."),
                                  ("full", "Every Roll has been taken. The Host can add more."),
                                  ("scheduled", "This event opens"),
                                  ("ended", "Shooting has ended. The album reveals")] {
            let app = launchMiniApp(scenario)
            XCTAssertTrue(app.staticTexts["join-title"].exists(within: 15), scenario)
            XCTAssertTrue(text(app, containing: words).exists(within: 5), scenario)
            XCTAssertFalse(app.buttons["join-take-roll"].exists, "\(scenario): nobody can take a Roll")
            keep(app, "MiniApp-cannot-join-\(scenario)")
            app.terminate()
        }
        // A code that opens no event, as a deleted event's or an ended album's.
        let gone = launchMiniApp(link: "https://join.immerse.test/j/NoSuchEventCodeAtAll00")
        XCTAssertTrue(text(gone, containing: "This event is no longer available.").exists(within: 15))
        XCTAssertFalse(gone.buttons["join-take-roll"].exists)
    }

    func testOpenedWithNoLinkOrAnotherSitesLinkItSaysHowToJoin() {
        for link in [nil, "https://elsewhere.example.com/j/OpenEventCodeForTests0", "https://join.immerse.test/"] {
            let app = launchMiniApp(link: link)
            XCTAssertTrue(app.staticTexts["mini-app-empty"].exists(within: 15), link ?? "no link")
            XCTAssertFalse(app.staticTexts["join-title"].exists)
            app.terminate()
        }
    }

    func testAPictureThatWaitsIsNeverCalledSentAndTheGuestIsAskedToKeepTheMiniAppOpen() {
        // Opened again with no link, the mini-app goes back to the event this iPhone holds.
        let app = launchMiniApp("waiting", link: nil)
        XCTAssertTrue(app.staticTexts["group-event-title"].exists(within: 15))
        let count = app.staticTexts["group-upload-count"]
        scrollUp(app, until: count)
        XCTAssertTrue(count.exists(within: 10))
        XCTAssertEqual(count.label, "1 waiting to send, 0 sent")
        XCTAssertFalse(app.staticTexts["All your pictures are sent"].exists)
        XCTAssertTrue(text(app, containing: "Keep Immerse open until all your pictures are sent, or come back through the same link.").exists)
        keep(app, "MiniApp-waiting")
    }

    func testTheRevealedAlbumInvitesTheGuestToInstallAndSavesOnePictureThroughTheShareSheet() throws {
        let app = launchMiniApp("revealed", link: nil)
        let pictures = app.buttons.matching(identifier: "group-album-picture")
        XCTAssertTrue(pictures.firstMatch.exists(within: 15), "Opened with no link, the mini-app shows the event's album")
        XCTAssertEqual(pictures.count, 3)
        XCTAssertTrue(app.descendants(matching: .any)["group-album-gap"].exists)
        let invitation = text(app, containing: "Get Immerse to be told when a Film is ready")
        scrollUp(app, until: invitation)
        XCTAssertTrue(invitation.exists, "The invitation to install the full app")
        XCTAssertTrue(text(app, containing: "This mini-app saves one picture at a time, through the share sheet.").exists)
        XCTAssertFalse(app.buttons["group-save-all"].exists, "Saving the whole album to Photos is the full app's")
        keep(app, "MiniApp-album")

        app.buttons["Picture 2, by Jo"].tap()
        XCTAssertTrue(app.staticTexts["group-picture-name"].exists(within: 5))
        app.buttons["group-picture-save"].tap()
        // Once, before the first save: a saved copy cannot be recalled (V2-FR-44).
        let note = text(app, containing: "A saved picture is your own copy")
        XCTAssertTrue(note.exists(within: 5), "The note shows over the picture")
        app.buttons["group-confirm-action"].tap()
        let sheet = app.otherElements["ActivityListView"]
        if !sheet.exists(within: 15) {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "MiniApp-share-sheet-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        keep(app, "MiniApp-share-sheet")
        XCTAssertTrue(sheet.exists, "The system's share sheet takes the picture")
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
