@preconcurrency import AVFoundation
import Foundation

public struct AVFoundationCaptureDeviceDiscoverer: CaptureDeviceDiscovering {
    public init() {}

    public func capabilities() -> CaptureCapabilities {
        let positions = Set(
            AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            .devices
            .compactMap { device -> CapturePosition? in
                switch device.position {
                case .back:
                    return .rear
                case .front:
                    return .front
                default:
                    return nil
                }
            }
        )

        #if os(iOS)
        let rearLenses = Self.rearLenses()
        #else
        let rearLenses = RearLensCapabilities.wideOnly
        #endif
        return CaptureCapabilities(
            availablePositions: positions,
            supportsLensSwitchDuringSession: positions.count > 1,
            rearLenses: rearLenses
        )
    }
}

#if os(iOS)
extension AVFoundationCaptureDeviceDiscoverer {
    /// The rear lenses as the iPhone reports them, labeled the way its Camera app labels them. The lens list and each
    /// lens's factor come from the rear virtual device (triple, dual wide or dual camera), which is only read: the
    /// switch-over zoom factors say where each lens takes over, and `displayVideoZoomFactorMultiplier` converts the
    /// virtual device's zoom factor to the Camera app's (0.5 where an ultra wide lens starts at 1). The wide lens's
    /// native crops are the zoom factors its active format reports (`secondaryNativeResolutionZoomFactors`), which
    /// depend on the format the session's preset chose, so the backend reads this again once its session runs.
    static func rearLenses() -> RearLensCapabilities {
        guard let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return .wideOnly
        }
        let crops = wide.activeFormat.secondaryNativeResolutionZoomFactors.map { Double($0) }.filter { $0 > 1 }
        let wideOnly = RearLensCapabilities(lenses: [.init(.wide, displayFactor: 1)], wideNativeCropFactors: crops)
        guard let virtual = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera],
            mediaType: .video, position: .back
        ).devices.first else { return wideOnly }
        let constituents = virtual.constituentDevices
        let switchOvers = [1.0] + virtual.virtualDeviceSwitchOverVideoZoomFactors.map { $0.doubleValue }
        guard constituents.count == switchOvers.count else { return wideOnly }
        let multiplier = Double(virtual.displayVideoZoomFactorMultiplier)
        var lenses: [RearLensCapabilities.Lens] = []
        for (device, factor) in zip(constituents, switchOvers) {
            let lens: RearLens
            switch device.deviceType {
            case .builtInUltraWideCamera: lens = .ultraWide
            case .builtInWideAngleCamera: lens = .wide
            case .builtInTelephotoCamera: lens = .telephoto
            default: return wideOnly
            }
            lenses.append(.init(lens, displayFactor: (factor * multiplier * 10).rounded() / 10))
        }
        return RearLensCapabilities(lenses: lenses, wideNativeCropFactors: crops)
    }
}
#endif

public struct AVFoundationCaptureAuthorizer: CapturePermissionAuthorizing {
    public init() {}

    public func authorizationStatus() -> CaptureAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    public func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
