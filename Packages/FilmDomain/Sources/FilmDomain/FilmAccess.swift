import Foundation

public enum FilmAccess: Codable, Equatable, Sendable {
    case subscription
    case trial(originDevice: UUID)
    /// A Roll taken in a Group Film (v2 PRD V2-FR-25): its right to shoot comes from the event on Immerse's server, never
    /// from the subscription or the Trial (V2-FR-07). Its Film lives in a store of its own, apart from personal Films.
    case groupRoll(eventID: String)

    /// Whether this is an event Roll rather than a personal Film.
    public var isGroupRoll: Bool {
        if case .groupRoll = self { return true }
        return false
    }
}

public struct PendingTrialConsumption: Codable, Equatable, Sendable {
    public let filmID: UUID
    public let originDevice: UUID
    public let savedAt: Date

    public init(filmID: UUID, originDevice: UUID, savedAt: Date) {
        self.filmID = filmID
        self.originDevice = originDevice
        self.savedAt = savedAt
    }
}
