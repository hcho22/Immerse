import CapturePipeline
import EntitlementCore
import FilmDomain
import FilmPersistence
import Foundation
import NativeAdapters

public actor TrialCoordinator {
    private let repository: FilmRepository
    private let root: URL
    private let store: any DeviceTrialStoring

    public init(root: URL, store: any DeviceTrialStoring = KeychainDeviceTrialStore()) throws {
        self.root = root
        self.repository = try FilmRepository(rootURL: root)
        self.store = store
    }

    /// No StoreKit or network request is made by Trial browsing or activation.
    public func state() throws -> DeviceTrialState {
        try reconcile()
        guard let record = try store.read() else { return .unused }
        if let id = record.consumedFilmID, let date = record.consumedAt {
            return .consumed(record: DeviceTrialConsumptionRecord(filmID: id, consumedAt: date))
        }
        for film in try repository.allFilms() {
            if try repository.filmAccess(filmID: film.id) == .trial(originDevice: record.deviceID) {
                return .emptyFilmInProgress(filmID: film.id)
            }
        }
        return .unused
    }

    public func start(camera: CameraPackage, title: String, orientation: MovieOrientation? = nil) throws -> Film {
        let record = try store.ensureDeviceRecord()
        switch try state() {
        case .unused:
            return try repository.createFilm(camera: camera, title: title, movieOrientation: orientation,
                access: .trial(originDevice: record.deviceID))
        case let .emptyFilmInProgress(id): throw EntitlementDenial.currentDeviceTrialAlreadyInProgress(id)
        case .consumed: throw EntitlementDenial.currentDeviceTrialConsumed
        }
    }

    public func reconcile() throws {
        guard let record = try store.read() else { return }
        for pending in try repository.pendingTrialConsumptions().sorted(by: { $0.savedAt < $1.savedAt })
            where pending.originDevice == record.deviceID {
            try store.consume(filmID: pending.filmID, savedAt: pending.savedAt)
            try repository.finishTrialConsumption(filmID: pending.filmID)
        }
    }

    public func receiver(filmID: UUID) throws -> TrialCaptureReceiver {
        _ = try repository.film(id: filmID)
        return try TrialCaptureReceiver(filmID: filmID, root: root, trial: self)
    }
}

public actor TrialCaptureReceiver: CaptureSaveCommitting {
    private let captures: CapturePipelineReceiver
    private let trial: TrialCoordinator

    init(filmID: UUID, root: URL, trial: TrialCoordinator) throws {
        self.captures = try CapturePipelineReceiver(filmID: filmID, repositoryURL: root)
        self.trial = trial
    }

    public func commit(_ event: CaptureSaveEvent) async throws {
        try await captures.commit(event)
        // Baseline D3: the SQLite outbox and capture commit atomically. Keychain
        // reconciliation is retryable while installed, not atomic across uninstall.
        try await trial.reconcile()
    }
}
