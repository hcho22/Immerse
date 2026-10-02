import Foundation

public enum SubscriptionAccess: Equatable, Sendable {
    case active
    case expired
    case notPurchased
}

public enum DeviceTrialState: Equatable, Sendable {
    case unused
    case emptyFilmInProgress(filmID: UUID)
    case consumed(record: DeviceTrialConsumptionRecord)
}

public struct DeviceTrialConsumptionRecord: Equatable, Sendable {
    public let filmID: UUID
    public let consumedAt: Date

    public init(filmID: UUID, consumedAt: Date) {
        self.filmID = filmID
        self.consumedAt = consumedAt
    }
}

public enum EntitlementDenial: Error, Equatable, Sendable {
    case currentDeviceTrialAlreadyInProgress(UUID)
    case currentDeviceTrialConsumed
}
