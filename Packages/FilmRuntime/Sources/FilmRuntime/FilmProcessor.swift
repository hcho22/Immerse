import AVFoundation
import FilmDomain
import FilmPersistence
import Foundation
import RenderCore
import NativeAdapters
import MediaCatalog
import Synchronization

/// Development, or a developed Movie's rebuild, that stopped as the app left the screen: stopped by
/// `FilmProcessor.suspendProcessing`, or failing while the app was away from the screen. It is thrown whatever the work
/// ended with: iOS takes an app's graphics and video work away once it leaves the screen, so a clip being written then
/// fails, as the stop reaches it or before, and that failure is the stop's, not a fault of the Film. Nothing is lost:
/// every capture and every Developed Clip already saved stays, and the next Development goes on from them.
public struct DevelopmentSuspended: Error, Equatable {
    public init() {}
}

/// A Development that made and showed its result, but did not remove the originals the person chose to remove after it:
/// their verification or removal failed. The developed Film is whole, and its originals stay in Immerse.
public struct OriginalsNotRemoved: Error {
    public let underlying: Error

    public init(underlying: Error) {
        self.underlying = underlying
    }
}

/// The system's or the Film store's report that the iPhone is full.
public enum OutOfSpace {
    /// Whether the error, or one it carries, reports a full iPhone.
    public static func reported(by error: Error) -> Bool {
        switch error {
        case PersistenceError.outOfSpace: return true
        case let NativeRenderError.writerFailed(underlying?), let NativeRenderError.invalidMovie(underlying?):
            return reported(by: underlying)
        case is NativeRenderError, is PersistenceError: return false
        default: break
        }
        let error = error as NSError
        switch (error.domain, error.code) {
        case (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError), (NSPOSIXErrorDomain, Int(ENOSPC)),
             (NSPOSIXErrorDomain, Int(EDQUOT)), (AVFoundationErrorDomain, AVError.Code.diskFull.rawValue):
            return true
        default:
            return error.underlyingErrors.contains(where: reported(by:))
        }
    }
}

