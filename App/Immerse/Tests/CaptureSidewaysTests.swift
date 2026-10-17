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

    /// The screen's own rule for the hold. A print's sheet lets go of its print as it starts to close, before its question
    /// comes up, so the rule keys on the prints still to be dropped (`revealedPrints`), which keep the hold off between them.
    func testTheHoldStaysOffFromAPrintToItsQuestionUntilTheLastPrintIsDropped() {
        let ask = OriginalAsk(prints: [1])
        XCTAssertTrue(CaptureView.holdsWindowUpright(revealedPrints: [CaptureRecord](), originalAsk: nil), "No print: held")
        XCTAssertFalse(CaptureView.holdsWindowUpright(revealedPrints: [1], originalAsk: nil),
                       "A print revealed, shown or closing before its question comes up: not held")
        XCTAssertFalse(CaptureView.holdsWindowUpright(revealedPrints: [1], originalAsk: ask), "Its question is up: not held")
        XCTAssertFalse(CaptureView.holdsWindowUpright(revealedPrints: [Int](), originalAsk: ask), "A question alone: not held")
    }

    /// The hold ends while an Instant print or its question shows over the camera, so they turn with the iPhone, stays ended
    /// from a print to its question, comes back when the last of them closes, and ends with the screen. The Instant's camera
    /// starts again by itself when they close (`CaptureController.printsClosed`), and the hold must be back by then.
    func testTheHoldEndsWhileAPrintShowsAndComesBackWhenItCloses() async throws {
        let showing = PrintShowing()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: HoldProbe(showing: showing))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "The shooting screen holds the window")
        showing.revealedPrints = [1]
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .allButUpsideDown, "A print over the camera turns with the iPhone")
        showing.originalAsk = OriginalAsk(prints: [1])
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .allButUpsideDown,
                       "Its question turns with the iPhone too, while the print waits to be dropped")
        showing.originalAsk = nil
        showing.revealedPrints = []
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(ImmerseAppDelegate.supportedOrientations, .portrait, "The hold is back when the last print is dropped")
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
    /// the slider's place as with the slider, in every hold, so the viewfinder never moves when a lens cannot do it.
    func testARowIsAsTallWithTheLensNoteAsWithItsSlider() {
        func row(slider: Bool) -> CaptionedSlider<Slider<EmptyView, EmptyView>> {
            CaptionedSlider(captionLength: 64, caption: Text("Focus").font(.caption),
                            unavailable: "Manual focus unavailable on this lens",
                            slider: slider ? Slider(value: .constant(0.5)) : nil)
        }
        let upright = size(row(slider: true), turn: .upright)
        for turn in [HeldTurn.upright, .clockwise, .counterClockwise] {
            XCTAssertEqual(size(row(slider: false), turn: turn).height, size(row(slider: true), turn: turn).height, "\(turn)")
            XCTAssertEqual(size(row(slider: true), turn: turn).height, upright.height, "\(turn)")
        }
    }

    /// The slider is the same view as the iPhone turns, so a drag in progress is not cut off and its end still reaches
    /// the lens.
    func testASliderStaysTheSameViewAsTheIPhoneTurns() async throws {
        let probe = SliderProbe()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
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

    /// Where `CaptureColumn` puts a header, a viewfinder of `aspect` and, with `controls` high, controls, for a screen with
    /// `available` points of room between its top and the shutter bar, as the screen lays them out in a window.
    private func column(
        available: CGFloat, aspect: CGFloat, controls: CGFloat = 0, turn: HeldTurn = .upright, width: CGFloat = 358
    ) async throws -> (header: CGRect, firstLine: CGRect, viewfinder: CGRect, controls: CGRect, size: CGSize) {
        let frames = Frames()
        let inColumn: @Sendable (GeometryProxy) -> CGRect = { $0.frame(in: .named("column")) }
        let view = CaptureColumn(available: available) {
            TurnedBlock(length: 128, reservesLength: true) {
                VStack(spacing: 12) {
                    Color.clear.frame(height: 44)
                        .onGeometryChange(for: CGRect.self, of: inColumn) { frames.firstLine = $0 }
                    Color.clear.frame(height: 28)
                    Color.clear.frame(height: 22)
                }.frame(maxWidth: .infinity)
            }
            .onGeometryChange(for: CGRect.self, of: inColumn) { frames.header = $0 }
            .captureColumnRole(.header)
            Color.black
                .onGeometryChange(for: CGRect.self, of: inColumn) { frames.viewfinder = $0 }
                .captureColumnRole(.viewfinder(aspect: aspect))
            if controls > 0 {
                Color.clear.frame(height: controls)
                    .onGeometryChange(for: CGRect.self, of: inColumn) { frames.controls = $0 }
                    .captureColumnRole(.controls)
            }
        }
        .environment(\.heldTurn, turn)
        .coordinateSpace(name: "column")
        .frame(width: width)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        return (frames.header, frames.firstLine, frames.viewfinder, frames.controls,
                host.sizeThatFits(in: CGSize(width: width, height: 3000)))
    }

    private final class Frames { var header = CGRect.zero, firstLine = CGRect.zero, viewfinder = CGRect.zero, controls = CGRect.zero }

    /// With room to spare, the viewfinder keeps the screen's full width and the rest is shared: half to the header, as far as
    /// 300 points in all, so held on its side its lines need not wrap, and half below the viewfinder, which sits centred in the
    /// room under the header's lines. Held upright, those lines stay against the top.
    func testRoomToSpareIsSharedAboveAndBelowTheViewfinderAfterItHasItsFullWidth() async throws {
        let big = try await column(available: 700, aspect: 1)
        XCTAssertEqual(big.viewfinder.width, 358, accuracy: 0.5)
        XCTAssertEqual(big.viewfinder.height, 358, accuracy: 0.5)
        let spare = 700 - 12 - 128 - 358.0
        XCTAssertEqual(big.header.height, 128 + spare / 2, accuracy: 0.5, "Half the spare room is the header's")
        XCTAssertEqual(big.viewfinder.minY, 128 + spare / 2 + 12, accuracy: 0.5)
        XCTAssertEqual(700 - big.viewfinder.maxY, spare / 2, accuracy: 0.5, "Half is below the viewfinder")
        XCTAssertEqual(big.firstLine.minY, 0, accuracy: 0.5, "Held upright, the header's first line is against the top")
        let tight = try await column(available: 520, aspect: 1)
        XCTAssertEqual(tight.viewfinder.height, 358, accuracy: 0.5, "The viewfinder has its full width first")
        XCTAssertEqual(tight.header.height, 128 + (520 - 12 - 128 - 358.0) / 2, accuracy: 0.5)
        XCTAssertEqual(tight.firstLine.minY, 0, accuracy: 0.5)
        let huge = try await column(available: 1200, aspect: 1)
        XCTAssertEqual(huge.header.height, 300, accuracy: 0.5, "The header is capped at 300 points")
    }

    /// Short of room, the viewfinder keeps its shape and gives up width, so the whole of it shows above the shutter bar.
    func testShortOfRoomTheViewfinderKeepsItsShapeAndGivesUpWidth() async throws {
        let tall = try await column(available: 540, aspect: 2.0 / 3)
        XCTAssertEqual(tall.header.height, 128, accuracy: 0.5)
        XCTAssertEqual(tall.viewfinder.height, 540 - 128 - 12, accuracy: 0.5)
        XCTAssertEqual(tall.viewfinder.width, tall.viewfinder.height * 2.0 / 3, accuracy: 0.5)
        XCTAssertLessThan(tall.viewfinder.width, 358)
        XCTAssertEqual(tall.viewfinder.midX, 179, accuracy: 0.5, "It sits in the middle")
        XCTAssertLessThanOrEqual(tall.viewfinder.maxY, 540 + 0.5, "The whole viewfinder is within the room")
        let controls = try await column(available: 540, aspect: 1, controls: 120)
        XCTAssertEqual(controls.viewfinder.height, 540 - 128 - 120 - 24, accuracy: 0.5, "The controls take their room first")
        XCTAssertEqual(controls.controls.minY, controls.viewfinder.maxY + 12, accuracy: 0.5)
        XCTAssertLessThanOrEqual(controls.controls.maxY, 540 + 0.5)
    }

    /// Below the smallest viewfinder the column is taller than the room, and the screen scrolls.
    func testTheViewfinderIsNeverSmallerThanItsMinimum() async throws {
        let cramped = try await column(available: 300, aspect: 1)
        XCTAssertEqual(cramped.viewfinder.height, 220, accuracy: 0.5)
        XCTAssertGreaterThan(cramped.size.height, 300)
    }

    /// The viewfinder is the same size in the same place however the iPhone is held, with and without controls and at the
    /// shape of every Camera.
    func testTheViewfinderIsTheSameInEveryHold() async throws {
        for (aspect, controls) in [(CGFloat(1), CGFloat(0)), (2.0 / 3, 0), (3.0 / 4, 0), (1, 120)] {
            for available in [CGFloat(480), 560, 640, 760] {
                let upright = try await column(available: available, aspect: aspect, controls: controls)
                for turn in [HeldTurn.clockwise, .counterClockwise] {
                    let turned = try await column(available: available, aspect: aspect, controls: controls, turn: turn)
                    XCTAssertEqual(turned.viewfinder, upright.viewfinder, "aspect \(aspect), room \(available), \(turn)")
                    XCTAssertEqual(turned.header.height, upright.header.height, "aspect \(aspect), room \(available), \(turn)")
                    XCTAssertEqual(turned.controls, upright.controls)
                }
            }
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
                    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
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
        var controls = NativeCameraControls()
        controls.manualFocus = true
        controls.minimumExposureBias = -2
        controls.maximumExposureBias = 2
        let steps = RearLensCapabilities(lenses: [.init(.ultraWide, displayFactor: 0.5),
                                                  .init(.wide, displayFactor: 1, nativeCropFactors: [2]),
                                                  .init(.telephoto, displayFactor: 3)]).zoomSteps
        controls.zoomSteps = steps
        for (selected, held, name) in [(1, CaptureFrameOrientation.portrait, "portrait"), (3, .landscapeLeft, "left")] {
            controls.zoomStep = steps[selected]
            for (style, styleName) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
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
                let attachment = XCTAttachment(image: screenshot)
                attachment.name = "Zoom-enabled-\(name)-\(styleName)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    private func makeModel() async throws -> (URL, JournalModel) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureSideways-\(UUID())")
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true))
        await model.recoverAtLaunch()
        return (root, model)
    }
}

/// The Instant prints revealed and not yet dropped by `showNextPrint`, and the question about an original that is up, for
/// the test of the hold.
@Observable private final class PrintShowing {
    var revealedPrints: [Int] = []
    var originalAsk: OriginalAsk?
}

/// Holds the window by `CaptureView`'s own rule.
private struct HoldProbe: View {
    let showing: PrintShowing
    var body: some View {
        Color.clear.holdsInterfaceOrientation(
            .portrait,
            while: CaptureView.holdsWindowUpright(revealedPrints: showing.revealedPrints, originalAsk: showing.originalAsk)
        ) { .portrait }
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
                        slider: Color.gray.frame(height: 30).onAppear { probe.appearances += 1 })
            .environment(\.heldTurn, probe.turn)
            .padding()
    }
}
