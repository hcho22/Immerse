import XCTest

/// The Rolls sheet (v2 Stage 4; V2-FR-60 to V2-FR-65), against Debug-only stand-ins for StoreKit and the server's Roll
/// functions (`DebugRollStore.swift`), so no App Store and no real service is reached: the Host buys a pack from Settings
/// and sees the balance and its history; Ask to Buy waits and the Rolls arrive once approved; a failed purchase changes
/// nothing; and Load Film offers Rolls, saying so when none are on sale. The real StoreKit path is `RollShopStoreKitTests`,
/// the server's rules are Backend/tests, and buying in Apple's sandbox is section B of
/// Evidence/NativeApp/manual-validation.md.
@MainActor
final class RollsUITests: ScreenTestCase {
    private func app(store scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ImmerseDebugHosting", "signedIn", "-ImmerseDebugGroupFilm", "open",
                                "-ImmerseDebugRollStore", scenario]
        return app
    }

    /// Opens the Rolls sheet from Settings, two taps from the Journal.
    private func openRolls(_ app: XCUIApplication) {
        app.buttons["Settings"].tap()
        let rolls = app.buttons["account-rolls"]
        XCTAssertTrue(rolls.exists(within: 10), "Settings shows the signed-in Host's Rolls")
        tapWhole(app, rolls)
        XCTAssertTrue(balance(app).exists(within: 10), "The Rolls sheet shows the balance")
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func balance(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["rolls-balance"]
    }

    private func waitForBalance(_ rolls: Int, _ app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let label = "\(rolls) Rolls in your balance"
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if balance(app).label == label { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return false
    }

    func testTheHostBuysAPackAndSeesTheBalanceAndItsHistory() throws {
        let app = app(store: "onSale")
        app.launch()
        openRolls(app)
        XCTAssertTrue(waitForBalance(3, app), "Everyone's free Rolls are in the balance")
        let pack = app.buttons["rolls-pack-debug.rolls.small"]
        XCTAssertTrue(pack.exists(within: 10))
        XCTAssertEqual(pack.label, "Buy 5 Rolls for $0.01", "The pack's size is the server's and its price the App Store's")
        keep(app, "Rolls-on-sale")
        try audit(app, name: "Rolls-on-sale", for: JournalFlowTests.auditTypes)
        tapWhole(app, pack)
        XCTAssertTrue(waitForBalance(8, app), "The purchase adds its Rolls once the server confirms it")
        let notice = app.descendants(matching: .any)["rolls-notice"]
        XCTAssertTrue(notice.exists(within: 5))
        XCTAssertTrue(notice.label.contains("5 Rolls added to your balance."))
        XCTAssertTrue(app.staticTexts["Bought"].exists(within: 5), "The history shows the purchase")
        keep(app, "Rolls-bought")
    }

    func testAskToBuyWaitsAndTheRollsArriveOnceApproved() {
        let app = app(store: "pending")
        app.launch()
        openRolls(app)
        XCTAssertTrue(waitForBalance(3, app))
        tapWhole(app, app.buttons["rolls-pack-debug.rolls.large"])
        let pending = app.descendants(matching: .any)["rolls-pending"]
        XCTAssertTrue(pending.exists(within: 5), "A purchase waiting for approval says so")
        XCTAssertTrue(pending.label.contains("once the purchase is approved"))
        keep(app, "Rolls-pending")
        XCTAssertTrue(waitForBalance(28, app, timeout: 15), "The Rolls arrive once the purchase is approved")
        XCTAssertTrue(pending.isGone(within: 5))
    }

    func testAFailedPurchaseChangesNothing() {
        let app = app(store: "fail")
        app.launch()
        openRolls(app)
        XCTAssertTrue(waitForBalance(3, app))
        tapWhole(app, app.buttons["rolls-pack-debug.rolls.small"])
        let notice = app.descendants(matching: .any)["rolls-notice"]
        XCTAssertTrue(notice.exists(within: 5))
        XCTAssertTrue(notice.label.contains("The purchase did not finish. Your balance is unchanged"))
        XCTAssertTrue(waitForBalance(3, app))
        keep(app, "Rolls-failed")
    }

    func testLoadFilmOffersRollsAndSaysWhenNoneAreOnSale() {
        let app = app(store: "notOnSale")
        app.launch()
        openCameraCatalog(app)
        tapWhole(app, app.buttons["group-film"])
        let buy = app.buttons["buy-rolls"]
        XCTAssertTrue(buy.exists(within: 10), "Load Film offers to buy Rolls (section 7)")
        tapWhole(app, buy)
        XCTAssertTrue(app.descendants(matching: .any)["rolls-not-on-sale"].exists(within: 10),
                      "Before the pricing decision nothing is on sale, and the sheet says so")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'rolls-pack-'")).firstMatch.exists)
        keep(app, "Rolls-not-on-sale")
        app.buttons["rolls-done"].tap()
        XCTAssertTrue(app.buttons["group-load"].exists(within: 5), "Done goes back to Load Film")
    }
}