public actor FilmProcessor {
    private let root: URL
    private let repository: FilmRepository
    private let developmentObserver: DevelopmentObserver?
    /// Exports are not suspendable: a write may already be in Photos and cannot be recalled.
    private struct Job {
        let task: Task<Void, Error>
        let suspendable: Bool
        /// Set when `suspendProcessing` stopped the job.
        let suspension = Suspension()
    }
    private final class Suspension {
        var requested = false
    }
    private var jobs: [UUID: Job] = [:]
    private var removing: Set<UUID> = []
    /// Whether the app is away from the screen, from `appLeftTheScreen` until `appReturnedToTheScreen`.
    private let away = Mutex(false)

    public init(root: URL, developmentObserver: DevelopmentObserver? = nil) throws {
        self.root = root
        self.repository = try FilmRepository(rootURL: root)
        self.developmentObserver = developmentObserver
    }

    public func develop(filmID: UUID) async throws {
        guard !removing.contains(filmID) else { throw PersistenceError.filmNotFound }
        if let job = jobs[filmID] { return try await outcome(of: job) }
        let root = self.root
        let observer = developmentObserver
        let job = Job(task: Task.detached { try await DevelopmentWorker.run(root: root, filmID: filmID, observer: observer) },
                      suspendable: true)
        jobs[filmID] = job
        defer { jobs[filmID] = nil }
        try await outcome(of: job)
    }

    /// Records at once, before `suspendProcessing` can reach the processor, that the app has left the screen. Until
    /// `appReturnedToTheScreen`, a Development's failure is the stop's (`DevelopmentSuspended`), whatever it was doing.
    public nonisolated func appLeftTheScreen() { away.withLock { $0 = true } }

    /// Records that the app is active on the screen again, so a Development's failure is its own once more.
    public nonisolated func appReturnedToTheScreen() { away.withLock { $0 = false } }

    /// Stops Development and Movie work before the app is suspended. Exports keep running. Each stopped job's callers
    /// get `DevelopmentSuspended`.
    public func suspendProcessing() async {
        let active = jobs.values.filter(\.suspendable)
        for job in active {
            job.suspension.requested = true
            job.task.cancel()
        }
        for job in active { _ = await job.task.result }
    }

    /// A job's outcome for its callers, with a failure that is the stop's reported as `DevelopmentSuspended`.
    private func outcome(of job: Job) async throws {
        do { try await job.task.value }
        catch let error where isTheStop(error, stopped: job.suspension.requested) { throw DevelopmentSuspended() }
    }

    /// Whether a Development's failure is the stop's: once `suspendProcessing` has stopped it (`stopped`), or arriving
    /// while the app is away from the screen. iOS takes an app's video encoder and decoder and refuses its graphics work
    /// as it leaves, so the work can fail before the stop reaches it. A full iPhone is never the stop's, and a
    /// cancellation the stop did not make is a deletion's or a discard's.
    private func isTheStop(_ error: Error, stopped: Bool) -> Bool {
        guard !OutOfSpace.reported(by: error) else { return false }
        return stopped || (!(error is CancellationError) && away.withLock { $0 })
    }

    public func discard(filmID: UUID, sequence: Int) async throws {
        guard !removing.contains(filmID) else { throw PersistenceError.operationInProgress }
        removing.insert(filmID)
        defer { removing.remove(filmID) }
        if let job = jobs[filmID] { job.task.cancel(); _ = await job.task.result }
        jobs[filmID] = nil
        let film = try repository.discardRevealedCapture(filmID: filmID, sequenceNumber: sequence)
        try removeWork(filmID: filmID)
        if film.canPlaybackDevelopedMovie {
            do { try await DevelopmentWorker.run(root: root, filmID: filmID, observer: developmentObserver) }
            catch let error where isTheStop(error, stopped: false) { throw DevelopmentSuspended() }
        }
    }

    public func deleteFilm(filmID: UUID) async throws {
        guard !removing.contains(filmID) else { throw PersistenceError.operationInProgress }
        removing.insert(filmID)
        defer { removing.remove(filmID) }
        if let job = jobs[filmID] { job.task.cancel(); _ = await job.task.result }
        jobs[filmID] = nil
        try repository.deleteFilm(filmID: filmID)
        try removeWork(filmID: filmID)
    }

    public func photo(filmID: UUID, sequence: Int, recipe: DarkroomRecipe? = nil) throws -> Data {
        let film = try repository.film(id: filmID)
        let master = try repository.revealedAsset(filmID: filmID, sequenceNumber: sequence, kind: .master)
        let selected = try recipe ?? repository.darkroomRecipe(filmID: filmID, sequence: sequence)
        return try NativePhotoRenderer.print(master: Data(contentsOf: master.url), recipe: selected, camera: film.camera,
            process: repository.photoPrintProcess(filmID: filmID))
    }

    public func saveRecipe(filmID: UUID, sequence: Int, recipe: DarkroomRecipe) throws -> Data {
        let rendered = try photo(filmID: filmID, sequence: sequence, recipe: recipe)
        try repository.saveDarkroomRecipe(filmID: filmID, sequence: sequence, recipe: recipe)
        return rendered
    }

    public func cleanupSources(filmID: UUID) async throws {
        try await DevelopmentWorker.cleanup(root: root, filmID: filmID)
    }

    /// Changes a developed Movie's sound choice without changing its Developed Clips or their captured audio.
    public func selectMovieSound(
        filmID: UUID, choice: MovieSoundChoice, assetID: String?, catalog: BundleMediaCatalog?
    ) async throws {
        guard (choice == .soundtrack) == (assetID != nil) else { throw PersistenceError.invalidMedia }
        guard !removing.contains(filmID), jobs[filmID] == nil else { throw PersistenceError.operationInProgress }
        let root = self.root
        let observer = developmentObserver
        let job = Task.detached {
            let asset: VerifiedCatalogAsset?
            if let assetID {
                guard let catalog else { throw PersistenceError.invalidMedia }
                asset = try catalog.resolve(id: assetID)
            } else { asset = nil }
            let verification: VerifiedMedia?
            if let asset { verification = try await VerifiedMedia.audio(at: asset.url) }
            else { verification = nil }
            try Task.checkCancellation()
            let repository = try FilmRepository(rootURL: root)
            try repository.selectMovieSoundChoice(filmID: filmID, choice: choice, asset: asset, verification: verification)
            try Task.checkCancellation()
            try await DevelopmentWorker.run(root: root, filmID: filmID, observer: observer)
        }
        let movieJob = Job(task: job, suspendable: true)
        jobs[filmID] = movieJob
        defer { jobs[filmID] = nil }
        try await outcome(of: movieJob)
    }

    /// Photos permission is settled before the export starts, so its prompt never interrupts a write.
    public func export<Authorizer: PhotoLibraryAuthorizing, Writer: PhotoLibraryWriting>(
        filmID: UUID, sequences: [Int], originals: Bool,
        coordinator: PhotoExportCoordinator<Authorizer, Writer>
    ) async throws {
        switch await coordinator.resolveAccess() {
        case .authorized, .limited: break
        case .notDetermined: throw FilmExportError.needsPermission
        case .denied, .restricted: throw FilmExportError.permissionDenied
        }
        guard !removing.contains(filmID), jobs[filmID] == nil else { throw PersistenceError.operationInProgress }
        let root = self.root
        let job = Task.detached {
            try await FilmExportWorker.export(root: root, filmID: filmID, sequences: sequences,
                originals: originals, coordinator: coordinator)
        }
        jobs[filmID] = Job(task: job, suspendable: false)
        defer { jobs[filmID] = nil }
        try await job.value
    }

    private func removeWork(filmID: UUID) throws {
        try FileManager.default.removeItemIfPresent(at: root.appendingPathComponent("Work/\(filmID)"))
    }
}

