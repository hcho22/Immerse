import FilmDomain
import Foundation

public struct CaptureCommitReceipt: Codable, Equatable, Sendable {
    public let captureID: String
    public let filmID: UUID
    public let sequenceNumber: Int
    public let kind: CaptureKind
    public let sourceSHA256: String
}
