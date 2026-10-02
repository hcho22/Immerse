import XCTest

/// Measures whether Movie setup text actually follows the person's text size, independent of
/// the original accessibility audits, which this test neither runs nor changes.
@MainActor
final class ContentSizeTests: XCTestCase {
    private let categories = ["XS", "S", "M", "L", "XL", "XXL", "XXXL",
                              "AccessibilityM", "AccessibilityL", "AccessibilityXL", "AccessibilityXXL", "AccessibilityXXXL"]

    func testMovieOrientationSetupTextScalesWithContentSize() throws {
        var rows: [String] = []
        var labelHeights: [CGFloat] = []
        var controlInk: [Int] = []
        for category in categories {
            let app = XCUIApplication()
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"]
            app.launch()
            XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
            app.buttons["start-film"].tap()
            let camera = app.buttons["camera-super8HomeMovie"]
            for _ in 0..<5 where !camera.isHittable { app.swipeUp() }
            camera.tap()
            let label = app.staticTexts["Movie Orientation"]
            for _ in 0..<8 where !(label.exists && label.isHittable) { app.swipeUp() }
            XCTAssertTrue(label.isHittable, category)
            let control = app.buttons["Portrait"]
            for _ in 0..<4 where !(control.exists && control.isHittable) { app.swipeUp() }
            XCTAssertTrue(control.isHittable, category)
            labelHeights.append(label.frame.height)
            let controlShot = control.screenshot()
            controlInk.append(inkHeight(controlShot))
            rows.append("\(category) label=\(label.frame) control=\(control.frame) controlInkPixels=\(controlInk.last!)")
            attach(label.screenshot(), "\(category)-label")
            attach(controlShot, "\(category)-control")
            attach(app.screenshot(), "\(category)-screen")
            app.terminate()
        }
        let summary = XCTAttachment(string: rows.joined(separator: "\n"))
        summary.name = "measurements"
        summary.lifetime = .keepAlways
        add(summary)
        XCTAssertLessThan(labelHeights[0], labelHeights[3], "The label grows from extra small to the default size")
        XCTAssertLessThan(labelHeights[3], labelHeights[11], "The label grows from the default to the largest accessibility size")
        XCTAssertLessThan(controlInk[0], controlInk[3], "Orientation text grows from extra small to the default size")
        XCTAssertLessThan(controlInk[3], controlInk[6], "Orientation text grows from the default to extra extra extra large")
        XCTAssertLessThan(controlInk[6], controlInk[11], "Orientation text grows across accessibility sizes")
    }

    /// Pixel height of the text in an element screenshot, measured against its top-left background color.
    private func inkHeight(_ screenshot: XCUIScreenshot) -> Int {
        guard let image = screenshot.image.cgImage else { return 0 }
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Sample inside the option's padding, away from the rounded corner.
        let inset = (height / 2) * width * 4 + 12 * 4
        let background = (Int(data[inset]), Int(data[inset + 1]), Int(data[inset + 2]))
        var top = height, bottom = -1
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let distance = abs(Int(data[i]) - background.0) + abs(Int(data[i + 1]) - background.1) + abs(Int(data[i + 2]) - background.2)
                if distance > 300 { top = min(top, y); bottom = max(bottom, y); break }
            }
        }
        return bottom >= top ? bottom - top + 1 : 0
    }

    private func attach(_ screenshot: XCUIScreenshot, _ name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