/// One capture developed from its source, as Development renders it: the Film's Camera, Film Stock and Movie orientation,
/// and the capture's assigned seed in its treatment version. Development is its one caller in Release; a Debug build's
/// preview of a saved capture calls it too (`PreviewDevelopment`), so the preview is what Development will make.
enum CaptureDevelopment {
    static func master(source: URL, film: Film, treatment: TreatmentAssignment, run: DevelopmentRun) throws -> Data {
        try NativePhotoRenderer.develop(source: source, camera: film.camera, seed: treatment.seed, filmStock: film.filmStock,
                                        treatmentVersion: run.treatmentVersion(of: treatment))
    }

    static func clip(source: URL, destination: URL, film: Film, treatment: TreatmentAssignment,
                     run: DevelopmentRun) async throws {
        guard let orientation = film.movieOrientation else { throw FilmDomainError.wrongCameraMedium }
        try await NativeMovieRenderer.developClip(source: source, destination: destination, camera: film.camera,
            filmStock: film.filmStock, seed: treatment.seed, orientation: orientation,
            treatmentVersion: run.treatmentVersion(of: treatment))
    }
}

enum DevelopmentWorker {
    static func run(root: URL, filmID: UUID, observer: DevelopmentObserver? = nil) async throws {
        let repository = try FilmRepository(rootURL: root)
        if let observer {
            try await observer(filmID, .beforeBegin)
            try Task.checkCancellation()
        }
        let run = try repository.beginDevelopment(filmID: filmID)
        if let observer {
            try await observer(filmID, .afterAssignments)
            try Task.checkCancellation()
        }
        let film = try repository.film(id: filmID)
        let audioSelection = try repository.movieAudioSelection(filmID: filmID)
        var work = root.appendingPathComponent("Work/\(filmID)/\(UUID())")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try work.setResourceValues(resources)
        defer { try? FileManager.default.removeItem(at: work) }
        var evidence: [VerifiedMedia] = []
        var clips: [URL] = []
        for capture in film.captures where !capture.isDiscarded {
            try Task.checkCancellation()
            guard let treatment = run.assignments[capture.sequenceNumber] else { throw PersistenceError.treatmentConflict }
            let kind: StoredAsset.Kind = film.camera.medium == .photo ? .master : .clip
            if try repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: kind) == nil {
                guard run.rendersAssignedTreatment(treatment) else { throw PersistenceError.treatmentConflict }
                guard let source = try repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: .source) else {
                    throw PersistenceError.captureNotFound
                }
                if kind == .master {
                    let data = try CaptureDevelopment.master(source: source.url, film: film, treatment: treatment, run: run)
                    if let observer {
                        try await observer(filmID, .afterRendering(sequence: capture.sequenceNumber))
                        try Task.checkCancellation()
                    }
                    try Task.checkCancellation()
                    try repository.writeDevelopedMaster(filmID: filmID, sequenceNumber: capture.sequenceNumber, data: data)
                } else {
                    let output = work.appendingPathComponent("\(capture.sequenceNumber).mov")
                    try await CaptureDevelopment.clip(source: source.url, destination: output, film: film, treatment: treatment,
                                                      run: run)
                    if let observer {
                        try await observer(filmID, .afterRendering(sequence: capture.sequenceNumber))
                        try Task.checkCancellation()
                    }
                    try Task.checkCancellation()
                    _ = try await VerifiedMedia.movie(at: output, allowsAudio: film.camera.recordsLiveSound == true)
                    try repository.writeDevelopedClip(filmID: filmID, sequenceNumber: capture.sequenceNumber, data: Data(contentsOf: output))
                }
                if let observer {
                    try await observer(filmID, .afterPersistence(sequence: capture.sequenceNumber))
                    try Task.checkCancellation()
                }
            }
            guard let asset = try repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: kind) else {
                throw PersistenceError.missingVerifiedMaster
            }
            let verification: VerifiedMedia
            if kind == .master { verification = try VerifiedMedia.photo(at: asset.url) }
            else {
                verification = try await VerifiedMedia.movie(at: asset.url, allowsAudio: film.camera.recordsLiveSound == true)
                clips.append(asset.url)
            }
            evidence.append(verification)
            if film.camera.revealRule == .instantPerExposure {
                if let observer {
                    try await observer(filmID, .beforeRevealOrCleanup(.instantReveal(sequence: capture.sequenceNumber)))
                    try Task.checkCancellation()
                }
                try repository.finishVerifiedDevelopment(filmID: filmID, verifiedMedia: [verification], instantSequence: capture.sequenceNumber)
            }
        }
        if film.camera.medium == .movie {
            guard !clips.isEmpty else { return }
            let output = work.appendingPathComponent("assembled.mov")
            let soundtrack = try repository.retainedSoundtrack(filmID: filmID)
            if let soundtrack { _ = try await VerifiedMedia.audio(at: soundtrack.url) }
            let soundChoice = try repository.movieSoundChoice(filmID: filmID)
            guard soundChoice != .recordedSound || film.camera.recordsLiveSound == true else { throw PersistenceError.invalidMedia }
            let includeRecordedSound = soundChoice == .recordedSound
            let selectedSoundtrack = soundChoice == .soundtrack
            try await NativeMovieRenderer.assemble(clips: clips, destination: output, soundtrack: soundtrack?.url,
                                                   includeRecordedSound: includeRecordedSound)
            let verification = try await VerifiedMedia.movie(at: output,
                allowsAudio: selectedSoundtrack || includeRecordedSound)
            try Task.checkCancellation()
            try repository.writeAssembledMovie(filmID: filmID, data: Data(contentsOf: output),
                clipSequenceNumbers: film.captures.filter { !$0.isDiscarded }.map(\.sequenceNumber), verification: verification,
                soundtrackRevision: audioSelection?.revision)
            evidence.append(verification)
        }
        if film.camera.revealRule != .instantPerExposure {
            if let observer {
                try await observer(filmID, .beforeRevealOrCleanup(.filmReveal))
                try Task.checkCancellation()
            }
            try repository.finishVerifiedDevelopment(filmID: filmID, verifiedMedia: evidence)
        }
        if let observer {
            try await observer(filmID, .beforeRevealOrCleanup(.sourceCleanup))
            try Task.checkCancellation()
        }
        do { try await cleanup(root: root, filmID: filmID) }
        catch let error where !(error is CancellationError) { throw OriginalsNotRemoved(underlying: error) }
    }

    static func cleanup(root: URL, filmID: UUID) async throws {
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.film(id: filmID)
        for capture in film.captures where capture.revealState == .revealed {
            try Task.checkCancellation()
            guard let choice = try repository.originalDisposition(filmID: filmID, sequenceNumber: capture.sequenceNumber),
                  choice != .exportRequested,
                  try repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: .source) != nil else { continue }
            var evidence: [VerifiedMedia] = []
            let kinds: [(Int, StoredAsset.Kind)] = film.camera.medium == .photo
                ? [(capture.sequenceNumber, .master)] : [(capture.sequenceNumber, .clip), (0, .movie)]
            for (sequence, kind) in kinds {
                let asset = try repository.revealedAsset(filmID: filmID, sequenceNumber: sequence, kind: kind)
                if kind == .master { evidence.append(try VerifiedMedia.photo(at: asset.url)) }
                else {
                    let soundChoice = try repository.movieSoundChoice(filmID: filmID)
                    let allowsAudio = kind == .movie
                        ? soundChoice != .silent
                        : film.camera.recordsLiveSound == true
                    evidence.append(try await VerifiedMedia.movie(at: asset.url, allowsAudio: allowsAudio))
                }
            }
            try repository.cleanupSourceAfterVerifiedMaster(filmID: filmID, sequenceNumber: capture.sequenceNumber, verifiedMedia: evidence)
        }
    }
}
