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

    /// The header reserves the same height in every hold, so the viewfinder below it never moves.
    func testAHeaderThatReservesItsLengthIsTheSameHeightInEveryHold() {
        let header = TurnedBlock(length: 128, reservesLength: true) {
            VStack(spacing: 12) {
                Color.clear.frame(height: 44)
                Color.clear.frame(height: 28)
                Color.clear.frame(height: 22)
            }.frame(maxWidth: .infinity)
        }
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

    /// Each Camera's shooting screen held upright, on its left side and on its right side, at the default text size and the
    /// largest, kept as screenshots. The viewfinder is a black box that keeps its size and place, with the live picture's
    /// shape, a landscape one on the side holds, inside it. The 6×6's zoom pill, sliders and the Disposable's cue are
    /// raised from what a lens would report, since the simulator has no lens.
    func testCaptureScreensHeldSidewaysKeepTheLayoutAndTurnTheText() async throws {
        let (root, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        var controls = NativeCameraControls()
        controls.flash = true
        controls.manualFocus = true
        controls.minimumExposureBias = -2
        controls.maximumExposureBias = 2
        let steps = RearLensCapabilities(lenses: [.init(.ultraWide, displayFactor: 0.5), .init(.wide, displayFactor: 1),
                                                  .init(.telephoto, displayFactor: 3)], wideNativeCropFactors: [2]).zoomSteps
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
                    model.capture.message = nil
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

    private func makeModel() async throws -> (URL, JournalModel) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureSideways-\(UUID())")
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true))
        await model.recoverAtLaunch()
        return (root, model)
    }
}
