import XCTest

/// Measures that every text element on the Movie Load Film screens follows the person's text size, in the
/// simulator's light or dark appearance. It stands in for Xcode's Dynamic Type audit at those screens' three
/// audit points, which grows the text in place and over the lazy Form flagged different rows from run to run
/// (Evidence/NativeApp/qa13-audit-exceptions-052.md). Each element's text must grow by at least 4 percent at every
/// step from L to AX XXXL, never shrink below L, and never be clipped by its frame or the screen.
@MainActor
final class ContentSizeTests: XCTestCase {
    /// A text element to measure, found in an accessibility snapshot by type and identifier or exact label.
    private struct Target {
        let name: String
        let type: XCUIElement.ElementType
        var identifier: String? = nil
        var label: String? = nil
        /// Whether the text itself is tinted. Otherwise only neutral pixels count as text, so a tinted icon
        /// beside it, such as the entitlement ticket, which the list keeps near one size, is not measured.
        var tinted = false

        @MainActor func find(in root: XCUIElementSnapshot) -> XCUIElementSnapshot? {
            var matches: [XCUIElementSnapshot] = []
            func visit(_ element: XCUIElementSnapshot) {
                if element.elementType == type, identifier.map({ element.identifier == $0 }) ?? true,
                   label.map({ element.label == $0 }) ?? true {
                    matches.append(element)
                }
                element.children.forEach(visit)
            }
            visit(root)
            // "Silent capture" combines its icon and text; the inner text element is the narrower match.
            return matches.min { $0.frame.width < $1.frame.width }
        }
    }

    private struct Sample {
        let frame: CGRect
        let ink: Int
        let navigation: CGFloat
    }

    private static let superEight: [Target] = [
        Target(name: "Capacity", type: .staticText, label: "Capacity, 3 minutes 20 seconds of film"),
        Target(name: "Reveal", type: .staticText, label: "One silent Movie after Development"),
        Target(name: "Controls", type: .staticText, label: "Handheld, pronounced grain and flicker"),
        Target(name: "Silent capture", type: .staticText, label: "Silent capture"),
        Target(name: "Movie Orientation", type: .staticText, label: "Movie Orientation"),
        Target(name: "Portrait", type: .button, label: "Portrait"),
        Target(name: "Landscape", type: .button, label: "Landscape"),
        Target(name: "Film title", type: .staticText, identifier: "film-title-heading"),
        Target(name: "Title field", type: .textField, identifier: "film-title"),
        Target(name: "Entitlement", type: .staticText, identifier: "load-entitlement"),
        Target(name: "Note", type: .staticText, identifier: "load-note"),
        Target(name: "Subscription", type: .button, label: "Subscription"),
        Target(name: "Load Film", type: .button, identifier: "load-film", tinted: true),
    ]

    private static let sixteenMillimeter: [Target] = [
        Target(name: "16mm Capacity", type: .staticText, label: "Capacity, 2 minutes 45 seconds of film"),
        Target(name: "16mm Controls", type: .staticText, label: "Deliberate framing, finer grain"),
    ]

    private static let sizes = ["XS", "S", "M", "L", "XL", "XXL", "XXXL",
                                "AccessibilityM", "AccessibilityL", "AccessibilityXL", "AccessibilityXXL", "AccessibilityXXXL"]

    /// Samples by target and then by size and appearance, from every size measured in this run. Each test
    /// measures one size, to stay inside the per-test time allowance, and checks growth against whichever
    /// neighboring sizes are already here, so a full run checks every step from XS to AX XXXL in any order.
    private static var measured: [String: [String: Sample]] = [:]

    /// The simulator's appearance, which the run sets (`xcrun simctl ui <device> appearance`); setting
    /// `XCUIDevice.shared.appearance` from the test did not change the app's rendering on iOS 26.5.
    private static var appearance: String { XCUIDevice.shared.appearance == .dark ? "dark" : "light" }

