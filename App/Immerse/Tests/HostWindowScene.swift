import UIKit

/// The scene the hosted tests put their windows in.
///
/// XCTest starts running tests as soon as its runner is ready, and the simulator's SpringBoard hands the app its
/// scene on its own time: usually half a second before the first test, but on CI run 39098085159 five seconds after
/// it, because SpringBoard answered the app's FrontBoard handshake seven seconds late
/// (Evidence/NativeApp/main-ci-flakes-071.md). A test that needs a window waits here for the scene to connect,
/// never reads `connectedScenes` once at its first line.
@MainActor
func hostWindowScene(within timeout: Duration = .seconds(60)) async throws -> UIWindowScene {
    func connected() -> UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
    if let scene = connected() { return scene }
    let clock = ContinuousClock()
    let start = clock.now
    let deadline = start.advanced(by: timeout)
    while true {
        // The main run loop has to turn for the scene to connect, so wait for it here instead of holding the thread.
        try await Task.sleep(for: .milliseconds(20))
        if let scene = connected() {
            // In the test's output, so a result bundle shows which tests had to wait and for how long.
            print("hostWindowScene: the scene connected \(start.duration(to: clock.now)) after the test asked for it")
            return scene
        }
        guard clock.now < deadline else { throw HostWindowSceneError(waited: timeout) }
    }
}

struct HostWindowSceneError: Error, CustomStringConvertible {
    let waited: Duration

    var description: String {
        "No window scene connected to the hosting app within \(waited): the app never received its scene from SpringBoard."
    }
}
