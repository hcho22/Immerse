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
    /// virtual device's zoom factor to the Camera app's (0.5 where an ultra wide lens starts at 1). Each lens's native
    /// crops are the zoom factors its active format reports (`secondaryNativeResolutionZoomFactors`), which depend on the
    /// format a session's preset chose for it, so the backend reads this again once its session runs.
    static func rearLenses() -> RearLensCapabilities {
        guard let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return .wideOnly
        }
        let wideOnly = RearLensCapabilities(
            lenses: [.init(.wide, displayFactor: 1, nativeCropFactors: nativeCrops(of: wide))]
        )
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
            lenses.append(.init(
                lens, displayFactor: (factor * multiplier * 10).rounded() / 10, nativeCropFactors: nativeCrops(of: device)
            ))
        }
        return RearLensCapabilities(lenses: lenses)
    }

    private static func nativeCrops(of lens: AVCaptureDevice) -> [Double] {
        lens.activeFormat.secondaryNativeResolutionZoomFactors.map { Double($0) }
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

    public func microphoneAuthorizationStatus() -> CaptureAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    public func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