    func testLoadScreenTextAtExtraSmall() throws { check("XS") }
    func testLoadScreenTextAtSmall() throws { check("S") }
    func testLoadScreenTextAtMedium() throws { check("M") }
    func testLoadScreenTextAtLarge() throws { check("L") }
    func testLoadScreenTextAtExtraLarge() throws { check("XL") }
    func testLoadScreenTextAtExtraExtraLarge() throws { check("XXL") }
    func testLoadScreenTextAtExtraExtraExtraLarge() throws { check("XXXL") }
    func testLoadScreenTextAtAccessibilityMedium() throws { check("AccessibilityM") }
    func testLoadScreenTextAtAccessibilityLarge() throws { check("AccessibilityL") }
    func testLoadScreenTextAtAccessibilityExtraLarge() throws { check("AccessibilityXL") }
    func testLoadScreenTextAtAccessibilityExtraExtraLarge() throws { check("AccessibilityXXL") }
    func testLoadScreenTextAtAccessibilityExtraExtraExtraLarge() throws { check("AccessibilityXXXL") }

    private func check(_ category: String) {
        var rows: [String] = []
        let app = XCUIApplication.shippingGate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"]
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        app.buttons["start-film"].tap()
        for (camera, title, targets) in [("camera-super8HomeMovie", "Super 8", Self.superEight),
                                         ("camera-cinema16mm", "16mm", Self.sixteenMillimeter)] {
            let row = app.buttons[camera]
            for _ in 0..<8 where !row.isHittable { drag(app, by: -300) }
            row.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "\(title) \(category)")
            // Let the push finish, so the first rows are measured where they rest rather than mid-transition.
            Thread.sleep(forTimeInterval: 1)
            for (tag, sample) in measure(app, targets, category) {
                Self.measured[tag.name, default: [:]][tag.variant] = sample
                rows.append("\(tag.variant) \(tag.name) frame=\(sample.frame) ink=\(sample.ink) navigation=\(sample.navigation)")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.terminate()
        let summary = XCTAttachment(string: rows.joined(separator: "\n"))
        summary.name = "measurements"
        summary.lifetime = .keepAlways
        add(summary)

        // Every text style grows at each step from L up, by at least 6.7 percent in measured text height here, so a
        // 4 percent minimum also catches text clipped by a container, whose visible slice gains only a pixel or two.
        // Below L, Apple's Dynamic Type table keeps some styles at one size (footnote is 12 points at XS, S and M),
        // so there the text must only never shrink.
        let index = Self.sizes.firstIndex(of: category)!
        let neighbors = [index - 1, index + 1].filter { Self.sizes.indices.contains($0) }
        for neighbor in neighbors {
            let (smaller, larger) = (Self.sizes[min(index, neighbor)], Self.sizes[max(index, neighbor)])
            for target in Self.superEight + Self.sixteenMillimeter {
                guard let from = Self.measured[target.name]?["\(smaller) \(Self.appearance)"],
                      let to = Self.measured[target.name]?["\(larger) \(Self.appearance)"] else { continue }
                if Self.sizes.firstIndex(of: smaller)! >= Self.sizes.firstIndex(of: "L")! {
                    XCTAssertGreaterThanOrEqual(to.ink * 100, from.ink * 104,
                                                "\(target.name) text grows from \(smaller) (\(from.ink) px) to \(larger) (\(to.ink) px)")
                } else {
                    XCTAssertGreaterThanOrEqual(to.ink, from.ink, "\(target.name) text never shrinks from \(smaller) to \(larger)")
                }
                XCTAssertGreaterThanOrEqual(to.frame.height, from.frame.height,
                                            "\(target.name) frame keeps growing from \(smaller) to \(larger)")
            }
        }
    }

    /// Scrolls the screen down in held drags from where it opens, and samples each target once it is fully on
    /// screen, between the navigation bar and the home indicator.
    private func measure(_ app: XCUIApplication, _ targets: [Target], _ category: String) -> [((name: String, variant: String), Sample)] {
        var results: [((name: String, variant: String), Sample)] = []
        var done: Set<String> = []
        for _ in 0..<30 {
            guard let root = try? app.snapshot() else { continue }
            let window = root.frame
            let navigation = Target(name: "", type: .navigationBar).find(in: root)?.frame.maxY ?? window.minY
            let ready = targets.filter { !done.contains($0.name) }.compactMap { target -> (Target, CGRect)? in
                guard let frame = target.find(in: root)?.frame, !frame.isEmpty,
                      // At the top the bar's edge and the first row meet at the same point, give or take rounding.
                      frame.minY >= navigation - 1, frame.maxY <= window.maxY - 34 else { return nil }
                return (target, frame)
            }
            if !ready.isEmpty {
                let shot = app.screenshot()
                let tag = "\(category) \(Self.appearance)"
                for (target, frame) in ready {
                    XCTAssertGreaterThanOrEqual(frame.minX, window.minX, "\(target.name) \(tag) starts on screen")
                    XCTAssertLessThanOrEqual(frame.maxX, window.maxX, "\(target.name) \(tag) ends on screen")
                    let ink = inkExtent(shot, frame, in: window, tinted: target.tinted)
                    XCTAssertLessThanOrEqual(ink.top, ink.bottom, "\(target.name) \(tag) text is found in its frame")
                    XCTAssertGreaterThan(ink.top, 0, "\(target.name) \(tag) text is not clipped at the top")
                    XCTAssertLessThan(ink.bottom, ink.height - 1, "\(target.name) \(tag) text is not clipped at the bottom")
                    results.append(((target.name, tag), Sample(frame: frame, ink: ink.bottom - ink.top + 1, navigation: navigation)))
                    done.insert(target.name)
                }
                attach(shot, "\(tag) \(ready.map(\.0.name).joined(separator: ", "))")
            }
            if done.count == targets.count { break }
            // Short enough that every target, up to about 250 points tall at the largest size, is fully on
            // screen at some step.
            drag(app, by: -380)
        }
        for target in targets where !done.contains(target.name) {
            XCTFail("\(target.name) \(category) was never fully on screen below the navigation bar")
        }
        return results
    }

    /// A slow drag that ends held, so the list does not coast; negative distances scroll toward the end. It runs
    /// in the left margin, outside the rows' controls and away from the scroll indicator: on the right edge a drag
    /// that starts while the indicator still shows from the previous one grabs it and scrubs the list back toward
    /// its start (Evidence/NativeApp/scroll-indicator-drag-053.md).
    private func drag(_ app: XCUIApplication, by distance: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// Rows of an element's area in a screen screenshot that hold text: pixels far from the area's most common
    /// color, and unless the text is tinted, neutral ones only.
    private func inkExtent(_ screenshot: XCUIScreenshot, _ frame: CGRect, in window: CGRect,
                           tinted: Bool) -> (top: Int, bottom: Int, height: Int) {
        guard let full = screenshot.image.cgImage else { return (0, 0, 0) }
        let scale = CGFloat(full.width) / window.width
        let crop = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale).integral
        guard let image = full.cropping(to: crop) else { return (0, 0, 0) }
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (0, 0, height) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var counts: [Int: Int] = [:]
        for i in stride(from: 0, to: data.count, by: 4) {
            // Colors in 8-level steps per channel, so antialiasing does not split the background.
            counts[(Int(data[i]) / 8) * 1024 + (Int(data[i + 1]) / 8) * 32 + Int(data[i + 2]) / 8, default: 0] += 1
        }
        let mode = counts.max { $0.value < $1.value }!.key
        let background = (mode / 1024 * 8 + 4, mode / 32 % 32 * 8 + 4, mode % 32 * 8 + 4)
        var top = height, bottom = -1
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let (r, g, b) = (Int(data[i]), Int(data[i + 1]), Int(data[i + 2]))
                let distance = abs(r - background.0) + abs(g - background.1) + abs(b - background.2)
                // Text is antialiased in gray steps; a tinted icon's pale edges differ across channels.
                let neutral = max(r, g, b) - min(r, g, b) < 12
                if distance > 200, tinted || neutral { top = min(top, y); bottom = max(bottom, y); break }
            }
        }
        return (top, bottom, height)
    }

    private func attach(_ screenshot: XCUIScreenshot, _ name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
