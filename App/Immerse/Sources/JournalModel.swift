import AVFoundation
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import MediaCatalog
import NativeAdapters
import Observation
import RenderCore
import SwiftUI

struct JournalAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func failure(_ message: String) -> JournalAlert { JournalAlert(title: "Could not finish", message: message) }
}

enum JournalError: Error {
    case cameraDenied, subscriptionUnavailable, subscriptionRequired, trialInProgress(UUID), operationInProgress
}

@MainActor @Observable
final class JournalModel {
    let repository: FilmRepository
    let processor: FilmProcessor
    let trial: TrialCoordinator
    let capture: CaptureController
    private let cameraAuthorizer: any CapturePermissionAuthorizing
    let billing: SubscriptionController
    let mediaCatalog: BundleMediaCatalog?
    let catalogError: String?
    var films: [Film] = []
    var trialState: DeviceTrialState?
    var trialError: String?
    var alert: JournalAlert?
    var busyFilms: Set<UUID> = []
    var hiddenFilms: Set<UUID> = []
    var mediaRevision = UUID()
    private(set) var pendingFilms: Set<UUID> = []
    private(set) var initialRecoveryPending = true
    #if DEBUG
    /// Off for directly constructed Journals; the app's Journal reads the persisted switch.
    @ObservationIgnored var testingUnlock = TestingUnlock(defaults: nil)
    #endif

    init(root: URL, trialStore: any DeviceTrialStoring = KeychainDeviceTrialStore(),
         cameraAuthorizer: any CapturePermissionAuthorizing = AVFoundationCaptureAuthorizer(),
         subscriptions: SubscriptionConfiguration? = SubscriptionController.bundleConfiguration()) throws {
        self.cameraAuthorizer = cameraAuthorizer
        billing = SubscriptionController(configuration: subscriptions)
        capture = CaptureController(authorizer: cameraAuthorizer)
        do {
            guard let resources = Bundle.main.resourceURL,
                  let manifest = Bundle.main.url(forResource: "MediaCatalog", withExtension: "json") else {
                throw MediaCatalogError.invalidManifest
            }
            mediaCatalog = try BundleMediaCatalog(rootURL: resources, manifestData: Data(contentsOf: manifest))
            catalogError = nil
        } catch {
            mediaCatalog = nil
            catalogError = ["Bundled media is unavailable.", FailureCopy.systemDetail(for: error)].compactMap { $0 }.joined(separator: " ")
        }
        repository = try FilmRepository(rootURL: root)
        processor = try FilmProcessor(root: root)
        trial = try TrialCoordinator(root: root, store: trialStore)
        try repository.recover()
        reloadFilms()
    }

    func refresh() {
        reloadFilms()
        Task {
            await billing.refresh()
            do { trialState = try await trial.state(); trialError = nil }
            catch { trialState = nil; trialError = FailureCopy.systemDetail(for: error) ?? "Reopen Immerse to check again." }
            reloadFilms()
        }
    }

    private func reloadFilms() {
        do {
            films = try repository.allFilms()
            var pending: Set<UUID> = []
            // The Trial owner deletes Films off the main actor, so a listed Film can be gone by its check.
            for film in films {
                do { if try repository.hasPendingCapture(filmID: film.id) { pending.insert(film.id) } }
                catch PersistenceError.filmNotFound { films.removeAll { $0.id == film.id } }
            }
            pendingFilms = pending
        } catch {
            pendingFilms = Set(films.map(\.id))
            report(error)
        }
    }

    func hasPendingSave(_ id: UUID) -> Bool { initialRecoveryPending || pendingFilms.contains(id) }

    func recoverAtLaunch() async {
        guard initialRecoveryPending else { return }
        do { try await trial.recoverSavedCaptures() }
        catch { report(error) }
        initialRecoveryPending = false
        refresh()
    }

    func recoverCapture(_ id: UUID) async throws {
        guard !busyFilms.contains(id), !hiddenFilms.contains(id) else { throw JournalError.operationInProgress }
        busyFilms.insert(id)
        defer { busyFilms.remove(id); refresh() }
        try await capture.finishSaves(filmID: id)
        try await trial.recoverSavedCaptures(filmID: id)
    }

