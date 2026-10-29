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

/// Keeps the iPhone's screen on while a Development runs, so its auto-lock cannot stop it: Development stops when Immerse
/// leaves the screen (`FilmProcessor.suspendProcessing`), and a Movie's Development can outlast the auto-lock. The
/// screen may sleep again once the last Development running ends, however it ends. Nothing else in Immerse holds the
/// screen on.
@MainActor
final class DevelopmentScreenAwake {
    private var running = 0
    private let hold: @MainActor (Bool) -> Void

    /// - Parameter hold: holds the screen on, or lets it sleep; tests record it.
    init(hold: @escaping @MainActor (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }) {
        self.hold = hold
    }

    /// Runs one Development with the screen held on.
    func during<T>(_ development: () async throws -> T) async rethrows -> T {
        running += 1
        if running == 1 { hold(true) }
        defer {
            running -= 1
            if running == 0 { hold(false) }
        }
        return try await development()
    }
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
    /// Whether this iPhone is low on free space, for the warning before a step that needs space.
    let storage: LowStorageCheck
    let screenAwake: DevelopmentScreenAwake
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
    /// Off for directly constructed Journals; the app's Journal reads the persisted switch.
    @ObservationIgnored var developedPreviews: DevelopedPreviews
    #endif

    init(root: URL, trialStore: any DeviceTrialStoring = KeychainDeviceTrialStore(),
         cameraAuthorizer: any CapturePermissionAuthorizing = AVFoundationCaptureAuthorizer(),
         subscriptions: SubscriptionConfiguration? = SubscriptionController.bundleConfiguration(),
         freeSpace: (any FreeSpaceReading)? = nil, screenAwake: DevelopmentScreenAwake? = nil,
         developmentObserver: DevelopmentObserver? = nil) throws {
        self.cameraAuthorizer = cameraAuthorizer
        self.screenAwake = screenAwake ?? DevelopmentScreenAwake()
        #if DEBUG
        developedPreviews = DevelopedPreviews(root: root, defaults: nil)
        #endif
        // The volume that holds the Films, unless a test sets the reading.
        storage = LowStorageCheck(reader: freeSpace ?? VolumeFreeSpaceReader(url: root))
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
        // Only isolated tests observe Development; the app installs no observer.
        processor = try FilmProcessor(root: root, developmentObserver: developmentObserver)
        trial = try TrialCoordinator(root: root, store: trialStore)
        try repository.recover()
        reloadFilms()
    }

