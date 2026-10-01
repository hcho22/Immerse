import Foundation
import MediaCatalog

public struct MovieAudioSelection: Codable, Equatable, Sendable {
    public let revision: UUID
    public let asset: CatalogMediaAsset?
}
