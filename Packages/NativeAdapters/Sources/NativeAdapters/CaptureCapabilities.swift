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
    /// The rear lenses and their native crops, which the 6×6, Super 8 and 16mm zoom steps derive from.
    public let rearLenses: RearLensCapabilities

    public init(
        availablePositions: Set<CapturePosition>,
        supportsLensSwitchDuringSession: Bool,
        rearLenses: RearLensCapabilities = .wideOnly
    ) {
        self.availablePositions = availablePositions
        self.supportsLensSwitchDuringSession = supportsLensSwitchDuringSession
        self.rearLenses = rearLenses
    }

    public func isAvailable(_ position: CapturePosition) -> Bool {
        availablePositions.contains(position)
    }
}

public protocol CaptureDeviceDiscovering: Sendable {
    func capabilities() -> CaptureCapabilities
}
