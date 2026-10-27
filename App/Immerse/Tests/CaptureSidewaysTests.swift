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

    /// The focus switch's words turn with the hold, as the screen's other words do (C2): held sideways, "Manual" stands
    /// on end, so the switch is taller than its upright 44 points.
    func testTheFocusSwitchWordsTurnHeldSideways() {
        func height(_ turn: HeldTurn) -> CGFloat {
            UIHostingController(rootView: FocusModeSwitch(settings: [.auto, .manual], selected: .auto) { _ in }
                .environment(\.heldTurn, turn))
                .sizeThatFits(in: CGSize(width: 351, height: 400)).height
        }
        XCTAssertEqual(height(.upright), 44, accuracy: 0.5)
        XCTAssertGreaterThan(height(.clockwise), 50, "Turned, the longer word stands taller than the upright switch")
        XCTAssertEqual(height(.clockwise), height(.counterClockwise), accuracy: 0.5)
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

    /// The shooting screen holds the window for as long as it is up, the print and the question that follow an Instant
    /// exposure included, so the camera is never seen in a turned window beneath them as they come and go; the hold ends
    /// with the screen.
    func testTheHoldLastsWhileAPrintIsOverTheScreenAndEndsWithIt() async throws {
        let showing = PrintShowing()
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: HoldProbe(showing: showing))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "The shooting screen holds the window")
        showing.print = true
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "A print over the camera keeps the hold")
        showing.print = false
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "So does the print closing")
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .allButUpsideDown, "The hold ends with the screen")
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
            CaptionedSlider(captionLength: 64, caption: Text("Focus").font(.caption),
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

    /// The header reserves the same height in every hold, so the viewfinder below it never moves.
    func testAHeaderThatReservesItsLengthIsTheSameHeightInEveryHold() {
        let header = TurnedBlock(length: 128, reservesLength: true) {
            VStack(spacing: 12) {
                Color.clear.frame(height: 44)
                Color.clear.frame(height: 28)
                Color.clear.frame(height: 22)
            }.frame(maxWidth: .infinity)
        }
        // A reserving block offered height is laid out that long, so this one is offered none.
        .fixedSize(horizontal: false, vertical: true)
        let upright = size(header, turn: .upright)
        XCTAssertEqual(size(header, turn: .clockwise).height, upright.height)
        XCTAssertEqual(size(header, turn: .counterClockwise).height, upright.height)
        XCTAssertEqual(upright.height, 128, "The portrait content is 118 high; the turned header is 128 long")
        XCTAssertEqual(size(header, turn: .clockwise).width, 358, "The header spans the screen's width in every hold")
    }

    /// A block that does not reserve its length takes the room its turned size needs: as wide as it is tall, and `length`
    /// high. Its parent puts it where it belongs.
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

    /// Where `CaptureColumn` puts the header and the fixed 4:3 viewfinder area in a window.
    private func column(
        aspect: CGFloat, turn: HeldTurn = .upright, width: CGFloat = 358, proposalHeight: CGFloat = 3000,
        extraHeaderText: String? = nil
    ) async throws -> (header: CGRect, firstLine: CGRect, viewfinder: CGRect, size: CGSize) {
        let frames = Frames()
        let inColumn: @Sendable (GeometryProxy) -> CGRect = { $0.frame(in: .named("column")) }
        let view = CaptureColumn {
            TurnedBlock(length: 128, reservesLength: true, maximumLength: 760) {
                VStack(spacing: 12) {
                    Color.clear.frame(height: 44)
                        .onGeometryChange(for: CGRect.self, of: inColumn) { frames.firstLine = $0 }
                    Color.clear.frame(height: 28)
                    Color.clear.frame(height: 22)
                    if let extraHeaderText { Text(extraHeaderText) }
                }.frame(maxWidth: .infinity)
            }
            .onGeometryChange(for: CGRect.self, of: inColumn) { frames.header = $0 }
            .captureColumnRole(.header)
            Color.black
                .onGeometryChange(for: CGRect.self, of: inColumn) { frames.viewfinder = $0 }
                .captureColumnRole(.viewfinder(aspect: aspect))
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
        return (frames.header, frames.firstLine, frames.viewfinder,
                host.sizeThatFits(in: CGSize(width: width, height: proposalHeight)))
    }

    private final class Frames { var header = CGRect.zero, firstLine = CGRect.zero, viewfinder = CGRect.zero }

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

    /// A header that scrolls across the screen once turned starts from its top in either hold, also turned straight from
    /// one side to the other, where its top is at the other end.
    func testAHeaderThatScrollsStartsFromItsTopTurnedFromSideToSide() async throws {
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

    /// Each Camera's shooting screen held upright, on its left side and on its right side, at the default text size and the
    /// largest, kept as screenshots. The viewfinder is a black box that keeps its size and place, which the live picture
    /// fills in every hold. The 6×6's zoom pill, sliders and the Disposable's cue are raised from what a lens would report,
    /// since the simulator has no lens.
    func testCaptureScreensHeldSidewaysKeepTheLayoutAndTurnTheText() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        var controls = NativeCameraControls()
        controls.flash = true
        controls.fixedExposure = true
        controls.manualFocus = true
        controls.minimumExposureBias = -2
        controls.maximumExposureBias = 2
        let steps = RearLensCapabilities(lenses: [.init(.ultraWide, displayFactor: 0.5),
                                                  .init(.wide, displayFactor: 1, nativeCropFactors: [2]),
                                                  .init(.telephoto, displayFactor: 3)]).zoomSteps
        controls.zoomSteps = steps
        controls.zoomStep = steps[1]
        let cases: [(CameraPackage, Bool, [DynamicTypeSize])] = [
            (CameraCatalog.mediumFormat6x6, false, [.large, .accessibility5]),
            (CameraCatalog.disposable1990s, true, [.large]),
            (CameraCatalog.instant1970s, false, [.large]),
            (CameraCatalog.super8HomeMovie, false, [.large]),
        ]
        for (camera, cue, sizes) in cases {
            let film = try model.repository.createFilm(
                camera: camera, title: "Synthetic \(camera.id.rawValue)",
                movieOrientation: camera.medium == .movie ? .portrait : nil, filmStock: camera.defaultFilmStock, access: .subscription)
            model.refresh()
            for size in sizes {
                for (held, name) in [(CaptureFrameOrientation.portrait, "portrait"), (.landscapeLeft, "left"), (.landscapeRight, "right")] {
                    let scene = try await hostWindowScene()
                    let window = UIWindow(windowScene: scene)
                    model.capture.hold(forTesting: held)
                    window.rootViewController = UIHostingController(
                        rootView: CaptureView(filmID: film.id).environment(model).dynamicTypeSize(size))
                    window.makeKeyAndVisible()
                    // Closing the last screen pauses its camera and clears the reading, so set what a lens
                    // would report once the screen has settled.
                    try await Task.sleep(for: .seconds(1))
                    model.capture.setForTesting(controls: controls, sceneEV100: cue ? 4 : FixedExposure.referenceEV100)
                    // The tallest case: the message and Resume Camera over the viewfinder, in every hold.
                    model.capture.message = "Camera paused. Saved captures are unchanged."
                    try await Task.sleep(for: .milliseconds(500))
                    let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    // Closing the screen turns the window to how the iPhone is held, which would turn every later test's
                    // window too, so the screen is closed with the iPhone upright.
                    model.capture.hold(forTesting: .portrait)
                    window.isHidden = true
                    window.rootViewController = nil
                    // SwiftUI reports the screen gone a moment later, and the next screen's hold must not be what it turns to.
                    try await Task.sleep(for: .milliseconds(500))
                    let attachment = XCTAttachment(image: screenshot)
                    attachment.name = "Capture-\(camera.id.rawValue)-\(size == .large ? "default" : "largest")-\(name)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    /// The 6×6's zoom steps as a person with a camera running sees them: enabled, with the selected step filled. The
    /// simulator's own screens show them dimmed, since its camera is never idle. No notice shows over the viewfinder.
    func testTheZoomStepsInTheirEnabledState() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try model.repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Synthetic zoom",
                                                   filmStock: .color, access: .subscription)
        model.refresh()
        for (selected, held, name) in [(1, CaptureFrameOrientation.portrait, "portrait"), (3, .landscapeLeft, "left")] {
            for (style, styleName) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
                let screenshot = try await screenWithALiveLens(model, film: film, zoomStep: selected, held: held, style: style)
                let attachment = XCTAttachment(image: screenshot)
                attachment.name = "Zoom-enabled-\(name)-\(styleName)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    /// The focus switch where it sits with a lens running (FR-25), kept for the captain's approval of its placement: the
    /// 6×6 on Auto and on Manual, with its Focus slider, the Super 8 with its zoom steps and the Disposable on Fixed,
    /// upright and held on its side. The switch and the sliders stay across the Viewfinder area's bottom in every hold.
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
            var film = try model.repository.createFilm(
                camera: camera, title: "Synthetic \(name)", movieOrientation: camera.medium == .movie ? .portrait : nil,
                filmStock: camera.defaultFilmStock, access: .subscription)
            model.refresh()
            film = try model.setFocusSetting(setting, filmID: film.id)
            for (held, holdName) in [(CaptureFrameOrientation.portrait, "portrait"), (.landscapeLeft, "left")] {
                let screenshot = try await screenWithALiveLens(model, film: film, zoomStep: 1, held: held, style: .light)
                let attachment = XCTAttachment(image: screenshot)
                attachment.name = "Focus-\(name)-\(holdName)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    /// The shooting screen of `film` as it shows with a three-lens rear camera running, `zoomStep` selected, held as
    /// `held`, drawn from its window.
    private func screenWithALiveLens(_ model: JournalModel, film: Film, zoomStep: Int, held: CaptureFrameOrientation,
                                     style: UIUserInterfaceStyle) async throws -> UIImage {
        var controls = NativeCameraControls()
        controls.manualFocus = true
        controls.minimumExposureBias = -2
        controls.maximumExposureBias = 2
        let steps = RearLensCapabilities(lenses: [.init(.ultraWide, displayFactor: 0.5),
                                                  .init(.wide, displayFactor: 1, nativeCropFactors: [2]),
                                                  .init(.telephoto, displayFactor: 3)]).zoomSteps
        controls.zoomSteps = steps
        controls.zoomStep = steps[zoomStep]
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = style
        model.capture.hold(forTesting: held)
        var screen = CaptureView(filmID: film.id)
        screen.opensCamera = false
        window.rootViewController = UIHostingController(rootView: screen.environment(model))
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1))
        model.capture.setForTesting(controls: controls)
        model.capture.setForTesting(phase: .idle)
        model.capture.message = nil
        try await Task.sleep(for: .milliseconds(500))
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        model.capture.hold(forTesting: .portrait)
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(500))
        return screenshot
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

/// Holds the window as `CaptureView` does, with a sheet over it as the print is.
private struct HoldProbe: View {
    @Bindable var showing: PrintShowing
    var body: some View {
        Color.clear.holdsInterfaceOrientation(.portrait) { .portrait }
            .sheet(isPresented: $showing.print) { Text("Print") }
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
        TurnedBlock(length: 128, reservesLength: true) {
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
        CaptionedSlider(captionLength: 64, caption: Text("Focus").font(.caption), unavailable: "Manual focus unavailable",
                        lensIsLive: true, slider: Color.gray.frame(height: 30).onAppear { probe.appearances += 1 })
            .environment(\.heldTurn, probe.turn)
            .padding()
    }
}
