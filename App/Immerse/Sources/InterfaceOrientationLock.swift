import NativeAdapters
import SwiftUI
import UIKit

/// The interface orientations the app lets its window take. Every screen turns with the iPhone, as the Info.plist allows,
/// except the shooting screen, which holds the portrait layout whichever way the iPhone is held (`HeldTurn`).
final class ImmerseAppDelegate: NSObject, UIApplicationDelegate {
    @MainActor static var supportedOrientations = UIInterfaceOrientationMask.allButUpsideDown

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { Self.supportedOrientations }
    }
}

@MainActor
enum InterfaceOrientationLock {
    /// Limits the app's window to `mask` and turns it to an orientation the mask allows, now.
    static func hold(_ mask: UIInterfaceOrientationMask) {
        ImmerseAppDelegate.supportedOrientations = mask
        apply(mask)
    }

    /// Lets every screen turn with the iPhone again, and turns the window to `mask`, the orientation the iPhone is held in.
    /// The device's orientation is read by the caller, since it is valid only while the shooting screen asks for its
    /// notifications, which end with it.
    static func release(turningTo mask: UIInterfaceOrientationMask) {
        ImmerseAppDelegate.supportedOrientations = .allButUpsideDown
        apply(mask)
    }

    /// The interface orientation that shows an iPhone held as `held` upright. The device's landscape orientations are
    /// named for the side the home button is on and the interface's for the side the top is on, so the two are mirrored.
    /// The app has no upside-down portrait, so that hold leaves the window as it is.
    static func mask(held: CaptureFrameOrientation) -> UIInterfaceOrientationMask {
        switch held {
        case .portrait: .portrait
        case .landscapeLeft: .landscapeRight
        case .landscapeRight: .landscapeLeft
        case .portraitUpsideDown: .allButUpsideDown
        }
    }

    private static func apply(_ mask: UIInterfaceOrientationMask) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            var controller = scene.keyWindow?.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }
}

extension View {
    /// Holds the window to `mask` while this view is on screen, and over anything it presents as a sheet. Every other
    /// screen is unaffected, since the hold ends when this view leaves, and the window then turns to `release`, the
    /// orientation the iPhone is held in.
    func holdsInterfaceOrientation(
        _ mask: UIInterfaceOrientationMask, thenTurnTo release: @escaping @MainActor () -> UIInterfaceOrientationMask
    ) -> some View {
        onAppear { InterfaceOrientationLock.hold(mask) }
            .onDisappear { InterfaceOrientationLock.release(turningTo: release()) }
    }
}
