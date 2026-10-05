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
}
