import AVFoundation
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import NativeAdapters
import Observation
import RenderCore
import SwiftUI

struct JournalAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum JournalError: Error {
    case cameraDenied, subscriptionUnavailable, subscriptionRequired, trialInProgress(UUID), operationInProgress
}

@MainActor @Observable
final class JournalModel {
    let repository: FilmRepository
    let processor: FilmProcessor
    let trial: TrialCoordinator
    let capture = CaptureController()
    let billing = SubscriptionController()
    var films: [Film] = []
    var trialState: DeviceTrialState?
    var trialError: String?
    var alert: JournalAlert?
    var busyFilms: Set<UUID> = []
    var hiddenFilms: Set<UUID> = []
    var mediaRevision = UUID()

    init(root: URL) throws {
        repository = try FilmRepository(rootURL: root)
        processor = try FilmProcessor(root: root)
        trial = try TrialCoordinator(root: root)
        try repository.recover()
        refresh()
    }

    func refresh() {
        do { films = try repository.allFilms() }
        catch { report(error) }
        Task {
            await billing.refresh()
            do { trialState = try await trial.state(); trialError = nil }
            catch { trialState = nil; trialError = error.localizedDescription }
        }
    }

    func film(_ id: UUID) -> Film? { films.first { $0.id == id } }

    func report(_ error: Error) {
        let message: String
        switch error {
        case JournalError.cameraDenied:
            message = "Camera access is off. Allow Immerse in iPhone Settings. No new Film was loaded."
        case JournalError.subscriptionUnavailable:
            message = "Subscriptions are not available in this build. Your existing Films remain usable."
        case JournalError.subscriptionRequired:
            message = "This iPhone's Trial is used. An active subscription is required to load another Film. Your existing Films remain usable."
        case JournalError.trialInProgress:
            message = "This iPhone already has an unused Trial Film. Open it in your Journal, or delete that empty Film before loading another."
        case PersistenceError.capacityChangedSinceConfirmation:
            message = "A capture finished saving while confirmation was open. The Film is still open. Check the updated remaining capacity and confirm again."
        case is CancellationError: return
        default:
            message = "The operation did not finish. Saved captures remain private; retry after checking available storage. \(error.localizedDescription)"
        }
        alert = JournalAlert(title: "Could not finish", message: message)
    }

    func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            do { try await operation(); refresh() }
            catch { refresh(); report(error) }
        }
    }

    func load(camera: CameraPackage, title: String, orientation: MovieOrientation) async throws -> Film {
        // Permission is checked before any Film or Trial activation is written.
        let authorizer = AVFoundationCaptureAuthorizer()
        let allowed = authorizer.authorizationStatus() == .authorized
            ? true : await authorizer.requestAccess()
        guard allowed else { throw JournalError.cameraDenied }
        await billing.refresh()
        if billing.access == .active {
            let film = try repository.createFilm(camera: camera, title: title,
                movieOrientation: camera.medium == .movie ? orientation : nil, access: .subscription)
            refresh()
            return film
        }
        switch try await trial.state() {
        case .unused: break
        case let .emptyFilmInProgress(id): throw JournalError.trialInProgress(id)
        case .consumed: throw billing.configured ? JournalError.subscriptionRequired : JournalError.subscriptionUnavailable
        }
        let film = try await trial.start(camera: camera, title: title,
                                        orientation: camera.medium == .movie ? orientation : nil)
        refresh()
        return film
    }

    func develop(_ id: UUID) async throws {
        guard !busyFilms.contains(id), !hiddenFilms.contains(id) else { throw JournalError.operationInProgress }
        busyFilms.insert(id)
        defer { busyFilms.remove(id); refresh(); mediaRevision = UUID() }
        try await processor.develop(filmID: id)
    }

    func chooseOriginals(_ id: UUID, sequences: [Int], export: Bool) throws {
        for sequence in sequences where try repository.originalDisposition(filmID: id, sequenceNumber: sequence) == nil {
            try repository.chooseOriginalExport(filmID: id, sequenceNumber: sequence, export: export)
        }
    }

    func remove(_ id: UUID, sequence: Int? = nil) async throws {
        hiddenFilms.insert(id)
        mediaRevision = UUID()
        // Clear every app-owned visible image/player before acknowledging removal.
        defer { refresh(); hiddenFilms.remove(id); mediaRevision = UUID() }
        try await capture.cancelForPrivacy(filmID: id)
        if let sequence { try await processor.discard(filmID: id, sequence: sequence) }
        else { try await processor.deleteFilm(filmID: id) }
    }

    func export(_ id: UUID, originals: Bool) async throws {
        guard let film = film(id), !busyFilms.contains(id), !hiddenFilms.contains(id) else {
            throw JournalError.operationInProgress
        }
        busyFilms.insert(id)
        defer { busyFilms.remove(id) }
        let sequences = try film.captures.filter {
            guard $0.revealState == .revealed else { return false }
            if !originals { return true }
            return try repository.originalDisposition(filmID: id, sequenceNumber: $0.sequenceNumber) == .exportRequested
        }.map(\.sequenceNumber)
        guard !sequences.isEmpty else { throw PersistenceError.captureNotFound }
        let coordinator = PhotoExportCoordinator(authorizer: PhotoKitAuthorizer(), writer: PhotoKitWriter(),
                                                promptPolicy: .requestAtCaptureStart)
        try await processor.export(filmID: id, sequences: sequences, originals: originals, coordinator: coordinator)
        alert = JournalAlert(title: "Saved to Photos", message: originals ? "The selected originals were saved." : "The revealed developed result was saved.")
    }
}
