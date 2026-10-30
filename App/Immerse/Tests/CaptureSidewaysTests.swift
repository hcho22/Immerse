import AVFoundation
import EntitlementCore
import FilmDomain
import NativeAdapters
import SwiftUI
import UIKit
import XCTest
@testable import Immerse

/// The shooting screen keeps the portrait layout whichever way the iPhone is held (the captain, 2026-10-16: "Like iPhone
/// Camera"), and only its words and icons turn. The simulator has no camera and a hosted test cannot turn the iPhone, so
/// these tests set how it is held and what a lens would report, and read the layout the screen's own `Layout` makes.
@MainActor
final class CaptureSidewaysTests: XCTestCase {
    private func size<Content: View>(_ view: Content, turn: HeldTurn, width: CGFloat = 358) -> CGSize {
        UIHostingController(rootView: view.environment(\.heldTurn, turn))
            .sizeThatFits(in: CGSize(width: width, height: 2000))
    }

    func testHeldTurnsFollowHowTheIPhoneIsHeld() {
        XCTAssertEqual(HeldTurn(.portrait), .upright)
        XCTAssertEqual(HeldTurn(.portraitUpsideDown), .upright, "Upside-down portrait reads as upright")
        XCTAssertEqual(HeldTurn(.landscapeLeft), .clockwise, "Home side right: the screen's right edge is the top")
        XCTAssertEqual(HeldTurn(.landscapeRight), .counterClockwise, "Home side left: the screen's left edge is the top")
        XCTAssertEqual(HeldTurn.clockwise.angle, .degrees(90))
        XCTAssertEqual(HeldTurn.counterClockwise.angle, .degrees(-90))
        XCTAssertEqual(HeldTurn.upright.angle, .zero)
        XCTAssertEqual(HeldTurn.clockwise.topEdge, .trailing)
        XCTAssertEqual(HeldTurn.counterClockwise.topEdge, .leading)
        XCTAssertEqual(HeldTurn.clockwise.bottomEdge, .leading)
        XCTAssertEqual(HeldTurn.counterClockwise.bottomEdge, .trailing)
    }

