import Foundation

public enum FilmAccess: Codable, Equatable, Sendable {
    case subscription
    case trial(originDevice: UUID)
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