    func refresh() {
        reloadFilms()
        Task { await storage.refresh() }
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

    func setFocusSetting(_ setting: FilmFocusSetting, filmID: UUID) throws -> Film {
        guard !busyFilms.contains(filmID), !hiddenFilms.contains(filmID), film(filmID) != nil else {
            throw JournalError.operationInProgress
        }
        return try repository.setFocusSetting(filmID: filmID, to: setting)
    }

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

    func load(camera: CameraPackage, title: String, orientation: MovieOrientation, filmStock: FilmStock? = nil) async throws -> Film {
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
                orientation: camera.medium == .movie ? orientation : nil,
                filmStock: filmStock, subscription: access)
        } catch let EntitlementDenial.currentDeviceTrialAlreadyInProgress(id) {
            throw JournalError.trialInProgress(id)
        } catch EntitlementDenial.currentDeviceTrialConsumed {
            throw billing.configured ? JournalError.subscriptionRequired : JournalError.subscriptionUnavailable
        }
        refresh()
        return film
    }

    /// - Parameter atTheCamera: whether a failure shows at the camera, away from the Film's screen.
    func develop(_ id: UUID, atTheCamera: Bool = false) async throws {
        guard !busyFilms.contains(id), !hiddenFilms.contains(id), !hasPendingSave(id) else { throw JournalError.operationInProgress }
        busyFilms.insert(id)
        defer { busyFilms.remove(id); refresh(); mediaRevision = UUID() }
        #if DEBUG
        developedPreviews.clear(filmID: id)
        #endif
        try await developing(id, atTheCamera: atTheCamera) { try await processor.develop(filmID: id) }
    }

    /// Runs a Development, or a developed Movie's rebuild, with the screen held on, and reports its failure as the
    /// Development's (`developmentFailure`). `retry` names the button that tries it again where the message shows, when
    /// that is not the Film's screen.
    private func developing(_ id: UUID, retry: String? = nil, atTheCamera: Bool = false,
                            _ development: () async throws -> Void) async throws {
        do { try await screenAwake.during(development) }
        catch is CancellationError { throw CancellationError() }
        catch { throw developmentFailure(error, filmID: id, retry: retry, atTheCamera: atTheCamera) }
    }

    /// A Development's failure as the Film it left reads, read again after it: `DevelopmentFailure` with the button that
    /// develops the Film again, `retry` or else the Film screen's. Once the Film shows its developed result nothing it
    /// needs was lost, so a stop there shows nothing.
    private func developmentFailure(_ error: Error, filmID id: UUID, retry: String? = nil,
                                    atTheCamera: Bool = false) -> Error {
        let film = try? repository.film(id: id)
        let screenRetry = film.flatMap(developmentRetry)
        if error is DevelopmentSuspended, film != nil, screenRetry == nil { return CancellationError() }
        return DevelopmentFailure(underlying: error, retry: retry ?? screenRetry, atTheCamera: atTheCamera)
    }

    /// The Film screen's button that develops `film` again as it stands: Develop Film, Resume Development, or Rebuild
    /// Movie for a developed Movie without its Movie. Nil once the Film shows its developed result.
    private func developmentRetry(_ film: Film) -> String? {
        if film.canStartDevelopment { return "Develop Film" }
        if film.offersResumeDevelopment { return "Resume Development" }
        if film.canPlaybackDevelopedMovie,
           (try? repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)) == nil {
            return "Rebuild Movie"
        }
        return nil
    }

    /// What the app does as its scene comes and goes. The app and the screen-test harness both forward the scene's
    /// phase here, so the harness's Films stop and carry on as the app's do.
    func sceneChanged(to phase: ScenePhase) {
        switch phase {
        case .active:
            processor.appReturnedToTheScreen()
            refresh()
            #if DEBUG
            developedPreviews.resume()
            #endif
        case .background:
            processor.appLeftTheScreen()
            capture.suspend()
            Task { await processor.suspendProcessing() }
            #if DEBUG
            developedPreviews.suspend()
            #endif
        default:
            // Control Center, a call or a permission prompt only pauses the camera.
            capture.pauseForInactiveScene()
        }
    }

    /// Instant prints develop as each save lands. A print saved while another operation owns
    /// or is removing the Film stays sealed and is offered through Resume Development.
    func developSavedPrint(_ id: UUID, failure: @escaping @MainActor (String) -> Void) {
        perform({ [self] in
            guard film(id) != nil, !busyFilms.contains(id), !hiddenFilms.contains(id), !hasPendingSave(id) else { return }
            try await develop(id, atTheCamera: true)
        }, failure: failure)
    }

    func chooseOriginals(_ id: UUID, sequences: [Int], export: Bool) throws {
        for sequence in sequences where try repository.originalDisposition(filmID: id, sequenceNumber: sequence) == nil {
            try repository.chooseOriginalExport(filmID: id, sequenceNumber: sequence, export: export)
        }
    }

    /// The revealed prints of an Instant Film; empty for every other Film.
    func revealedInstantPrints(_ id: UUID) -> Set<Int> {
        guard let film = film(id), film.camera.revealRule == .instantPerExposure else { return [] }
        return Set(film.captures.filter { $0.revealState == .revealed && !$0.isDiscarded }.map(\.sequenceNumber))
    }

    /// The prints among `prints` whose original the Instant still has to ask about: revealed, kept and with no choice
    /// recorded. A sealed print is never among them, so no choice reaches a frame that is not revealed yet.
    func printsAwaitingOriginalChoice(_ id: UUID, among prints: Set<Int>) -> [Int] {
        revealedInstantPrints(id).intersection(prints).sorted().filter {
            (try? repository.originalDisposition(filmID: id, sequenceNumber: $0) == nil) == true
        }
    }

    /// The prints the Instant's one question at the end of its pack covers (DEV-12), which the shooting screen asks as
    /// its last print closes: once every exposure is used and every kept print is revealed, each revealed print whose
    /// original is still undecided. While a print is still sealed there is none. A print revealed at the camera closes
    /// there and the question follows it; a last print whose Development the app stopped in the background is revealed
    /// elsewhere, so its question is missed and does not come back by itself (the captain's "C"), and the Film screen's
    /// Originals button remains.
    func packEndOriginalQuestion(_ id: UUID) -> [Int] {
        guard let film = film(id), film.camera.id == .instant1970s, film.remainingExposures == 0,
              !film.captures.contains(where: { $0.revealState == .sealed }) else { return [] }
        return printsAwaitingOriginalChoice(id, among: revealedInstantPrints(id))
    }

    func selectMovieSound(_ id: UUID, choice: MovieSoundChoice, assetID: String?) async throws {
        guard (choice == .soundtrack) == (assetID != nil), !busyFilms.contains(id), !hiddenFilms.contains(id) else {
            throw JournalError.operationInProgress
        }
        guard assetID == nil || mediaCatalog != nil else { throw PersistenceError.invalidMedia }
        busyFilms.insert(id)
        mediaRevision = UUID()
        defer { busyFilms.remove(id); refresh(); mediaRevision = UUID() }
        try await developing(id, retry: "Apply sound choice") {
            try await processor.selectMovieSound(filmID: id, choice: choice, assetID: assetID, catalog: mediaCatalog)
        }
    }

    func remove(_ id: UUID, sequence: Int? = nil) async throws {
        guard !hiddenFilms.contains(id) else { throw JournalError.operationInProgress }
        hiddenFilms.insert(id)
        mediaRevision = UUID()
        // Clear every app-owned visible image/player before acknowledging removal.
        defer { refresh(); hiddenFilms.remove(id); mediaRevision = UUID() }
        if let sequence {
            // Discard tombstones only this revealed capture, including any staged copy of it.
            // Another capture's unfinished save stays staged for its retry. A Movie's discard develops its Movie again.
            do { try await screenAwake.during { try await processor.discard(filmID: id, sequence: sequence) } }
            catch let error where discardLeftAMovieToRebuild(id, sequence: sequence) {
                throw developmentFailure(error, filmID: id)
            }
        } else {
            #if DEBUG
            developedPreviews.clear(filmID: id)
            defer { developedPreviews.clear(filmID: id) }
            #endif
            try await capture.cancelForPrivacy(filmID: id)
            try await trial.deleteFilm(filmID: id, processor: processor)
        }
    }

    /// Whether the discard of `sequence` is recorded and the Film has a Movie to make again: the discard develops that
    /// Movie again (`FilmProcessor.discard`), so its failure is that Development's.
    private func discardLeftAMovieToRebuild(_ id: UUID, sequence: Int) -> Bool {
        guard let film = try? repository.film(id: id) else { return false }
        return film.canPlaybackDevelopedMovie && film.captures.contains { $0.sequenceNumber == sequence && $0.isDiscarded }
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
        // The Journal alert cannot appear over the camera, and would otherwise wait until the camera closes.
        guard !capture.presented else { return }
        alert = JournalAlert(title: "Saved to Photos", message: originals ? "The selected originals were saved." : "The revealed developed result was saved.")
    }
}
