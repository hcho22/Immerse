import FilmDomain
import Foundation

public struct PendingCaptureRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let mediaKind: CaptureMediaKind
    public let createdAt: Date
    public let orientation: ClipOrientation?
    public let remainingFrames: Int?

    public init(id: UUID, mediaKind: CaptureMediaKind, createdAt: Date = Date(),
                orientation: ClipOrientation? = nil, remainingFrames: Int? = nil) {
        self.id = id; self.mediaKind = mediaKind; self.createdAt = createdAt
        self.orientation = orientation; self.remainingFrames = remainingFrames
    }
}
