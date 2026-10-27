import NativeAdapters
import SwiftUI
import UIKit

/// The interface orientations the app lets its window take. Screens turn with the iPhone, as the Info.plist allows,
/// except the shooting screen and Darkroom, which keep their portrait layouts while the iPhone is held sideways.
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
    static var allowedOrientations: UIInterfaceOrientationMask { ImmerseAppDelegate.supportedOrientations }

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

    /// Restores both the orientations the covered screen allowed and its current interface orientation.
    static func restore(allowing allowed: UIInterfaceOrientationMask, turningTo mask: UIInterfaceOrientationMask) {
        ImmerseAppDelegate.supportedOrientations = allowed
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

    /// The current window orientation, read before a portrait-only sheet changes it.
    static func currentWindowMask() -> UIInterfaceOrientationMask {
        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?.effectiveGeometry.interfaceOrientation ?? .unknown
        return mask(interfaceOrientation: orientation)
    }

    static func mask(interfaceOrientation: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        switch interfaceOrientation {
        case .portrait: .portrait
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        default: .allButUpsideDown
        }
    }

    /// The interface orientation that matches how the device is held, or `fallback` where it is not held upright.
    static func mask(deviceOrientation: UIDeviceOrientation, fallback: UIInterfaceOrientationMask) -> UIInterfaceOrientationMask {
        switch deviceOrientation {
        case .portrait: .portrait
        case .landscapeLeft: .landscapeRight
        case .landscapeRight: .landscapeLeft
        default: fallback
        }
    }

    private static func apply(_ mask: UIInterfaceOrientationMask) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            var controller = scene.keyWindow?.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
            // No error handler: UIKit calls it from a background queue when the request times out, and a closure written
            // here is main-actor isolated, so it traps there.
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask), errorHandler: nil)
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

    /// Holds this presentation in portrait and restores the orientation it covered when it leaves.
    func holdsPortraitOrientationPreservingCurrent() -> some View {
        modifier(PortraitOrientationHold())
    }
}

private struct PortraitOrientationHold: ViewModifier {
    @State private var priorAllowedOrientations: UIInterfaceOrientationMask = .allButUpsideDown
    @State private var priorOrientation: UIInterfaceOrientationMask = .allButUpsideDown
    @State private var followsDeviceOrientation = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                priorAllowedOrientations = InterfaceOrientationLock.allowedOrientations
                priorOrientation = InterfaceOrientationLock.currentWindowMask()
                followsDeviceOrientation = priorAllowedOrientations == .allButUpsideDown
                if followsDeviceOrientation { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
                InterfaceOrientationLock.hold(.portrait)
            }
            .onDisappear {
                let orientation = followsDeviceOrientation
                    ? InterfaceOrientationLock.mask(deviceOrientation: UIDevice.current.orientation, fallback: priorOrientation)
                    : priorOrientation
                if followsDeviceOrientation { UIDevice.current.endGeneratingDeviceOrientationNotifications() }
                InterfaceOrientationLock.restore(allowing: priorAllowedOrientations, turningTo: orientation)
            }
    }
}
