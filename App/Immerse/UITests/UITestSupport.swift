import XCTest

extension XCUIScreen {
    /// The screen as it appears, in either orientation. In landscape, `XCUIApplication.screenshot()` turned the image
    /// sideways a second time and cropped it, and the screen's own capture keeps the display's portrait pixels with an
    /// orientation flag that attachments and `cgImage` drop, so the capture is redrawn upright
    /// (Evidence/NativeApp/scroll-indicator-drag-053.md).
    func uprightScreenshot() -> UIImage {
        let screen = screenshot().image
        let format = UIGraphicsImageRendererFormat()
        format.scale = screen.scale
        return UIGraphicsImageRenderer(size: screen.size, format: format).image { _ in screen.draw(at: .zero) }
    }
}

@MainActor
extension XCTestCase {
    /// Scrolls up in equal, slow drags that end held, so the list never coasts, until `element` can be tapped.
    /// Free swipes coasted a different distance each run, which changed the rows under the bars at each audit
    /// (Evidence/NativeApp/qa13-audit-exceptions-052.md). The drag runs in the left margin, outside the rows' controls
    /// and away from the scroll indicator, which a right-edge drag can grab and scrub the list back toward its start
    /// (Evidence/NativeApp/scroll-indicator-drag-053.md). It starts low on the screen, where a raised keyboard would take the drag.
    func scrollUp(_ app: XCUIApplication, until element: XCUIElement) {
        scrollUp(app) { element.isHittable }
    }

    /// Scrolls up in the same held drags until `done` holds.
    @nonobjc func scrollUp(_ app: XCUIApplication, until done: () -> Bool) {
        for _ in 0..<16 where !done() {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    /// Taps Start a Film and waits for the Camera catalog sheet. One CI run (main, run 37627486582) delivered the tap at the
    /// button's centre, (201, 822), exactly where every passing launch did, and the Journal stayed on screen for the next
    /// six seconds with no sheet; no repeat could reproduce it (Evidence/NativeApp/ci-flakes-057.md). The tap therefore
    /// gets one more try, but only after the first one demonstrably did nothing, and the miss is kept as a screenshot.
    func openCameraCatalog(_ app: XCUIApplication) {
        let start = app.buttons["start-film"]
        let catalog = app.navigationBars["Choose a Camera"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        if catalog.waitForExistence(timeout: 5) { return }
        let miss = XCTAttachment(screenshot: app.screenshot())
        miss.name = "Start-a-Film-tap-did-not-open-the-catalog"
        miss.lifetime = .keepAlways
        add(miss)
        start.tap()
        XCTAssertTrue(catalog.waitForExistence(timeout: 5), "The Camera catalog did not open after two taps on Start a Film")
    }
}
