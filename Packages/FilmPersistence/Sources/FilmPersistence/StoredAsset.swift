import Foundation

public struct StoredAsset: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case source
        case master
        case clip
        case movie
    }

    public let filmID: UUID
    public let sequenceNumber: Int
    public let kind: Kind
    public let relativePath: String
    public let sha256: String
}
