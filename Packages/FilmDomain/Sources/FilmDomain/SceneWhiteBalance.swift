import Foundation

/// The color of the light a Movie clip was recorded in, as the phone's white balance judged it when recording began.
/// The capture writes it into the clip, and a Film Stock with a fixed color balance develops against it: the 16mm
/// Cinema's color Film Stock is balanced for daylight, so warm indoor light develops orange (PRD 2.1 section 6.2).
public struct SceneWhiteBalance: Equatable, Sendable {
    /// The clip's QuickTime metadata key.
    public static let metadataKey = "app.immerse.scene-white-balance"

    /// The light's correlated color temperature, in kelvin.
    public let temperature: Double
    /// Its tint: negative toward green, positive toward magenta.
    public let tint: Double

    public init(temperature: Double, tint: Double) {
        self.temperature = temperature
        self.tint = tint
    }

    /// The metadata value: temperature and tint, separated by a comma.
    public var metadataValue: String { "\(temperature),\(tint)" }

    /// The record a clip carries, or nil for a value that is not two finite numbers.
    public init?(metadataValue: String) {
        let parts = metadataValue.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, parts.allSatisfy(\.isFinite), parts[0] > 0 else { return nil }
        self.init(temperature: parts[0], tint: parts[1])
    }
}
