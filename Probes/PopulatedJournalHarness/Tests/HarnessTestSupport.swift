import XCTest

/// The base of every workflow test class. Each test starts with the simulator held upright. A test stopped at its time
/// allowance runs no `defer` or teardown, so a turn it made stays: run 38980604148 stopped a landscape Darkroom test,
/// and the next test launched the app sideways and failed on a tap (Evidence/NativeApp/main-ci-flakes-069.md).
@MainActor
class HarnessTestCase: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        XCUIDevice.shared.orientation = .portrait
    }
}

extension XCUIElement {
    /// Flips a switch with a press held for 0.3 s, where `tap()` holds for 66 ms. When the simulator's touch service is
    /// late to register the touchscreen XCTest attaches for a tap, the finger-down and the finger-up reach the app a few
    /// milliseconds apart, and a switch ignores that touch (the same helper is `flipSwitch` in the app's screen tests,
    /// `Evidence/NativeApp/main-ci-flakes-069.md`). This is one press, never a second tap.
    func flipSwitch() {
        press(forDuration: 0.3)
    }
}
