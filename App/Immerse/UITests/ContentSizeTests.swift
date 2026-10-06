import XCTest

/// Measures that every text element the accessibility audits show follows the person's text size, in the simulator's
/// light or dark appearance: the empty Journal, the Camera catalog, the Super 8 and 16mm Load Film screens and
/// Settings in landscape. It stands in for Xcode's Dynamic Type audit, which grows the text in place and flagged
/// correctly resizing text from run to run (Evidence/NativeApp/qa13-audit-exceptions-052.md and
/// Evidence/NativeApp/scroll-indicator-drag-053.md). Each element's text must grow by at least 4 percent at every
/// step from L to AX XXXL, never shrink below L, and never be clipped by its frame or the screen. Navigation titles
/// are system text and are not included.
@MainActor
final class ContentSizeTests: XCTestCase {
    /// A text element to measure, found in an accessibility snapshot by type and identifier, exact label or label prefix.
    private struct Target {
        let name: String
        let type: XCUIElement.ElementType
        var identifier: String? = nil
        var label: String? = nil
        /// For text whose label carries a value that varies, such as a permission state or an error.
        var labelPrefix: String? = nil
        /// Whether the text itself is tinted. Otherwise only neutral pixels count as text, so a tinted icon
        /// beside it, such as the entitlement ticket, which the list keeps near one size, is not measured.
        var tinted = false
        /// A section header, which spans its row; a control's own text with the same label is narrower.
        var header = false
        /// Text that is shown only in some states, such as a Trial error, and is not required to appear.
        var optional = false
        /// A label the element shows only until the app has read some state, such as "Checking Trial status": the
        /// screen is held where it is until the label changes, so the settled text is measured.
        var unsettled: String? = nil
        /// For the Camera names, set in the serif display face: the label of the capacity line below, 5 pt down.
        /// At XS the "p" descender of "Disposable" ends exactly on the name's own line box, its 3 px foot fully drawn
        /// and nothing beyond it, which reads as clipping against the line box; so the bottom edge is judged against
        /// the gap above the capacity line, where text cut by its row still fails.
        var clearance: String? = nil
        /// A symbol drawn inside the element's frame, which the list keeps near one size: the text is measured
        /// below it (`above`) or beside it (`leading`), by the symbol's accessibility identifier.
        var symbol: (identifier: String, side: SymbolSide)? = nil
        /// The identifier of a text element above whose line box this element's taller frame reaches: the text is
        /// measured below that element's frame.
        var below: String? = nil
        /// The least height of the element's frame, the area that takes a tap, at every size.
        var minimumHeight: CGFloat? = nil

        @MainActor func find(in root: XCUIElementSnapshot) -> XCUIElementSnapshot? {
            var matches: [XCUIElementSnapshot] = []
            func visit(_ element: XCUIElementSnapshot) {
                if element.elementType == type, identifier.map({ element.identifier == $0 }) ?? true,
                   label.map({ element.label == $0 }) ?? true, labelPrefix.map({ element.label.hasPrefix($0) }) ?? true {
                    matches.append(element)
                }
                element.children.forEach(visit)
            }
            visit(root)
            // "Silent capture" combines its icon and text; the inner text element is the narrower match.
            return header ? matches.max { $0.frame.width < $1.frame.width } : matches.min { $0.frame.width < $1.frame.width }
        }

        /// The area that holds the element's text: its frame, less its symbol's side when it has one.
        @MainActor func textFrame(in root: XCUIElementSnapshot) -> CGRect? {
            guard var frame = find(in: root)?.frame else { return nil }
            if let below, let above = Target(name: "", type: .staticText, identifier: below).find(in: root)?.frame {
                frame = CGRect(x: frame.minX, y: max(frame.minY, above.maxY), width: frame.width,
                               height: frame.maxY - max(frame.minY, above.maxY))
            }
            guard let symbol else { return frame }
            var images: [CGRect] = []
            func visit(_ element: XCUIElementSnapshot) {
                if element.elementType == .image, element.identifier == symbol.identifier, element.frame.intersects(frame) {
                    images.append(element.frame)
                }
                element.children.forEach(visit)
            }
            visit(root)
            guard let image = images.first else { return nil }
            switch symbol.side {
            case .above: return CGRect(x: frame.minX, y: image.maxY, width: frame.width, height: frame.maxY - image.maxY)
            case .leading: return CGRect(x: image.maxX, y: frame.minY, width: frame.maxX - image.maxX, height: frame.height)
            }
        }
    }

