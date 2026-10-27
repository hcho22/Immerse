import Foundation
import MediaCatalog

public enum MovieSoundChoice: String, Codable, Equatable, Sendable {
    case recordedSound
    case soundtrack
    case silent
}

public struct MovieAudioSelection: Codable, Equatable, Sendable {
    public let revision: UUID
    /// Nil only in selections saved before MOV-13. An old nil asset means Silent; a new Film without a selection
    /// defaults to Recorded sound when its locked package records live sound.
    public let choice: MovieSoundChoice?
    public let asset: CatalogMediaAsset?

    public init(revision: UUID = UUID(), choice: MovieSoundChoice? = nil, asset: CatalogMediaAsset? = nil) {
        self.revision = revision
        self.choice = choice
        self.asset = asset
    }

    public func effectiveChoice(recordsLiveSound: Bool) -> MovieSoundChoice {
        if let choice { return choice }
        if asset != nil { return .soundtrack }
        return recordsLiveSound ? .recordedSound : .silent
    }
}
