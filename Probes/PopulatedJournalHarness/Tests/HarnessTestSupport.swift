import XCTest

/// The base of every workflow test class. Each test starts with the simulator held upright. A test stopped at its time
/// allowance runs no `defer` or teardown, so a turn it made stays: run 38980604148 stopped a landscape Darkroom test,
/// and the next test launched the app sideways and failed on a tap (Evidence/NativeApp/main-ci-flakes-069.md).
@MainActor
class HarnessTestCase: XCTestCase {
    /// Launches the harness once before the class's first test, outside every test's time allowance: a session's first
    /// launch, where XCTest installs the app, is the slowest on CI (Evidence/NativeApp/main-ci-flakes-072.md).
    override class func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            let app = XCUIApplication()
            app.launch()
            app.terminate()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        XCUIDevice.shared.orientation = .portrait
    }
}

extension XCUICoordinate {
    /// Presses a slider's thumb and drags it to `end`, then keeps the finger down for 1.5 s before lifting it, where a
    /// bare `press(forDuration:thenDragTo:)` lifts it while it is still moving. The finger's whole path reaches the app
    /// on time, but when the app's main thread stops for about a second in the middle of the drag, as it did once on
    /// CI, a finger lifted inside that time is handled together with the moves before it: iOS 26's slider then springs
    /// back towards the value it had before the stop and comes to rest on the way, at 2.0 stops where the drag was to
    /// end at -3.0 (`Evidence/NativeApp/main-ci-flakes-072.md`). A finger still down when the app catches up is handled
    /// in order, so the slider ends under it; the hold covers a stop that ends up to about 2.5 s after the finger went
    /// down. A longer stop still fails the test. This is one drag, never a second.
    func dragThumb(to end: XCUICoordinate) {
        press(forDuration: 0.2, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 1.5)
    }
}

extension XCUIElement {
    /// Flips a switch with a press held for 1 s, where `tap()` holds for 66 ms. When the simulator's touch service is
    /// late to register the touchscreen XCTest attaches for a tap, the finger-down and the finger-up reach the app a few
    /// milliseconds apart, and a switch ignores that touch; a press held longer than the lag, which reached 628 ms once
    /// on CI, still has its finger-up after its finger-down (the same helper is `flipSwitch` in the app's screen tests,
    /// `Evidence/NativeApp/main-ci-flakes-069.md`). This is one press, never a second tap.
    func flipSwitch() {
        press(forDuration: 1)
    }
}