    private enum SymbolSide { case above, leading }

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
        // The field's frame is at least 44 points tall, centered on its text, so at the smaller sizes it reaches over
        // the heading's line box (Evidence/NativeApp/title-field-hit-area-056.md).
        Target(name: "Title field", type: .textField, identifier: "film-title", below: "film-title-heading", minimumHeight: 44),
        Target(name: "Entitlement", type: .staticText, identifier: "load-entitlement", unsettled: "Checking Trial status"),
        Target(name: "Note", type: .staticText, identifier: "load-note"),
        Target(name: "Subscription", type: .button, label: "Subscription"),
        Target(name: "Load Film", type: .button, identifier: "load-film", tinted: true),
    ]

    private static let sixteenMillimeter: [Target] = [
        Target(name: "16mm Capacity", type: .staticText, label: "Capacity, 2 minutes 45 seconds of film"),
        Target(name: "16mm Controls", type: .staticText, label: "Deliberate framing, finer grain"),
    ]

    /// The empty state's element spans its camera symbol and title; the title is measured below the symbol.
    private static let journal: [Target] = [
        Target(name: "Empty Journal", type: .staticText, label: "Your Journal begins here", symbol: ("camera", .above)),
    ]

    private static let catalog: [Target] = [
        Target(name: "Photo header", type: .staticText, label: "Photo", header: true),
        Target(name: "Disposable", type: .staticText, label: "Disposable", clearance: "27 exposures"),
        Target(name: "Disposable capacity", type: .staticText, label: "27 exposures"),
        Target(name: "Instant", type: .staticText, label: "Instant", clearance: "10 exposures"),
        Target(name: "Instant capacity", type: .staticText, label: "10 exposures"),
        Target(name: "6x6", type: .staticText, label: "6x6", clearance: "12 exposures"),
        Target(name: "6x6 capacity", type: .staticText, label: "12 exposures"),
        Target(name: "Movie header", type: .staticText, label: "Movie", header: true),
        Target(name: "Super 8", type: .staticText, label: "Super 8", clearance: "3 minutes 20 seconds of film"),
        Target(name: "Super 8 capacity", type: .staticText, label: "3 minutes 20 seconds of film"),
        Target(name: "16mm", type: .staticText, label: "16mm", clearance: "2 minutes 45 seconds of film"),
        Target(name: "16mm capacity", type: .staticText, label: "2 minutes 45 seconds of film"),
    ]

    /// Settings as a Debug build shows it with the testing unlock off, including the testing section, in two halves:
    /// at the largest sizes the whole screen takes longer to scroll through than one test may run.
    private static let settingsTop: [Target] = [
        Target(name: "Debug testing header", type: .staticText, label: "Debug testing", header: true),
        Target(name: "Testing unlock", type: .staticText, label: "Testing unlock - Debug build"),
        Target(name: "Testing unlock note", type: .staticText, labelPrefix: "Debug builds only."),
        Target(name: "Storage header", type: .staticText, label: "Storage and backup", header: true),
        Target(name: "Backup", type: .staticText, labelPrefix: "Films, sealed captures"),
        Target(name: "Trial header", type: .staticText, label: "Trial", header: true),
        Target(name: "Trial error", type: .staticText, labelPrefix: "Trial status unavailable:", tinted: true, optional: true),
        Target(name: "Trial rule", type: .staticText, labelPrefix: "One complete Film per iPhone"),
        Target(name: "Trial record", type: .staticText, labelPrefix: "The Trial record stays"),
    ]

    private static let settingsBottom: [Target] = [
        Target(name: "Photos header", type: .staticText, label: "Saving to Photos", header: true),
        Target(name: "Photos exports", type: .staticText, labelPrefix: "Exports are optional."),
        Target(name: "Privacy header", type: .staticText, label: "Privacy", header: true),
        Target(name: "Camera permission", type: .staticText, labelPrefix: "Camera, "),
        Target(name: "Photos permission", type: .staticText, labelPrefix: "Photos (add only), "),
        Target(name: "Microphone", type: .staticText, labelPrefix: "Microphone, "),
        Target(name: "No accounts", type: .staticText, labelPrefix: "No Accounts, sign-in"),
        Target(name: "Open iPhone Settings", type: .button, label: "Open iPhone Settings", tinted: true,
               symbol: ("gearshape", .leading)),
        Target(name: "Subscription header", type: .staticText, label: "Subscription", header: true),
        Target(name: "Settings Subscription", type: .button, label: "Subscription"),
        Target(name: "About header", type: .staticText, label: "About", header: true),
        Target(name: "Version", type: .staticText, labelPrefix: "Immerse, "),
    ]

    private static let sizes = ["XS", "S", "M", "L", "XL", "XXL", "XXXL",
                                "AccessibilityM", "AccessibilityL", "AccessibilityXL", "AccessibilityXXL", "AccessibilityXXXL"]

    /// Samples by target and then by size and appearance, from every size measured in this run. Each test
    /// measures one size of one group of text, to stay inside the per-test time allowance, and checks growth
    /// against whichever neighboring sizes are already here, so a full run checks every step from XS to AX XXXL
    /// in any order.
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

    func testJournalAndCatalogTextAtExtraSmall() throws { checkJournalAndCatalog("XS") }
    func testJournalAndCatalogTextAtSmall() throws { checkJournalAndCatalog("S") }
    func testJournalAndCatalogTextAtMedium() throws { checkJournalAndCatalog("M") }
    func testJournalAndCatalogTextAtLarge() throws { checkJournalAndCatalog("L") }
    func testJournalAndCatalogTextAtExtraLarge() throws { checkJournalAndCatalog("XL") }
    func testJournalAndCatalogTextAtExtraExtraLarge() throws { checkJournalAndCatalog("XXL") }
    func testJournalAndCatalogTextAtExtraExtraExtraLarge() throws { checkJournalAndCatalog("XXXL") }
    func testJournalAndCatalogTextAtAccessibilityMedium() throws { checkJournalAndCatalog("AccessibilityM") }
    func testJournalAndCatalogTextAtAccessibilityLarge() throws { checkJournalAndCatalog("AccessibilityL") }
    func testJournalAndCatalogTextAtAccessibilityExtraLarge() throws { checkJournalAndCatalog("AccessibilityXL") }
    func testJournalAndCatalogTextAtAccessibilityExtraExtraLarge() throws { checkJournalAndCatalog("AccessibilityXXL") }
    func testJournalAndCatalogTextAtAccessibilityExtraExtraExtraLarge() throws { checkJournalAndCatalog("AccessibilityXXXL") }

    func testLandscapeSettingsTopTextAtExtraSmall() throws { checkLandscapeSettings("XS", fromEnd: false) }
    func testLandscapeSettingsTopTextAtSmall() throws { checkLandscapeSettings("S", fromEnd: false) }
    func testLandscapeSettingsTopTextAtMedium() throws { checkLandscapeSettings("M", fromEnd: false) }
    func testLandscapeSettingsTopTextAtLarge() throws { checkLandscapeSettings("L", fromEnd: false) }
    func testLandscapeSettingsTopTextAtExtraLarge() throws { checkLandscapeSettings("XL", fromEnd: false) }
    func testLandscapeSettingsTopTextAtExtraExtraLarge() throws { checkLandscapeSettings("XXL", fromEnd: false) }
    func testLandscapeSettingsTopTextAtExtraExtraExtraLarge() throws { checkLandscapeSettings("XXXL", fromEnd: false) }
    func testLandscapeSettingsTopTextAtAccessibilityMedium() throws { checkLandscapeSettings("AccessibilityM", fromEnd: false) }
    func testLandscapeSettingsTopTextAtAccessibilityLarge() throws { checkLandscapeSettings("AccessibilityL", fromEnd: false) }
    func testLandscapeSettingsTopTextAtAccessibilityExtraLarge() throws { checkLandscapeSettings("AccessibilityXL", fromEnd: false) }
    func testLandscapeSettingsTopTextAtAccessibilityExtraExtraLarge() throws { checkLandscapeSettings("AccessibilityXXL", fromEnd: false) }
    func testLandscapeSettingsTopTextAtAccessibilityExtraExtraExtraLarge() throws { checkLandscapeSettings("AccessibilityXXXL", fromEnd: false) }

    func testLandscapeSettingsBottomTextAtExtraSmall() throws { checkLandscapeSettings("XS", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtSmall() throws { checkLandscapeSettings("S", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtMedium() throws { checkLandscapeSettings("M", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtLarge() throws { checkLandscapeSettings("L", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtExtraLarge() throws { checkLandscapeSettings("XL", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtExtraExtraLarge() throws { checkLandscapeSettings("XXL", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtExtraExtraExtraLarge() throws { checkLandscapeSettings("XXXL", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtAccessibilityMedium() throws { checkLandscapeSettings("AccessibilityM", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtAccessibilityLarge() throws { checkLandscapeSettings("AccessibilityL", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtAccessibilityExtraLarge() throws { checkLandscapeSettings("AccessibilityXL", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtAccessibilityExtraExtraLarge() throws { checkLandscapeSettings("AccessibilityXXL", fromEnd: true) }
    func testLandscapeSettingsBottomTextAtAccessibilityExtraExtraExtraLarge() throws { checkLandscapeSettings("AccessibilityXXXL", fromEnd: true) }

    private func check(_ category: String) {
        var rows: [String] = []
        let app = launch(category)
        app.buttons["start-film"].tap()
        for (camera, title, targets) in [("camera-super8HomeMovie", "Super 8", Self.superEight),
                                         ("camera-cinema16mm", "16mm", Self.sixteenMillimeter)] {
            let row = app.buttons[camera]
            for _ in 0..<8 where !row.isHittable { drag(app, by: -300) }
            row.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "\(title) \(category)")
            // Let the push finish, so the first rows are measured where they rest rather than mid-transition.
            Thread.sleep(forTimeInterval: 1)
            rows += record(measure(app, targets, category, below: title))
            app.navigationBars[title].buttons.element(boundBy: 0).tap()
        }
        app.terminate()
        finish(category, rows, Self.superEight + Self.sixteenMillimeter)
    }

    private func checkJournalAndCatalog(_ category: String) {
        var rows: [String] = []
        let app = launch(category)
        rows += record(measure(app, Self.journal, category, below: "Film Journal"))
        app.buttons["start-film"].tap()
        XCTAssertTrue(app.navigationBars["Choose a Camera"].waitForExistence(timeout: 5), "Catalog \(category)")
        // Let the sheet finish rising, so the first rows are measured where they rest.
        Thread.sleep(forTimeInterval: 1)
        rows += record(measure(app, Self.catalog, category, below: "Choose a Camera"))
        app.terminate()
        finish(category, rows, Self.journal + Self.catalog)
    }

    /// Settings in landscape, where the audit checks it at the largest size. Some paragraphs are taller than the
    /// landscape screen there, so each edge of an element is checked in a pose where that edge is on screen. The top
    /// half is measured scrolling down from the top, and the bottom half scrolling up from the end, which swipes
    /// reach quickly because the list stops there.
    private func checkLandscapeSettings(_ category: String, fromEnd: Bool) {
        let targets = fromEnd ? Self.settingsBottom : Self.settingsTop
        let app = launch(category)
        defer { XCUIDevice.shared.orientation = .portrait }
        app.buttons["start-film"].tap()
        app.buttons["camera-disposable1990s"].tap()
        waitForTrialStatus(app)
        app.navigationBars["Disposable"].buttons.element(boundBy: 0).tap()
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings \(category)")
        let settled = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 10)
        Thread.sleep(forTimeInterval: 1)
        if fromEnd {
            // Flicks that coast reach the end quickly; `swipeUp()` did not scroll this list in landscape.
            let version = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Immerse, ")).firstMatch
            for _ in 0..<20 {
                if version.exists && version.frame.maxY <= app.frame.maxY - 34 { break }
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.8))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)),
                            withVelocity: .fast, thenHoldForDuration: 0)
            }
        }
        let rows = record(measure(app, targets, category, below: "Settings", upward: fromEnd))
        app.terminate()
        finish(category, rows, targets)
    }

    /// Launches at the text size in portrait, whatever orientation an earlier test that ran out of time left.
    private func launch(_ category: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.shippingGate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"]
        app.launch()
        XCTAssertTrue(app.buttons["start-film"].waitForExistence(timeout: 10))
        return app
    }

    /// Waits until the app has read this iPhone's Trial status, which it does after launch. Settings shows no sign
    /// meanwhile and adds the Trial error that an unsigned build shows only afterwards, so the status is read where
    /// a Load screen shows it, as "Checking Trial status" until then.
    private func waitForTrialStatus(_ app: XCUIApplication) {
        let line = app.staticTexts["load-entitlement"]
        // At the larger sizes the line starts below the screen, and the lazy list adds it only once shown.
        for _ in 0..<10 {
            if line.exists { break }
            app.swipeUp()
        }
        let settled = NSPredicate(format: "exists == true AND label != %@", "Checking Trial status")
        wait(for: [XCTNSPredicateExpectation(predicate: settled, object: line)], timeout: 30)
    }

    private func record(_ results: [((name: String, variant: String), Sample)]) -> [String] {
        results.map { tag, sample in
            Self.measured[tag.name, default: [:]][tag.variant] = sample
            return "\(tag.variant) \(tag.name) frame=\(sample.frame) ink=\(sample.ink) navigation=\(sample.navigation)"
        }
    }

    private func finish(_ category: String, _ rows: [String], _ targets: [Target]) {
        let summary = XCTAttachment(string: rows.joined(separator: "\n"))
        summary.name = "measurements"
        summary.lifetime = .keepAlways
        add(summary)

        // Every text style grows at each step from L up, by at least 6.3 percent in measured text height here, so a
        // 4 percent minimum also catches text clipped by a container, whose visible slice gains only a pixel or two.
        // Below L, Apple's Dynamic Type table keeps some styles at one size (footnote is 12 points at XS, S and M),
        // so there the text must only never shrink. Where the frame height is unchanged, 1 px less is allowed, in case
        // the text's position on the pixel grid moves an edge row (decision `raster-rules`); measured from the frames'
        // exact edges, the catalog capacities are 24 px and the Settings testing note 76 px at XS, S and M, in light
        // and dark. A shorter frame, or any larger loss, still fails.
        let index = Self.sizes.firstIndex(of: category)!
        let neighbors = [index - 1, index + 1].filter { Self.sizes.indices.contains($0) }
        for neighbor in neighbors {
            let (smaller, larger) = (Self.sizes[min(index, neighbor)], Self.sizes[max(index, neighbor)])
            for target in targets {
                guard let from = Self.measured[target.name]?["\(smaller) \(Self.appearance)"],
                      let to = Self.measured[target.name]?["\(larger) \(Self.appearance)"] else { continue }
                if Self.sizes.firstIndex(of: smaller)! >= Self.sizes.firstIndex(of: "L")! {
                    XCTAssertGreaterThanOrEqual(to.ink * 100, from.ink * 104,
                                                "\(target.name) text grows from \(smaller) (\(from.ink) px) to \(larger) (\(to.ink) px)")
                } else {
                    let sameSize = abs(to.frame.height - from.frame.height) < 0.001
                    XCTAssertGreaterThanOrEqual(to.ink + (sameSize ? 1 : 0), from.ink,
                                                "\(target.name) text never shrinks from \(smaller) (\(from.ink) px) to \(larger) (\(to.ink) px)")
                }
                // Frames are compared in layout points, which differ only by floating-point rounding at one size.
                XCTAssertGreaterThanOrEqual(to.frame.height, from.frame.height - 0.001,
                                            "\(target.name) frame keeps growing from \(smaller) to \(larger)")
            }
        }
    }

    /// Scrolls the screen down, or up from its end, in held drags, between the named navigation bar and the home
    /// indicator. An element's top edge is checked once it is on screen with the text below it, and its bottom edge
    /// once that is on screen with the text above it; an element that fits is checked in one pose. Each drag is
    /// short enough that every edge reaches such a pose. Each edge keeps the text's distance from the frame's exact
    /// edge in pixels, so the text height is the frame's height less those two, from one pose or two. Text that comes
    /// within half a pixel of an edge, or of the line below a Camera name, is clipped.
    private func measure(_ app: XCUIApplication, _ targets: [Target], _ category: String,
                         below bar: String, upward: Bool = false) -> [((name: String, variant: String), Sample)] {
        let tag = "\(category) \(Self.appearance)"
        var tops: [String: CGFloat] = [:], bottoms: [String: CGFloat] = [:], frames: [String: CGRect] = [:], seen: Set<String> = []
        var results: [((name: String, variant: String), Sample)] = []
        var navigation: CGFloat = 0
        func pending(_ root: XCUIElementSnapshot) -> Target? {
            targets.first { $0.unsettled != nil && $0.find(in: root)?.label == $0.unsettled }
        }
        for _ in 0..<60 {
            guard var root = try? app.snapshot() else { continue }
            for _ in 0..<60 where pending(root) != nil {
                Thread.sleep(forTimeInterval: 0.5)
                if let next = try? app.snapshot() { root = next }
            }
            if let target = pending(root) { XCTFail("\(target.name) \(category) still reads \(target.unsettled!)") }
            let window = root.frame
            navigation = Target(name: "", type: .navigationBar, identifier: bar).find(in: root)?.frame.maxY ?? window.minY
            // At the top the bar's edge and the first row meet at the same point, give or take rounding.
            let (top, bottom) = (navigation - 1, window.maxY - 34)
            // An edge is checked with at least this much of its element, more than the space between a frame's edge
            // and its text at the largest size (about 25 pt above a section header).
            let context = min(50, (bottom - top) / 3)
            var due: [(Target, CGRect, floor: CGFloat, edges: (top: Bool, bottom: Bool))] = []
            for target in targets where results.allSatisfy({ $0.0.name != target.name }) {
                guard let frame = target.textFrame(in: root), !frame.isEmpty else { continue }
                seen.insert(target.name)
                if let minimum = target.minimumHeight, let element = target.find(in: root) {
                    XCTAssertGreaterThanOrEqual(element.frame.height, minimum, "\(target.name) \(tag) frame is at least \(Int(minimum)) points tall")
                }
                let needed = min(frame.height, context)
                // The edge the text must stay clear of at the bottom: its frame, or the line below it once that is listed.
                let floor: CGFloat? = if let label = target.clearance {
                    Target(name: "", type: .staticText, label: label).find(in: root)?.frame.minY
                } else {
                    frame.maxY
                }
                let checkTop = tops[target.name] == nil && frame.minY >= top && min(frame.maxY, bottom) - frame.minY >= needed
                let checkBottom = bottoms[target.name] == nil && floor.map { $0 <= bottom && $0 - max(frame.minY, top) >= needed } ?? false
                if checkTop || checkBottom { due.append((target, frame, floor ?? frame.maxY, (checkTop, checkBottom))) }
            }
            if !due.isEmpty {
                let shot = XCUIScreen.main.uprightScreenshot()
                for (target, frame, floor, edges) in due {
                    XCTAssertGreaterThanOrEqual(frame.minX, window.minX, "\(target.name) \(tag) starts on screen")
                    XCTAssertLessThanOrEqual(frame.maxX, window.maxX, "\(target.name) \(tag) ends on screen")
                    if let previous = frames[target.name] {
                        XCTAssertEqual(previous.height, frame.height, accuracy: 0.5, "\(target.name) \(tag) keeps its height while scrolled")
                    }
                    frames[target.name] = frame
                    let visible = CGRect(x: frame.minX, y: max(frame.minY, top), width: frame.width,
                                         height: min(frame.maxY, bottom) - max(frame.minY, top))
                    let ink = inkExtent(shot, visible, in: window, tinted: target.tinted)
                    XCTAssertLessThanOrEqual(ink.top, ink.bottom, "\(target.name) \(tag) text is found in its frame")
                    if edges.top {
                        let inset = CGFloat(ink.origin + ink.top) - frame.minY * shot.scale
                        XCTAssertGreaterThanOrEqual(inset, 0.5, "\(target.name) \(tag) text is not clipped at the top")
                        tops[target.name] = inset
                    }
                    if edges.bottom {
                        let above = target.clearance == nil ? ink : inkExtent(
                            shot, CGRect(x: frame.minX, y: visible.minY, width: frame.width, height: floor - visible.minY),
                            in: window, tinted: target.tinted)
                        let end = CGFloat(above.origin + above.bottom + 1)
                        XCTAssertGreaterThanOrEqual(floor * shot.scale - end, 0.5, "\(target.name) \(tag) text is not clipped at the bottom")
                        // How far the text ends above the frame's bottom; negative where a descender reaches past it.
                        bottoms[target.name] = frame.maxY * shot.scale - end
                    }
                    if let inset = tops[target.name], let outset = bottoms[target.name] {
                        let height = Int((frame.height * shot.scale - inset - outset).rounded())
                        results.append(((target.name, tag), Sample(frame: frame, ink: height, navigation: navigation)))
                    }
                }
                attach(shot, "\(tag) \(due.map(\.0.name).joined(separator: ", "))")
            }
            // Optional text appears above the last required element when it is shown at all.
            if targets.allSatisfy({ target in
                results.contains { $0.0.name == target.name } || (target.optional && !seen.contains(target.name))
            }) { break }
            let step = min(380, bottom - top - context)
            drag(app, by: upward ? step : -step, landscape: window.width > window.height)
        }
        for target in targets where !results.contains(where: { $0.0.name == target.name }) {
            if target.optional && !seen.contains(target.name) { continue }
            XCTFail("\(target.name) \(category) was never checked at both edges below the navigation bar")
        }
        return results
    }

    /// A slow drag that ends held, so the list does not coast; negative distances scroll toward the end, from 70 percent
    /// of the height, and positive ones toward the start, from 25 percent. It runs
    /// in the left margin, outside the rows' controls and away from the scroll indicator: on the right edge a drag
    /// that starts while the indicator still shows from the previous one grabs it and scrubs the list back toward
    /// its start (Evidence/NativeApp/scroll-indicator-drag-053.md). In landscape the margin includes the safe area
    /// beside the Dynamic Island, where a drag 17 pt from the edge did not scroll, so it starts 44 pt in.
    private func drag(_ app: XCUIApplication, by distance: CGFloat, landscape: Bool = false) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: landscape ? 0.05 : 0.02, dy: distance < 0 ? 0.7 : 0.25))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// Rows of an element's area in a screen screenshot that hold text: pixels far from the area's most common
    /// color, and unless the text is tinted, neutral ones only. They count from the first row of the area's crop,
    /// which `CGRect.integral` widens to whole pixels; `origin` is that row in the screenshot.
    private func inkExtent(_ screenshot: UIImage, _ frame: CGRect, in window: CGRect,
                           tinted: Bool) -> (top: Int, bottom: Int, origin: Int) {
        guard let full = screenshot.cgImage else { return (0, 0, 0) }
        let scale = CGFloat(full.width) / window.width
        let crop = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale).integral
        guard let image = full.cropping(to: crop) else { return (0, 0, Int(crop.minY)) }
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (0, 0, Int(crop.minY)) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Colors in 8-level steps per channel, so antialiasing does not split the background. A flat table, since a
        // landscape paragraph's area holds about two million pixels.
        var counts = [Int](repeating: 0, count: 32 * 32 * 32)
        for i in stride(from: 0, to: data.count, by: 4) {
            counts[(Int(data[i]) / 8) * 1024 + (Int(data[i + 1]) / 8) * 32 + Int(data[i + 2]) / 8] += 1
        }
        let mode = counts.indices.max { counts[$0] < counts[$1] }!
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
        return (top, bottom, Int(crop.minY))
    }

    private func attach(_ screenshot: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
