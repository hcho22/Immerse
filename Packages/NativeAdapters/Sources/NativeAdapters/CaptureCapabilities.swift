import Foundation

public enum CapturePosition: String, Codable, Equatable, Hashable, Sendable {
    case rear
    case front
}

public enum CaptureMediaKind: String, Codable, Equatable, Sendable {
    case photo
    case movie
}

public struct CaptureCapabilities: Codable, Equatable, Sendable {
    public let availablePositions: Set<CapturePosition>
    public let supportsLensSwitchDuringSession: Bool

    public init(
        availablePositions: Set<CapturePosition>,
        supportsLensSwitchDuringSession: Bool
    ) {
        self.availablePositions = availablePositions
        self.supportsLensSwitchDuringSession = supportsLensSwitchDuringSession
    }

    public func isAvailable(_ position: CapturePosition) -> Bool {
        availablePositions.contains(position)
    }
}

public protocol CaptureDeviceDiscovering: Sendable {
    func capabilities() -> CaptureCapabilities
}
