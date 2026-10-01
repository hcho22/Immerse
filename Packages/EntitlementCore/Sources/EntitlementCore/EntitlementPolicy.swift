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

public enum FilmEntitlementOrigin: Equatable, Sendable {
    case subscription
    case currentDeviceTrial
    case restoredTrialFromAnotherDevice
}

public struct ExistingFilmEntitlement: Equatable, Sendable {
    public let filmID: UUID
    public let origin: FilmEntitlementOrigin
    public var hasSavedCapture: Bool

    public init(
        filmID: UUID,
        origin: FilmEntitlementOrigin,
        hasSavedCapture: Bool
    ) {
        self.filmID = filmID
        self.origin = origin
        self.hasSavedCapture = hasSavedCapture
    }
}

public enum NewFilmEntitlement: Equatable, Sendable {
    case subscription
    case currentDeviceTrial
}

public enum EntitlementDecision: Equatable, Sendable {
    case allowed(NewFilmEntitlement)
    case denied(EntitlementDenial)
}

public enum EntitlementDenial: Error, Equatable, Sendable {
    case subscriptionRequired
    case currentDeviceTrialAlreadyInProgress(UUID)
    case currentDeviceTrialConsumed
}

public enum TrialConsumptionEvent: Equatable, Sendable {
    case failedBeforeDurableSave
    case firstSuccessfulSave(Date)
}

public enum EntitlementPolicyError: Error, Equatable, Sendable {
    case notCurrentDeviceTrial
    case trialFilmMismatch
    case currentDeviceTrialAlreadyConsumed
    case deleteFilmDoesNotMatchCurrentEmptyTrial
}

/// Pure policy only. This type intentionally performs no StoreKit lookup and no Keychain write.
public enum EntitlementPolicy {
    public static func decisionForNewFilm(
        subscription: SubscriptionAccess,
        deviceTrial: DeviceTrialState,
        requestedByNonSubscriber: Bool
    ) -> EntitlementDecision {
        if subscription == .active {
            return .allowed(.subscription)
        }

        guard requestedByNonSubscriber else {
            return .denied(.subscriptionRequired)
        }

        switch deviceTrial {
        case .unused:
            return .allowed(.currentDeviceTrial)
        case let .emptyFilmInProgress(filmID):
            return .denied(.currentDeviceTrialAlreadyInProgress(filmID))
        case .consumed:
            return .denied(.currentDeviceTrialConsumed)
        }
    }

    public static func startCurrentDeviceTrialFilm(
        filmID: UUID,
        deviceTrial: DeviceTrialState
    ) -> Result<DeviceTrialState, EntitlementDenial> {
        switch deviceTrial {
        case .unused:
            .success(.emptyFilmInProgress(filmID: filmID))
        case let .emptyFilmInProgress(existingFilmID):
            .failure(.currentDeviceTrialAlreadyInProgress(existingFilmID))
        case .consumed:
            .failure(.currentDeviceTrialConsumed)
        }
    }

    public static func applyCaptureEvent(
        _ event: TrialConsumptionEvent,
        to film: ExistingFilmEntitlement,
        deviceTrial: DeviceTrialState
    ) throws -> (film: ExistingFilmEntitlement, deviceTrial: DeviceTrialState) {
        guard film.origin == .currentDeviceTrial else {
            throw EntitlementPolicyError.notCurrentDeviceTrial
        }

        switch event {
        case .failedBeforeDurableSave:
            return (film, deviceTrial)
        case let .firstSuccessfulSave(consumedAt):
            switch deviceTrial {
            case let .emptyFilmInProgress(filmID) where filmID == film.filmID:
                var updatedFilm = film
                updatedFilm.hasSavedCapture = true
                return (
                    updatedFilm,
                    .consumed(record: DeviceTrialConsumptionRecord(filmID: film.filmID, consumedAt: consumedAt))
                )
            case let .consumed(record) where record.filmID == film.filmID:
                var updatedFilm = film
                updatedFilm.hasSavedCapture = true
                return (updatedFilm, deviceTrial)
            case .emptyFilmInProgress:
                throw EntitlementPolicyError.trialFilmMismatch
            case .unused:
                throw EntitlementPolicyError.trialFilmMismatch
            case .consumed:
                throw EntitlementPolicyError.currentDeviceTrialAlreadyConsumed
            }
        }
    }

    public static func deleteCurrentDeviceTrialFilm(
        film: ExistingFilmEntitlement,
        deviceTrial: DeviceTrialState
    ) throws -> DeviceTrialState {
        guard film.origin == .currentDeviceTrial else {
            throw EntitlementPolicyError.notCurrentDeviceTrial
        }

        if film.hasSavedCapture {
            return deviceTrial
        }

        switch deviceTrial {
        case let .emptyFilmInProgress(filmID) where filmID == film.filmID:
            return .unused
        case .emptyFilmInProgress:
            throw EntitlementPolicyError.deleteFilmDoesNotMatchCurrentEmptyTrial
        case .unused:
            return .unused
        case .consumed:
            return deviceTrial
        }
    }

    public static func canContinueExistingFilm(
        _ film: ExistingFilmEntitlement,
        subscription: SubscriptionAccess,
        deviceTrial: DeviceTrialState
    ) -> Bool {
        switch film.origin {
        case .subscription:
            true
        case .restoredTrialFromAnotherDevice:
            true
        case .currentDeviceTrial:
            switch deviceTrial {
            case let .emptyFilmInProgress(filmID):
                filmID == film.filmID
            case let .consumed(record):
                record.filmID == film.filmID || film.hasSavedCapture
            case .unused:
                !film.hasSavedCapture
            }
        }
    }

    public static func restoredTrialFilmDoesNotConsumeThisDevice(
        deviceTrial: DeviceTrialState
    ) -> DeviceTrialState {
        deviceTrial
    }
}
