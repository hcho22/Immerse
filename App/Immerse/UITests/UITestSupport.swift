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

    /// Scrolls up in the same held drags, `distance` points each, until `done` holds.
    @nonobjc func scrollUp(_ app: XCUIApplication, by distance: CGFloat = 300, until done: () -> Bool) {
        for _ in 0..<16 where !done() {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    /// Taps Start a Film once and waits for the Camera catalog sheet. One CI run (main, run 37627486582) delivered a tap
    /// at the button's centre, (201, 822), where every passing launch did, and the Journal stayed on screen for the
    /// next six seconds with no sheet; no repeat reproduced it (Evidence/NativeApp/ci-flakes-057.md). A second tap
    /// would hide that, so a miss fails here, with a screenshot of what was showing.
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
        XCTFail("The Camera catalog did not open within 5 seconds of the tap on Start a Film")
    }
}