    func film(_ id: UUID) -> Film? { films.first { $0.id == id } }

    func report(_ error: Error) {
        guard let message = FailureCopy.message(for: error) else { return }
        alert = .failure(message)
    }

    /// Runs an operation and reports its failure in the Journal alert. Inside a sheet or a
    /// full-screen cover, where that alert cannot appear, pass `failure` to show it there instead.
    func perform(_ operation: @escaping @MainActor () async throws -> Void,
                 failure: (@MainActor (String) -> Void)? = nil) {
        Task {
            do { try await operation(); refresh() }
            catch {
                refresh()
                guard let failure else { return report(error) }
                if let message = FailureCopy.message(for: error) { failure(message) }
            }
        }
    }

    func load(camera: CameraPackage, title: String, orientation: MovieOrientation) async throws -> Film {
        guard !initialRecoveryPending else { throw JournalError.operationInProgress }
        // Permission is checked before any Film or Trial activation is written.
        let allowed = cameraAuthorizer.authorizationStatus() == .authorized
            ? true : await cameraAuthorizer.requestAccess()
        guard allowed else { throw JournalError.cameraDenied }
        await billing.refresh()
        #if DEBUG
        let access = testingUnlock.loadAccess(billing.access)
        #else
        let access = billing.access
        #endif
        let film: Film
        do {
            film = try await trial.load(camera: camera, title: title,
                orientation: camera.medium == .movie ? orientation : nil, subscription: access)
        } catch let EntitlementDenial.currentDeviceTrialAlreadyInProgress(id) {
            throw JournalError.trialInProgress(id)
        } catch EntitlementDenial.currentDeviceTrialConsumed {
            throw billing.configured ? JournalError.subscriptionRequired : JournalError.subscriptionUnavailable
        }
        refresh()
        return film
    }

    func develop(_ id: UUID) async throws {
        guard !busyFilms.contains(id), !hiddenFilms.contains(id), !hasPendingSave(id) else { throw JournalError.operationInProgress }
        busyFilms.insert(id)
        defer { busyFilms.remove(id); refresh(); mediaRevision = UUID() }
        try await processor.develop(filmID: id)
    }

    /// Instant prints develop as each save lands. A print saved while another operation owns
    /// or is removing the Film stays sealed and is offered through Resume Development.
    func developSavedPrint(_ id: UUID, failure: @escaping @MainActor (String) -> Void) {
        perform({ [self] in
            guard film(id) != nil, !busyFilms.contains(id), !hiddenFilms.contains(id), !hasPendingSave(id) else { return }
            try await develop(id)
        }, failure: failure)
    }

    func chooseOriginals(_ id: UUID, sequences: [Int], export: Bool) throws {
        for sequence in sequences where try repository.originalDisposition(filmID: id, sequenceNumber: sequence) == nil {
            try repository.chooseOriginalExport(filmID: id, sequenceNumber: sequence, export: export)
        }
    }

    func selectSoundtrack(_ id: UUID, assetID: String?) async throws {
        guard let mediaCatalog, !busyFilms.contains(id), !hiddenFilms.contains(id) else {
            throw JournalError.operationInProgress
        }
        busyFilms.insert(id)
        mediaRevision = UUID()
        defer { busyFilms.remove(id); refresh(); mediaRevision = UUID() }
        try await processor.selectSoundtrack(filmID: id, assetID: assetID, catalog: mediaCatalog)
    }

    func remove(_ id: UUID, sequence: Int? = nil) async throws {
        guard !hiddenFilms.contains(id) else { throw JournalError.operationInProgress }
        hiddenFilms.insert(id)
        mediaRevision = UUID()
        // Clear every app-owned visible image/player before acknowledging removal.
        defer { refresh(); hiddenFilms.remove(id); mediaRevision = UUID() }
        if let sequence {
            // Discard tombstones only this revealed capture, including any staged copy of it.
            // Another capture's unfinished save stays staged for its retry.
            try await processor.discard(filmID: id, sequence: sequence)
        } else {
            try await capture.cancelForPrivacy(filmID: id)
            try await trial.deleteFilm(filmID: id, processor: processor)
        }
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