    /// Closing the shooting screen turns the window to how the iPhone is held. The device's landscape orientations are named
    /// for the side the home button is on and the interface's for the side the top is on, so they are mirrored.
    func testTheWindowTurnsToHowTheIPhoneIsHeldWhenTheShootingScreenCloses() {
        XCTAssertEqual(InterfaceOrientationLock.mask(held: .portrait), .portrait)
        XCTAssertEqual(InterfaceOrientationLock.mask(held: .landscapeLeft), .landscapeRight)
        XCTAssertEqual(InterfaceOrientationLock.mask(held: .landscapeRight), .landscapeLeft)
        XCTAssertEqual(InterfaceOrientationLock.mask(held: .portraitUpsideDown), .allButUpsideDown,
                       "The app has no upside-down portrait, so that hold leaves the window as it is")
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .allButUpsideDown,
                       "Every screen turns unless the shooting screen holds the window")
    }

    /// FR-25: a tap shows the focus mark only once the lens has focused there; a lens that cannot focus on a point shows
    /// none (C3).
    func testATapShowsTheFocusMarkOnlyWhereTheLensFocused() async throws {
        for focused in [true, false] {
            let surface = PreviewSurface(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
            surface.preview = AVCaptureVideoPreviewLayer()
            surface.onFocusPoint = { _ in focused }
            await surface.focus(at: CGPoint(x: 120, y: 80))?.value
            XCTAssertEqual(surface.focusMark.superview === surface && surface.focusMark.alpha > 0, focused,
                           focused ? "A focused tap shows the mark" : "An unfocused tap shows none")
            if focused { XCTAssertEqual(surface.focusMark.center, CGPoint(x: 120, y: 80), "The mark is where it was tapped") }
        }
    }

    /// The focus switch takes the same room in every hold, its words turning inside it (C2), so the control strip it sits
    /// in never moves as the iPhone turns.
    func testTheFocusSwitchTakesTheSameRoomInEveryHold() {
        for settings in [[FilmFocusSetting.auto, .manual], [.auto, .fixed]] {
            func size(_ turn: HeldTurn) -> CGSize {
                UIHostingController(rootView: FocusModeSwitch(settings: settings, selected: .auto) { _ in }
                    .environment(\.heldTurn, turn))
                    .sizeThatFits(in: CGSize(width: 351, height: 400))
            }
            XCTAssertGreaterThanOrEqual(size(.upright).height, 44, "\(settings)")
            XCTAssertEqual(size(.clockwise), size(.upright), "\(settings)")
            XCTAssertEqual(size(.counterClockwise), size(.upright), "\(settings)")
        }
    }

    /// A word that turns in place is as wide as it reads upright and as tall as it is long, in every hold.
    func testAWordTurnedInPlaceTakesTheSameRoomInEveryHold() {
        let word = TurnedInPlace { Color.clear.frame(width: 40, height: 16) }
        for turn in [HeldTurn.upright, .clockwise, .counterClockwise] {
            XCTAssertEqual(size(word, turn: turn), CGSize(width: 40, height: 40), "\(turn)")
        }
        XCTAssertEqual(size(TurnedInPlace { Color.clear.frame(width: 20, height: 30) }, turn: .clockwise),
                       CGSize(width: 20, height: 30), "Taller than long, it keeps its height")
    }

    func testDarkroomLockRestoresTheInterfaceOrientationItCovered() {
        XCTAssertEqual(InterfaceOrientationLock.mask(interfaceOrientation: .portrait), .portrait)
        XCTAssertEqual(InterfaceOrientationLock.mask(interfaceOrientation: .landscapeLeft), .landscapeLeft)
        XCTAssertEqual(InterfaceOrientationLock.mask(interfaceOrientation: .landscapeRight), .landscapeRight)
        XCTAssertEqual(InterfaceOrientationLock.mask(interfaceOrientation: .portraitUpsideDown), .allButUpsideDown)
        XCTAssertEqual(InterfaceOrientationLock.mask(interfaceOrientation: .unknown), .allButUpsideDown)
        XCTAssertEqual(InterfaceOrientationLock.mask(deviceOrientation: .portrait, fallback: .landscapeRight), .portrait)
        XCTAssertEqual(InterfaceOrientationLock.mask(deviceOrientation: .landscapeLeft, fallback: .portrait), .landscapeRight)
        XCTAssertEqual(InterfaceOrientationLock.mask(deviceOrientation: .landscapeRight, fallback: .portrait), .landscapeLeft)
        XCTAssertEqual(InterfaceOrientationLock.mask(deviceOrientation: .faceUp, fallback: .landscapeLeft), .landscapeLeft)
    }

    /// The shooting session holds the window for as long as the screen is up, the full-screen print and question that
    /// follow an Instant exposure included, which the screen disappears beneath without ending its session, so the
    /// camera is never seen in a turned window as they come and go; the hold ends with the screen.
    func testTheHoldLastsWhileAPrintIsOverTheScreenAndEndsWithIt() async throws {
        let showing = PrintShowing()
        let capture = CaptureController(authorizer: SyntheticCamera(granted: true))
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: SessionProbe(capture: capture, showing: showing))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "The shooting screen holds the window")
        XCTAssertTrue(capture.shootingSessionActive)
        showing.print = true
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "A print over the camera keeps the hold")
        XCTAssertTrue(capture.shootingSessionActive, "The print's cover does not end the session")
        showing.print = false
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "So does the print closing")
        XCTAssertTrue(capture.shootingSessionActive)
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .allButUpsideDown, "The hold ends with the screen")
        XCTAssertFalse(capture.shootingSessionActive)
    }

    /// While a clip records, the words and icons keep turning with the iPhone, and the clip keeps the orientation it
    /// started in.
    func testWhileAClipRecordsTheWordsFollowTheHoldAndTheClipKeepsItsOrientation() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let capture = model.capture
        capture.hold(forTesting: .portrait)
        capture.setForTesting(phase: .recordingMovie)
        capture.hold(forTesting: .landscapeLeft)
        XCTAssertEqual(HeldTurn(capture.held), .clockwise, "The words turn to read upright")
        XCTAssertEqual(capture.orientation, .portrait, "The clip keeps the orientation it started in")
        capture.setForTesting(phase: .idle)
        capture.updateOrientation()
        XCTAssertEqual(capture.orientation, .landscapeLeft, "The next capture is taken as the iPhone is held")
        capture.hold(forTesting: .portrait)
    }

    /// A Focus or Exposure row is there whenever the Camera offers the control, and it is as tall with the lens's note in
    /// the slider's place as with the slider, and kept empty while no lens is running, in every hold, so the viewfinder
    /// never moves when a lens cannot do the control or the camera starts or stops.
    func testARowIsAsTallWithTheLensNoteAsWithItsSliderAndWithNoLens() {
        func row(slider: Bool, live: Bool = true) -> CaptionedSlider<Slider<EmptyView, EmptyView>> {
            CaptionedSlider(caption: Text("Focus").font(.caption),
                            unavailable: "Manual focus unavailable on this lens", lensIsLive: live,
                            slider: slider ? Slider(value: .constant(0.5)) : nil)
        }
        let upright = size(row(slider: true), turn: .upright)
        for turn in [HeldTurn.upright, .clockwise, .counterClockwise] {
            XCTAssertEqual(size(row(slider: false), turn: turn).height, size(row(slider: true), turn: turn).height, "\(turn)")
            XCTAssertEqual(size(row(slider: false, live: false), turn: turn).height, upright.height, "No lens, \(turn)")
            XCTAssertEqual(size(row(slider: true), turn: turn).height, upright.height, "\(turn)")
        }
    }

    /// A notice's words stay whole: offered lines shorter than its longest word, its text asks for that word's length, so
    /// the notices read at a smaller text size rather than hyphenate it. Where every word fits it is the text as it was.
    func testANoticeTextAsksForItsLongestWordRatherThanBreakingIt() {
        let font = Font.system(size: 51)
        let longestWord = size(Text("unavailable.").font(font).fixedSize(), turn: .upright).width
        XCTAssertLessThan(size(Text("Camera unavailable.").font(font), turn: .upright, width: 150).width, longestWord,
                          "A plain text breaks a word longer than its lines")
        XCTAssertGreaterThanOrEqual(size(WholeWords("Camera unavailable.").font(font), turn: .upright, width: 150).width,
                                    longestWord, "The notice's text asks for its longest word's length")
        XCTAssertEqual(size(WholeWords("Camera unavailable.").font(font), turn: .upright, width: 358),
                       size(Text("Camera unavailable.").font(font), turn: .upright, width: 358),
                       "Where every word fits, the notice's text is the text as it was")
    }

    /// The slider is the same view as the iPhone turns, so a drag in progress is not cut off and its end still reaches
    /// the lens.
    func testASliderStaysTheSameViewAsTheIPhoneTurns() async throws {
        let probe = SliderProbe()
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: SliderProbeView(probe: probe))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(probe.appearances, 1)
        for turn in [HeldTurn.clockwise, .counterClockwise, .upright] {
            probe.turn = turn
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertEqual(probe.appearances, 1, "The slider stays in place turned \(turn)")
        }
    }

    /// A turned block takes the room its turned size needs: as wide as it is tall, and `length` high. Its parent puts it
    /// where it belongs.
    func testATurnedBlockTakesTheRoomItNeedsOnceTurned() {
        let block = TurnedBlock(length: 100) { Color.clear.frame(maxWidth: .infinity).frame(height: 40) }
        XCTAssertEqual(size(block, turn: .upright, width: 300), CGSize(width: 300, height: 40))
        let sideways = size(block, turn: .clockwise, width: 300)
        XCTAssertEqual(sideways.height, 100, "As long as the block's width before it turned")
        XCTAssertEqual(sideways.width, 40, "A block is as wide as it was tall")
        XCTAssertEqual(size(block, turn: .counterClockwise, width: 300), sideways)
    }

    func testANaturalBlockKeepsItsSizeAndTurnsItsFootprint() {
        let row = TurnedBlock { Color.clear.frame(width: 132, height: 44) }
        XCTAssertEqual(size(row, turn: .upright), CGSize(width: 132, height: 44))
        let sideways = size(row, turn: .clockwise, width: 400)
        XCTAssertEqual(sideways.height, 132, "A row of buttons becomes a column as long as it was wide")
    }

    // MARK: The column

    /// Where `CaptureColumn` puts the header, the fixed 4:3 viewfinder area and, given a `stripHeight`, a control strip in
    /// a window, with `room` above the shutter bar.
    private func column(
        aspect: CGFloat, turn: HeldTurn = .upright, width: CGFloat = 358, proposalHeight: CGFloat = 3000,
        extraHeaderText: String? = nil, stripHeight: CGFloat? = nil, room: CGFloat? = nil
    ) async throws -> (header: CGRect, viewfinder: CGRect, strip: CGRect, size: CGSize) {
        let frames = Frames()
        let inColumn: @Sendable (GeometryProxy) -> CGRect = { $0.frame(in: .named("column")) }
        let view = CaptureColumn(room: room) {
            VStack(spacing: 12) {
                Color.clear.frame(height: 44)
                if let extraHeaderText { Text(extraHeaderText) }
            }
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGRect.self, of: inColumn) { frames.header = $0 }
            .captureColumnRole(.header)
            Color.black
                .onGeometryChange(for: CGRect.self, of: inColumn) { frames.viewfinder = $0 }
                .captureColumnRole(.viewfinder(aspect: aspect))
            if let stripHeight {
                Color.gray.frame(height: stripHeight)
                    .onGeometryChange(for: CGRect.self, of: inColumn) { frames.strip = $0 }
                    .captureColumnRole(.strip)
            }
        }
        .environment(\.heldTurn, turn)
        .coordinateSpace(name: "column")
        .frame(width: width)
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        return (frames.header, frames.viewfinder, frames.strip,
                host.sizeThatFits(in: CGSize(width: width, height: proposalHeight)))
    }

    private final class Frames { var header = CGRect.zero, viewfinder = CGRect.zero, strip = CGRect.zero }

    /// Every Camera gets the same full-width 4:3 area, regardless of its picture shape, the available height or the hold.
    func testEveryCameraUsesTheSameFullWidthFourByThreeAreaInEveryHold() async throws {
        for aspect in [CGFloat(1), CGFloat(2.0 / 3), CGFloat(3.0 / 4)] {
            for width in [CGFloat(375), CGFloat(402), CGFloat(440)] {
                let upright = try await column(aspect: aspect, width: width)
                XCTAssertEqual(upright.viewfinder.minX, 0, accuracy: 0.5)
                XCTAssertEqual(upright.viewfinder.width, width, accuracy: 0.5)
                XCTAssertEqual(upright.viewfinder.height, width / CaptureAreaGeometry.aspectRatio, accuracy: 0.5)
                XCTAssertEqual(upright.viewfinder.minY, upright.header.height, accuracy: 0.5)
                for turn in [HeldTurn.clockwise, .counterClockwise] {
                    let turned = try await column(aspect: aspect, turn: turn, width: width)
                    XCTAssertEqual(turned.viewfinder, upright.viewfinder, "aspect \(aspect), width \(width), \(turn)")
                    XCTAssertEqual(turned.header.height, upright.header.height, "aspect \(aspect), width \(width), \(turn)")
                }
            }
        }
    }

    /// Camera-specific picture bounds are centered: square frames fill the area's width, 4:3 fills the area and 3:2
    /// portrait pictures fill its height with equal bars at the sides.
    func testEachCameraPictureShapeIsCenteredInsideTheArea() {
        let area = CGSize(width: 375, height: 500)
        let square = CaptureAreaGeometry.cameraFrame(aspectRatio: 1, in: area)
        XCTAssertEqual(square, CGRect(x: 0, y: 62.5, width: 375, height: 375))
        let disposable = CaptureAreaGeometry.cameraFrame(aspectRatio: 2.0 / 3, in: area)
        XCTAssertEqual(disposable.width, 1000.0 / 3, accuracy: 0.01)
        XCTAssertEqual(disposable.height, 500, accuracy: 0.01)
        XCTAssertEqual(disposable.minX, (375 - 1000.0 / 3) / 2, accuracy: 0.01)
        XCTAssertEqual(disposable.minY, 0, accuracy: 0.01)
        let fourByThree = CaptureAreaGeometry.cameraFrame(aspectRatio: 3.0 / 4, in: area)
        XCTAssertEqual(fourByThree, CGRect(origin: .zero, size: area))
    }

    /// The full area keeps its width and height even when the room is short; the scroll view, not the area, gives up room.
    func testShortRoomDoesNotResizeTheViewfinderArea() async throws {
        let cramped = try await column(aspect: 2.0 / 3, proposalHeight: 300)
        let spacious = try await column(aspect: 1, proposalHeight: 760)
        XCTAssertEqual(cramped.viewfinder.width, 358, accuracy: 0.5)
        XCTAssertEqual(cramped.viewfinder.height, 358 / CaptureAreaGeometry.aspectRatio, accuracy: 0.5)
        XCTAssertEqual(cramped.viewfinder, spacious.viewfinder)
        XCTAssertGreaterThan(cramped.size.height, 300)
    }

    /// A tall header can make the column scroll, but the fixed viewfinder stays directly below it and keeps its area in both
    /// holds.
    func testATallHeaderDoesNotResizeTheViewfinderArea() async throws {
        let extraHeaderText = String(repeating: "Camera name. ", count: 40)
        let upright = try await column(aspect: 1, extraHeaderText: extraHeaderText)
        XCTAssertGreaterThan(upright.header.height, 300, "The long heading makes the column much taller")
        XCTAssertEqual(upright.viewfinder.minY, upright.header.maxY, accuracy: 0.5)
        XCTAssertGreaterThan(upright.size.height, upright.header.height + 300, "The full area stays in the scrollable column")
        for turn in [HeldTurn.clockwise, .counterClockwise] {
            let turned = try await column(aspect: 1, turn: turn, extraHeaderText: extraHeaderText)
            XCTAssertEqual(turned.header.height, upright.header.height, "\(turn)")
            XCTAssertEqual(turned.viewfinder, upright.viewfinder, "\(turn)")
        }
    }

    /// A block that scrolls across the screen once turned starts from its top in either hold, also turned straight from
    /// one side to the other, where its top is at the other end.
    func testABlockThatScrollsStartsFromItsTopTurnedFromSideToSide() async throws {
        let probe = ScrollProbe()
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: ScrollProbeView(probe: probe))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        for turn in [HeldTurn.clockwise, .counterClockwise, .clockwise] {
            probe.turn = turn
            try await Task.sleep(for: .milliseconds(500))
            XCTAssertTrue(probe.block.contains(CGPoint(x: probe.firstLine.midX, y: probe.firstLine.midY)),
                          "The first line \(probe.firstLine) shows in the block \(probe.block) turned \(turn)")
            XCTAssertEqual(probe.firstLine.midX > probe.block.midX, turn == .clockwise,
                           "The first line is at the edge that is the top turned \(turn)")
        }
    }

    // MARK: The control strip

    /// Where the strip's top goes: centred in the room between the area and the shutter bar where that holds the strip,
    /// as low as the room allows where it holds at least half of it, otherwise over the area with its bottom on the area's.
    func testWhereTheStripGoes() {
        XCTAssertEqual(CaptureColumn.stripTop(viewfinderBottom: 580, stripHeight: 44, room: 674), 605, "Centred in 94 points")
        XCTAssertEqual(CaptureColumn.stripTop(viewfinderBottom: 580, stripHeight: 94, room: 674), 580, "Exactly the room")
        XCTAssertEqual(CaptureColumn.stripTop(viewfinderBottom: 580, stripHeight: 120, room: 674), 554,
                       "Room for most of it: down to the shutter bar, 26 points over the area")
        XCTAssertEqual(CaptureColumn.stripTop(viewfinderBottom: 580, stripHeight: 200, room: 674), 380,
                       "Room for less than half: wholly over the area's bottom edge")
        XCTAssertEqual(CaptureColumn.stripTop(viewfinderBottom: 544, stripHeight: 92, room: 543), 452,
                       "No room under the area: wholly over its bottom edge")
        XCTAssertEqual(CaptureColumn.stripTop(viewfinderBottom: 580, stripHeight: 44, room: nil), 580)
    }

    /// The strip is centred in the room between the area and the shutter bar where that holds it, as on the largest
    /// iPhone; where the room holds most of it, it sits down to the shutter bar, partly over the area; and where it holds
    /// less than half, as on the iPhone SE (3rd generation), it sits over the area's bottom edge, its bottom on the
    /// area's. The area keeps its size and place in each.
    func testTheStripSitsUnderTheAreaWhereItFitsAndOverItsBottomEdgeWhereNot() async throws {
        // Rooms like those the iPhone 17 Pro Max, the largest supported, and the iPhone 17 Pro leave above the shutter
        // bar, a shorter one, and the iPhone SE's.
        let cases: [(name: String, width: CGFloat, room: CGFloat, strip: CGFloat)] = [
            ("17 Pro Max, one line", 440, 756, 44), ("17 Pro Max, two lines", 440, 756, 92),
            ("17 Pro, two lines", 402, 682, 100), ("most of it", 402, 640, 92), ("less than half", 402, 610, 92),
            ("iPhone SE, one line", 375, 543, 44), ("iPhone SE, two lines", 375, 543, 92),
        ]
        for c in cases {
            let without = try await column(aspect: 1, width: c.width, room: c.room)
            let with = try await column(aspect: 1, width: c.width, stripHeight: c.strip, room: c.room)
            XCTAssertEqual(with.viewfinder.minY, without.viewfinder.minY, accuracy: 0.5, "The area stays, \(c.name)")
            XCTAssertEqual(with.viewfinder.height, without.viewfinder.height, accuracy: 0.5, "The area keeps its size, \(c.name)")
            XCTAssertEqual(with.strip.height, c.strip, accuracy: 0.5, c.name)
            let under = c.room - with.viewfinder.maxY
            if under >= c.strip {
                XCTAssertGreaterThanOrEqual(with.strip.minY, with.viewfinder.maxY - 0.5, "Under the area, \(c.name)")
                XCTAssertEqual(with.strip.minY - with.viewfinder.maxY, c.room - with.strip.maxY, accuracy: 0.5,
                               "Centred in the room under the area, \(c.name)")
            } else {
                XCTAssertEqual(with.strip.maxY, under >= c.strip / 2 ? c.room : with.viewfinder.maxY, accuracy: 0.5,
                               "Down to the shutter bar or over the area's bottom edge, \(c.name)")
            }
        }
        let se = try await column(aspect: 1, width: 375, stripHeight: 44, room: 543)
        XCTAssertEqual(se.strip.maxY, se.viewfinder.maxY, accuracy: 0.5, "On the iPhone SE the strip is wholly over the area")
    }

    /// The steps and the settings share one line where they fit across the strip and take a line each where they do not,
    /// steps above, each line centred; the 6×6 keeps both lines whatever fits.
    func testTheStripSharesOneLineWhereItsControlsFit() async throws {
        let one = try await strip(width: 378, steps: 184, settings: [119])
        XCTAssertEqual(one.size.height, 44)
        XCTAssertEqual(one.steps.midY, one.settings[0].midY, "One line")
        XCTAssertEqual(one.steps.minX, 378 - one.settings[0].maxX, accuracy: 0.5, "Centred across the strip")
        let two = try await strip(width: 343, steps: 228, settings: [130])
        XCTAssertEqual(two.size.height, 90, "Two 44-point lines 2 points apart")
        XCTAssertEqual(two.steps.maxY + 2, two.settings[0].minY, accuracy: 0.5, "The steps above the settings")
        XCTAssertEqual(two.steps.midX, 343 / 2, accuracy: 0.5)
        XCTAssertEqual(two.settings[0].midX, 343 / 2, accuracy: 0.5)
        let kept = try await strip(width: 378, steps: 44, settings: [130, 44, 44], keepsStepsLine: true)
        XCTAssertEqual(kept.size.height, 90, "The 6×6 keeps both lines")
        XCTAssertEqual(kept.settings[1].minX - kept.settings[0].maxX, 8, accuracy: 0.5)
    }

    /// Where `ControlStripLayout` puts a steps pill `steps` wide and settings of the given widths, each 44 points tall.
    private func strip(width: CGFloat, steps: CGFloat, settings: [CGFloat], keepsStepsLine: Bool = false)
        async throws -> (steps: CGRect, settings: [CGRect], size: CGSize) {
        let frames = StripFrames()
        frames.settings = settings.map { _ in .zero }
        let inStrip: @Sendable (GeometryProxy) -> CGRect = { $0.frame(in: .named("strip")) }
        let view = ControlStripLayout(keepsStepsLine: keepsStepsLine) {
            Color.clear.frame(width: steps, height: 44)
                .onGeometryChange(for: CGRect.self, of: inStrip) { frames.steps = $0 }
                .controlStripLine(.steps)
            ForEach(Array(settings.enumerated()), id: \.offset) { index, width in
                Color.clear.frame(width: width, height: 44)
                    .onGeometryChange(for: CGRect.self, of: inStrip) { frames.settings[index] = $0 }
                    .controlStripLine(.settings)
            }
        }
        .coordinateSpace(name: "strip")
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { frames.size = $0 }
        .frame(width: width)
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        return (frames.steps, frames.settings, frames.size)
    }

    private final class StripFrames { var steps = CGRect.zero, settings: [CGRect] = [], size = CGSize.zero }

    // MARK: The shooting screen

    /// On every Camera with controls the strip is under the Viewfinder area on this simulator's iPhone, centred in the room
    /// above the shutter bar, with the area where it is, and both are the same in every hold. On an iPhone at least 390
    /// points wide, as every one but the iPhone SE and the mini is, the room holds every strip, the 6×6's two lines
    /// included. The Instant has no strip, and the 16mm has one only where the iPhone offers Zoom Steps.
    func testEveryCameraPutsItsStripUnderTheViewfinderAreaInEveryHold() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        for camera in Self.cameras {
            let film = try makeFilm(camera, model)
            for steps in [true, false] {
                var upright: (viewfinder: CGRect, strip: CGRect?)?
                for held in [CaptureFrameOrientation.portrait, .landscapeLeft, .landscapeRight] {
                    let probe = try await showScreen(model, film: film, zoomSteps: steps, held: held).probe
                    let name = "\(camera.id.rawValue), \(steps ? "with" : "without") Zoom Steps, \(held)"
                    let hasStrip = camera.id != CameraCatalog.instant1970s.id
                        && (steps || camera.id != CameraCatalog.cinema16mm.id)
                    XCTAssertEqual(probe.strip != nil, hasStrip, "Whether the strip shows, \(name)")
                    XCTAssertEqual(probe.viewfinder.width, probe.room.width, accuracy: 0.5, name)
                    XCTAssertEqual(probe.viewfinder.height, probe.room.width * 4 / 3, accuracy: 0.5, name)
                    XCTAssertEqual(probe.shutter.midX, probe.room.midX, accuracy: 0.5, "The shutter is centred, \(name)")
                    if let strip = probe.strip {
                        let under = probe.room.maxY - probe.viewfinder.maxY
                        if probe.room.width >= 390 {
                            // With a gap above and below it.
                            XCTAssertGreaterThanOrEqual(under, strip.height + 8, "The room holds the strip, \(name)")
                        }
                        if under >= strip.height {
                            XCTAssertGreaterThanOrEqual(strip.minY, probe.viewfinder.maxY - 0.5, "Under the area, \(name)")
                            XCTAssertEqual(strip.minY - probe.viewfinder.maxY, probe.room.maxY - strip.maxY, accuracy: 0.5,
                                           "Centred between the area and the shutter bar, \(name)")
                        }
                        XCTAssertEqual(strip.width, probe.room.width, accuracy: 0.5, "Across the screen, \(name)")
                    }
                    if let upright {
                        XCTAssertEqual(probe.viewfinder, upright.viewfinder, "The area keeps its place, \(name)")
                        XCTAssertEqual(probe.strip, upright.strip, "The strip keeps its place, \(name)")
                    } else {
                        upright = (probe.viewfinder, probe.strip)
                    }
                }
            }
        }
    }

    /// On the iPhone SE (3rd generation), whose 667-point screen leaves no room under the Viewfinder area, the strip sits
    /// over the area's bottom edge, as the iPhone Camera app's controls do there, and the area keeps its size and place.
    /// The iPhone SE has one rear lens, so no Zoom Steps.
    func testOnTheIPhoneSETheStripSitsOverTheAreasBottomEdge() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        // The iPhone SE's screen less its 20-point status bar, with no home indicator.
        let iPhoneSE = CGSize(width: 375, height: 647)
        for camera in [CameraCatalog.disposable1990s, CameraCatalog.mediumFormat6x6, CameraCatalog.super8HomeMovie] {
            let film = try makeFilm(camera, model)
            for held in [CaptureFrameOrientation.portrait, .landscapeLeft, .landscapeRight] {
                let probe = try await showScreen(model, film: film, zoomSteps: false, held: held, size: iPhoneSE).probe
                let name = "\(camera.id.rawValue), \(held)"
                XCTAssertEqual(probe.viewfinder.size.width, 375, accuracy: 0.5, name)
                XCTAssertEqual(probe.viewfinder.size.height, 500, accuracy: 0.5, name)
                XCTAssertEqual(probe.shutter.midX, probe.room.midX, accuracy: 0.5, "The shutter is centred, \(name)")
                let strip = try XCTUnwrap(probe.strip, name)
                // The few points under the area hold no strip, so it sits over the area's bottom edge.
                XCTAssertLessThan(probe.room.maxY - probe.viewfinder.maxY, strip.height, name)
                XCTAssertEqual(strip.maxY, probe.viewfinder.maxY, accuracy: 0.5, "Over the area's bottom edge, \(name)")
                XCTAssertGreaterThan(strip.minY, probe.viewfinder.midY, "Low over the area, \(name)")
            }
        }
    }

    /// The 6×6's Focus and Exposure buttons each open their slider in the strip, in the Zoom Steps' place, and the strip
    /// keeps its size and place for it in every hold, so nothing else moves.
    func testTheSixBySixOpensEachSliderInTheStrip() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        var film = try makeFilm(CameraCatalog.mediumFormat6x6, model)
        film = try model.setFocusSetting(.manual, filmID: film.id)
        for held in [CaptureFrameOrientation.portrait, .landscapeLeft, .landscapeRight] {
            let closed = try await showScreen(model, film: film, held: held).probe
            let steps = try XCTUnwrap(closed.zoomSteps, "\(held)")
            XCTAssertNil(closed.slider, "No slider is open at first, \(held)")
            for slider in [StripSlider.focus, .exposure] {
                let open = try await showScreen(model, film: film, held: held, slider: slider).probe
                let name = "\(slider), \(held)"
                let strip = try XCTUnwrap(open.strip, name)
                let panel = try XCTUnwrap(open.slider, name)
                XCTAssertEqual(strip, closed.strip, "The strip keeps its size and place, \(name)")
                XCTAssertEqual(open.viewfinder, closed.viewfinder, name)
                XCTAssertTrue(panel.insetBy(dx: -0.5, dy: -0.5).contains(steps), "The slider takes the steps' place, \(name)")
                XCTAssertTrue(strip.insetBy(dx: -0.5, dy: -0.5).contains(panel), "Inside the strip, \(name)")
            }
        }
    }

    /// Each Camera's shooting screen held upright, on its left side and on its right side, at the default text size and the
    /// largest, kept for the captain's approval with a three-lens rear camera running and nothing over the viewfinder, and
    /// the 6×6 with each of its sliders open. Run on the iPhone SE (3rd generation) and the largest supported iPhone.
    func testTheShootingScreensForApproval() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let width = try await hostWindowScene().screen.bounds.width
        let device = width < 390 ? "SE" : width >= 440 ? "Largest" : "\(Int(width))-point"
        for camera in Self.cameras {
            let film = try makeFilm(camera, model)
            for (size, sizeName) in [(DynamicTypeSize.large, "default"), (.accessibility5, "largest")] {
                for (held, name) in Self.holds {
                    let (probe, screenshot) = try await showScreen(model, film: film, zoomSteps: device != "SE", held: held,
                                                                   textSize: size)
                    keep(screenshot, "Approval-\(device)-\(camera.id.rawValue)-\(sizeName)-\(name)")
                    let shot = "\(camera.id.rawValue), \(sizeName), \(name)"
                    XCTAssertEqual(probe.shutter.midX, probe.room.midX, accuracy: 0.5, "The shutter is centred, \(shot)")
                    // Where the room under the area holds a strip it is there with a gap above it, and on the largest
                    // iPhone it holds every strip, the 6×6's two lines at the largest size included.
                    if let strip = probe.strip {
                        let under = probe.room.maxY - probe.viewfinder.maxY
                        if device == "Largest" {
                            XCTAssertGreaterThanOrEqual(under, strip.height + 8, "The room holds the strip, \(shot)")
                        }
                        if under >= strip.height + 8 {
                            XCTAssertGreaterThanOrEqual(strip.minY, probe.viewfinder.maxY + 4, "A gap under the area, \(shot)")
                        }
                    }
                }
            }
        }
        var film = try makeFilm(CameraCatalog.mediumFormat6x6, model)
        film = try model.setFocusSetting(.manual, filmID: film.id)
        for slider in [StripSlider.focus, .exposure] {
            for (held, name) in Self.holds {
                let screenshot = try await showScreen(model, film: film, zoomSteps: device != "SE", held: held,
                                                      slider: slider).screenshot
                keep(screenshot, "Approval-\(device)-mediumFormat6x6-\(slider)-open-\(name)")
            }
        }
    }

    private static let cameras = [CameraCatalog.disposable1990s, CameraCatalog.instant1970s, CameraCatalog.mediumFormat6x6,
                                  CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm]
    private static let holds: [(CaptureFrameOrientation, String)] = [(.portrait, "portrait"), (.landscapeLeft, "left"),
                                                                     (.landscapeRight, "right")]

    private func keep(_ screenshot: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeFilm(_ camera: CameraPackage, _ model: JournalModel) throws -> Film {
        let film = try model.repository.createFilm(
            camera: camera, title: "Synthetic \(camera.id.rawValue) \(UUID().uuidString.prefix(4))",
            movieOrientation: camera.medium == .movie ? .portrait : nil, filmStock: camera.defaultFilmStock,
            access: .subscription)
        model.refresh()
        return film
    }

    /// Each Camera's shooting screen held upright, on its left side and on its right side, at the default text size and the
    /// largest, kept as screenshots in the tallest case, the message and Resume Camera over the viewfinder, clear of the
    /// strip. The viewfinder is a black box that keeps its size and place, which the live picture fills in every hold. The
    /// Zoom Steps, the 6×6's sliders and the Disposable's cue are raised from what a lens would report, since the
    /// simulator has no lens.
    func testCaptureScreensHeldSidewaysKeepTheLayoutAndTurnTheText() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        for camera in Self.cameras {
            let film = try makeFilm(camera, model)
            for size in [DynamicTypeSize.large, .accessibility5] {
                for (held, name) in Self.holds {
                    let screenshot = try await showScreen(
                        model, film: film, held: held, textSize: size,
                        sceneEV100: camera.id == CameraCatalog.disposable1990s.id ? 4 : nil,
                        message: "Camera paused. Saved captures are unchanged.").screenshot
                    keep(screenshot, "Capture-\(camera.id.rawValue)-\(size == .large ? "default" : "largest")-\(name)")
                }
            }
        }
    }

    /// The 6×6's zoom steps as a person with a camera running sees them: enabled, with the selected step filled. The
    /// simulator's own screens show them dimmed, since its camera is never idle. No notice shows over the viewfinder.
    func testTheZoomStepsInTheirEnabledState() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try makeFilm(CameraCatalog.mediumFormat6x6, model)
        for (selected, held, name) in [(1, CaptureFrameOrientation.portrait, "portrait"), (3, .landscapeLeft, "left")] {
            for (style, styleName) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
                let screenshot = try await showScreen(model, film: film, zoomStep: selected, held: held, style: style).screenshot
                keep(screenshot, "Zoom-enabled-\(name)-\(styleName)")
            }
        }
    }

    /// The focus switch where it sits with a lens running (FR-25): the 6×6 on Auto and on Manual, the Super 8 with its zoom
    /// steps and the Disposable on Fixed, upright and held on its side, in the control strip under the Viewfinder area.
    func testTheFocusSwitchWithALiveLens() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let cases: [(CameraPackage, FilmFocusSetting, String)] = [
            (CameraCatalog.mediumFormat6x6, .auto, "6x6-Auto"),
            (CameraCatalog.mediumFormat6x6, .manual, "6x6-Manual"),
            (CameraCatalog.super8HomeMovie, .auto, "Super8-Auto"),
            (CameraCatalog.disposable1990s, .fixed, "Disposable-Fixed")
        ]
        for (camera, setting, name) in cases {
            var film = try makeFilm(camera, model)
            film = try model.setFocusSetting(setting, filmID: film.id)
            for (held, holdName) in [(CaptureFrameOrientation.portrait, "portrait"), (.landscapeLeft, "left")] {
                keep(try await showScreen(model, film: film, held: held).screenshot, "Focus-\(name)-\(holdName)")
            }
        }
    }

    /// The shooting screen of `film` as it shows with a lens running, by default a three-lens rear camera with its 1x step
    /// selected, held as `held`, with any `slider` open and `message` over the viewfinder, in a window or, given a `size`,
    /// in a box that size in the middle of it, which no safe area reaches. It returns where the screen put its parts and
    /// the window drawn.
    private func showScreen(
        _ model: JournalModel, film: Film, zoomSteps: Bool = true, zoomStep: Int = 1,
        held: CaptureFrameOrientation = .portrait, slider: StripSlider? = nil, size: CGSize? = nil,
        textSize: DynamicTypeSize = .large, style: UIUserInterfaceStyle = .light, sceneEV100: Double? = nil,
        message: String? = nil
    ) async throws -> (probe: CaptureLayoutProbe, screenshot: UIImage) {
        var controls = NativeCameraControls()
        controls.flash = true
        controls.fixedExposure = true
        controls.manualFocus = true
        controls.minimumExposureBias = -2
        controls.maximumExposureBias = 2
        if zoomSteps {
            let steps = RearLensCapabilities(lenses: [.init(.ultraWide, displayFactor: 0.5),
                                                      .init(.wide, displayFactor: 1, nativeCropFactors: [2]),
                                                      .init(.telephoto, displayFactor: 3)]).zoomSteps
            controls.zoomSteps = steps
            controls.zoomStep = steps[zoomStep]
        }
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = style
        model.capture.hold(forTesting: held)
        let probe = CaptureLayoutProbe()
        var screen = CaptureView(filmID: film.id)
        screen.opensCamera = false
        screen.initialSlider = slider
        screen.probe = probe
        let root = screen.environment(model).dynamicTypeSize(textSize)
        window.rootViewController = UIHostingController(
            rootView: size.map { AnyView(root.frame(width: $0.width, height: $0.height)) } ?? AnyView(root))
        window.makeKeyAndVisible()
        // Closing the last screen pauses its camera and clears the reading, so set what a lens would report once the
        // screen has settled.
        try await Task.sleep(for: .seconds(1))
        model.capture.setForTesting(controls: controls, sceneEV100: sceneEV100 ?? FixedExposure.referenceEV100)
        model.capture.setForTesting(phase: .idle)
        model.capture.message = message
        try await Task.sleep(for: .milliseconds(500))
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        // Closing the screen turns the window to how the iPhone is held, which would turn every later test's window too,
        // so the screen is closed with the iPhone upright.
        model.capture.hold(forTesting: .portrait)
        window.isHidden = true
        window.rootViewController = nil
        // SwiftUI reports the screen gone a moment later, and the next screen's hold must not be what it turns to.
        try await Task.sleep(for: .milliseconds(500))
        return (probe, screenshot)
    }

    private func makeModel() async throws -> (URL, JournalModel) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureSideways-\(UUID())")
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true))
        await model.recoverAtLaunch()
        return (root, model)
    }
}

