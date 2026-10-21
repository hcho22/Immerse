import XCTest

/// A freshly booted simulator answers slowly for its first minutes on CI, which fell inside the session's first test
/// (Evidence/NativeApp/main-ci-flakes-075.md). So before the first test the app's own first steps are made again and
/// timed, a pass at a time, until a pass is no longer a fifth quicker than the one before it: a quick simulator is through
/// in two passes and a slow one takes the passes it needs, at most six, and none begins after 6 minutes. It runs once for
/// the session, in a class `setUp`, outside every test's allowance, asserts nothing, and writes each pass's time to the
/// test runner's output (the same type is in the app's `UITestSupport.swift`).
@MainActor
enum SimulatorWarmUp {
    private static var settled = false

    /// Runs the passes and returns true the first time; returns false, doing nothing, every time after.
    static func settle(pass: () -> Void) -> Bool {
        guard !settled else { return false }
        settled = true
        let began = Date()
        var previous: TimeInterval?
        for number in 1...6 {
            let start = Date()
            pass()
            let took = Date().timeIntervalSince(start)
            print("Simulator warm-up pass \(number): \(String(format: "%.1f", took)) s")
            if let previous, took >= previous * 0.8 { break }
            if Date().timeIntervalSince(began) > 360 { break }
            previous = took
        }
        return true
    }
}

/// The base of every workflow test class. Each test starts with the simulator held upright. A test stopped at its time
/// allowance runs no `defer` or teardown, so a turn it made stays: run 38980604148 stopped a landscape Darkroom test,
/// and the next test launched the app sideways and failed on a tap (Evidence/NativeApp/main-ci-flakes-069.md).
@MainActor
class HarnessTestCase: XCTestCase {
    /// Launches the harness before the class's first test, outside every test's time allowance: once, or in each pass of
    /// `SimulatorWarmUp` in a session's first class. A session's first launch, where XCTest installs the app, is the
    /// slowest on CI (Evidence/NativeApp/main-ci-flakes-072.md). These launches seed with `--scratch-history`, so they
    /// leave no history beside the tests' own for `inspect-retained.rb` to count.
    override class func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            // The first class of a session settles the simulator; every other class makes the plain first launch.
            if !SimulatorWarmUp.settle(pass: { warmUpPass() }) { launchOnce() }
        }
    }

    private static func launchOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["--scratch-history"]
        app.launch()
        app.terminate()
    }

    /// What every workflow test does first, once: the launch, a turn to one side and back with a capture each, and a
    /// second launch (the pass the app's screen tests make in `ScreenTestCase`, less the Camera catalog, which no workflow
    /// test opens).
    private static func warmUpPass() {
        let app = XCUIApplication()
        app.launchArguments = ["--scratch-history"]
        app.launch()
        _ = app.buttons["start-film"].waitForExistence(timeout: 10)
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            _ = XCUIScreen.main.screenshot()
        }
        app.terminate()
        app.launch()
        app.terminate()
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
