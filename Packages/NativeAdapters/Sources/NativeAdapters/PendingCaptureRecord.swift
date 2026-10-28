import FilmDomain
import Foundation

public struct PendingCaptureRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let mediaKind: CaptureMediaKind
    public let createdAt: Date
    public let orientation: ClipOrientation?
    public let remainingFrames: Int?
    /// Whether this Film's locked package permits its clips to contain an audio track. Nil in pre-MOV-12 staging records.
    public let allowsAudio: Bool?

    public init(id: UUID, mediaKind: CaptureMediaKind, createdAt: Date = Date(),
                orientation: ClipOrientation? = nil, remainingFrames: Int? = nil, allowsAudio: Bool? = false) {
        self.id = id; self.mediaKind = mediaKind; self.createdAt = createdAt
        self.orientation = orientation; self.remainingFrames = remainingFrames
        self.allowsAudio = allowsAudio
    }
}
