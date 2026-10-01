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

        return CaptureCapabilities(
            availablePositions: positions,
            supportsLensSwitchDuringSession: positions.count > 1
        )
    }
}

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