/// Whether an Instant print is over the camera, for the test of the hold.
@Observable private final class PrintShowing { var print = false }

/// Starts and ends the shooting session as `CaptureView` does, once per presentation and not as a full-screen print
/// covers it, with the print as a full-screen cover as the Instant's is.
private struct SessionProbe: View {
    let capture: CaptureController
    @Bindable var showing: PrintShowing
    @State private var started = false

    var body: some View {
        Color.clear
            .onAppear {
                guard !started else { return }
                started = true
                capture.beginShootingSession()
            }
            .onDisappear {
                guard !showing.print else { return }
                capture.endShootingSession()
            }
            .fullScreenCover(isPresented: $showing.print) { Text("Print") }
    }
}

/// How the iPhone is held, and where a header that scrolls once turned and its first line are, for the test of where it
/// starts.
@Observable private final class ScrollProbe {
    var turn = HeldTurn.upright
    var block = CGRect.zero
    var firstLine = CGRect.zero
}

private struct ScrollProbeView: View {
    let probe: ScrollProbe
    var body: some View {
        TurnedBlock(length: 128) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 44).onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { probe.firstLine = $0 }
                Color.clear.frame(height: 900)
            }.frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { probe.block = $0 }
        .environment(\.heldTurn, probe.turn)
        .frame(width: 358)
    }
}

/// How the iPhone is held, and how many times the slider in a row has come on screen, for the test of its identity.
@Observable private final class SliderProbe {
    var turn = HeldTurn.upright
    var appearances = 0
}

private struct SliderProbeView: View {
    let probe: SliderProbe
    var body: some View {
        CaptionedSlider(caption: Text("Focus").font(.caption), unavailable: "Manual focus unavailable",
                        lensIsLive: true, slider: Color.gray.frame(height: 30).onAppear { probe.appearances += 1 })
            .environment(\.heldTurn, probe.turn)
            .padding()
    }
}
