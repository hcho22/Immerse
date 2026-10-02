import EntitlementCore
import FilmDomain
import FilmPersistence
import Foundation
import NativeAdapters

public enum TrialCommitCheckpoint: Sendable { case prepared, receiptResolved, projected }

public actor TrialCoordinator {
    private let repository: FilmRepository
    private let journal: CaptureCommitJournal
    private let store: any DeviceTrialStoring
    private let checkpoint: @Sendable (TrialCommitCheckpoint) async throws -> Void
    private let projectionFailure: SaveFailureInjection?
    private var occupied = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(root: URL, store: any DeviceTrialStoring = KeychainDeviceTrialStore(),
                projectionFailure: SaveFailureInjection? = nil,
                checkpoint: @escaping @Sendable (TrialCommitCheckpoint) async throws -> Void = { _ in }) throws {
        self.repository = try FilmRepository(rootURL: root)
        self.journal = CaptureCommitJournal(root: root)
        self.store = store
        self.checkpoint = checkpoint
        self.projectionFailure = projectionFailure
    }

    public func state() async throws -> DeviceTrialState {
        await enter(); defer { leave() }
        try await reconcileLocked()
        return try currentState()
    }

    private func currentState() throws -> DeviceTrialState {
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

    /// The single new-Film entitlement decision production executes. An active subscription
    /// loads a subscription Film and leaves this iPhone's Trial untouched; otherwise the Film
    /// uses the Trial through `start`, which refuses a Trial in progress or already consumed.
    public func load(camera: CameraPackage, title: String, orientation: MovieOrientation? = nil,
                     subscription: SubscriptionAccess) async throws -> Film {
        switch subscription {
        case .active:
            return try repository.createFilm(camera: camera, title: title, movieOrientation: orientation,
                access: .subscription)
        case .notPurchased:
            return try await start(camera: camera, title: title, orientation: orientation)
        case .expired:
            // PRD section 18 open question 7: whether a lapsed subscriber who never used the
            // Trial still gets it is undecided. Provisional default pending the captain: yes.
            return try await start(camera: camera, title: title, orientation: orientation)
        }
    }

    /// Loads a Film on this iPhone's Trial. Production reaches it only through `load`.
    public func start(camera: CameraPackage, title: String, orientation: MovieOrientation? = nil) async throws -> Film {
        await enter(); defer { leave() }
        try await reconcileLocked()
        let record = try store.ensureDeviceRecord()
        switch try currentState() {
        case .unused:
            return try repository.createFilm(camera: camera, title: title, movieOrientation: orientation,
                access: .trial(originDevice: record.deviceID))
        case let .emptyFilmInProgress(id): throw EntitlementDenial.currentDeviceTrialAlreadyInProgress(id)
        case .consumed: throw EntitlementDenial.currentDeviceTrialConsumed
        }
    }

    public func reconcile(filmID: UUID? = nil) async throws {
        await enter(); defer { leave() }
        try await reconcileLocked(filmID: filmID)
    }

    /// Call at launch or after the capture backend has quiesced, never while its
    /// native writer may still be recording into the staging directory.
    public func recoverSavedCaptures(filmID: UUID? = nil) async throws {
        await enter(); defer { leave() }
        try await reconcileLocked(filmID: filmID, recoverNativeStaging: true)
    }

    public func deleteFilm(filmID: UUID, processor: FilmProcessor? = nil) async throws {
        await enter(); defer { leave() }
        // The lease quiesces all receipt/projection work. Unknown saves need not
        // be reconciled merely to delete them; existing consumption never refunds.
        if let processor { try await processor.deleteFilm(filmID: filmID) }
        else { try repository.deleteFilm(filmID: filmID) }
    }

    private func reconcileLegacyOutbox(filmID: UUID? = nil) throws {
        let pending = try repository.pendingTrialConsumptions()
            .filter { filmID == nil || $0.filmID == filmID }.sorted { $0.savedAt < $1.savedAt }
        guard !pending.isEmpty else { return }
        for value in pending {
            let record = try store.ensureDeviceRecord()
            if value.originDevice == record.deviceID, !record.isConsumed {
                try store.consume(filmID: value.filmID, savedAt: value.savedAt)
            }
            // Foreign restored grants and already-consumed records are independent
            // of this iPhone's eligibility. Legacy committed captures never refund.
            try repository.finishTrialConsumption(filmID: value.filmID)
        }
    }

    public func receiver(filmID: UUID) throws -> TrialCaptureReceiver {
        _ = try repository.film(id: filmID)
        return TrialCaptureReceiver(filmID: filmID, trial: self)
    }

    fileprivate func commit(filmID: UUID, event: CaptureSaveEvent) async throws {
        await enter(); defer { leave() }
        try reconcileLegacyOutbox(filmID: filmID)
        try await projectPending(filmID: filmID)
        try await commitLocked(filmID: filmID, event: event)
    }

    private func reconcileLocked(filmID: UUID? = nil, recoverNativeStaging: Bool = false) async throws {
        try reconcileLegacyOutbox(filmID: filmID)
        let films = try filmID.map { [try repository.film(id: $0)] } ?? repository.allFilms()
        for film in films {
            try await projectPending(filmID: film.id)
            guard recoverNativeStaging else { continue }
            let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
            for event in try await files.recoveryEvents() {
                try await commitLocked(filmID: film.id, event: event)
                try files.removeCommittedFile(for: event)
            }
        }
    }

    private func projectPending(filmID: UUID) async throws {
        _ = try repository.film(id: filmID)
        for operation in try journal.pending(filmID: filmID) { try await project(operation) }
    }

    private func commitLocked(filmID: UUID, event: CaptureSaveEvent) async throws {
        let source: URL
        let kind: CaptureKind
        switch event {
        case let .photoSaved(url): source = url; kind = .photo
        case let .movieClipSaved(url, seconds, orientation):
            source = url; kind = .movieClip(seconds: seconds, orientation: orientation)
        default: return
        }
        let film = try repository.film(id: filmID)
        if let existing = try repository.captureReceipt(filmID: filmID, captureID: source.lastPathComponent) {
            guard existing.kind == kind else { throw PersistenceError.conflictingCaptureReceipt }
            if try FileManager.default.itemExists(at: source) {
                guard try CaptureCommitJournal.hash(Data(contentsOf: source)) == existing.sourceSHA256 else {
                    throw PersistenceError.conflictingCaptureReceipt
                }
            }
            return
        }
        let operation = try await journal.prepare(film: film, access: repository.filmAccess(filmID: filmID),
            source: source, kind: kind, savedAt: CapturedMediaFiles.metadata(for: source)?.createdAt ?? Date())
        try await checkpoint(.prepared)
        try await project(operation)
    }

    private func project(_ operation: PendingCaptureCommit) async throws {
        let film = try repository.film(id: operation.filmID)
        guard film.camera == operation.camera, try repository.filmAccess(filmID: film.id) == operation.access else {
            throw PersistenceError.conflictingCaptureReceipt
        }
        if let existing = try repository.captureReceipt(filmID: film.id, captureID: operation.captureID) {
            guard existing.kind == operation.kind, existing.sequenceNumber == operation.expectedSequence,
                  existing.sourceSHA256 == operation.sourceSHA256 else { throw PersistenceError.conflictingCaptureReceipt }
            try repository.finishTrialConsumption(filmID: film.id)
            try journal.finish(operation)
            return
        }
        guard film.savedCaptureCount + 1 == operation.expectedSequence else { throw PersistenceError.conflictingCaptureReceipt }
        let bytes = try await journal.verifiedBytes(operation)
        if operation.expectedSequence == 1, case let .trial(origin) = operation.access {
            let record = try store.ensureDeviceRecord()
            // Existing Film rights include older same-iPhone empty-Film backups.
            if record.deviceID == origin, !record.isConsumed {
                try store.consume(filmID: film.id, captureID: operation.captureID, savedAt: operation.savedAt)
            }
        }
        try await checkpoint(.receiptResolved)
        switch operation.kind {
        case .photo:
            try repository.savePhotoCapture(filmID: film.id, sourceData: bytes, captureID: operation.captureID,
                savedAt: operation.savedAt, failureInjection: projectionFailure)
        case let .movieClip(seconds, orientation):
            try repository.saveMovieClip(filmID: film.id, sourceData: bytes, durationSeconds: seconds,
                orientation: orientation, captureID: operation.captureID, savedAt: operation.savedAt,
                failureInjection: projectionFailure)
        }
        try await checkpoint(.projected)
        try repository.finishTrialConsumption(filmID: film.id)
        try journal.finish(operation)
    }

    // Actor reentrancy does not serialize native decoding/recovery awaits.
    private func enter() async {
        if occupied { await withCheckedContinuation { waiters.append($0) } }
        else { occupied = true }
    }
    private func leave() {
        if waiters.isEmpty { occupied = false }
        else { waiters.removeFirst().resume() }
    }

    var queuedOperationCount: Int { waiters.count }
}

public actor TrialCaptureReceiver: CaptureSaveCommitting {
    private let filmID: UUID
    private let trial: TrialCoordinator

    init(filmID: UUID, trial: TrialCoordinator) {
        self.filmID = filmID
        self.trial = trial
    }

    public func commit(_ event: CaptureSaveEvent) async throws {
        try await trial.commit(filmID: filmID, event: event)
    }
}
