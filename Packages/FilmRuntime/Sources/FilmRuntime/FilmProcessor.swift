import FilmDomain
import FilmPersistence
import Foundation
import RenderCore
import NativeAdapters
import MediaCatalog

public actor FilmProcessor {
    private let root: URL
    private let repository: FilmRepository
    private let developmentObserver: DevelopmentObserver?
    private var jobs: [UUID: Task<Void, Error>] = [:]
    private var removing: Set<UUID> = []

    public init(root: URL, developmentObserver: DevelopmentObserver? = nil) throws {
        self.root = root
        self.repository = try FilmRepository(rootURL: root)
        self.developmentObserver = developmentObserver
    }

    public func develop(filmID: UUID) async throws {
        guard !removing.contains(filmID) else { throw PersistenceError.filmNotFound }
        if let job = jobs[filmID] { return try await job.value }
        let root = self.root
        let observer = developmentObserver
        let job = Task.detached { try await DevelopmentWorker.run(root: root, filmID: filmID, observer: observer) }
        jobs[filmID] = job
        defer { jobs[filmID] = nil }
        try await job.value
    }

    public func suspendProcessing() async {
        let active = Array(jobs.values)
        for task in active { task.cancel() }
        for task in active { _ = await task.result }
    }

    public func discard(filmID: UUID, sequence: Int) async throws {
        guard !removing.contains(filmID) else { throw PersistenceError.operationInProgress }
        removing.insert(filmID)
        defer { removing.remove(filmID) }
        if let job = jobs[filmID] { job.cancel(); _ = await job.result }
        jobs[filmID] = nil
        let film = try repository.discardRevealedCapture(filmID: filmID, sequenceNumber: sequence)
        try removeWork(filmID: filmID)
        if film.canPlaybackDevelopedMovie {
            try await DevelopmentWorker.run(root: root, filmID: filmID, observer: developmentObserver)
        }
    }

    public func deleteFilm(filmID: UUID) async throws {
        guard !removing.contains(filmID) else { throw PersistenceError.operationInProgress }
        removing.insert(filmID)
        defer { removing.remove(filmID) }
        if let job = jobs[filmID] { job.cancel(); _ = await job.result }
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

    public func selectSoundtrack(filmID: UUID, assetID: String?, catalog: BundleMediaCatalog) async throws {
        guard !removing.contains(filmID), jobs[filmID] == nil else { throw PersistenceError.operationInProgress }
        guard let policy = catalog.manifest.soundtrackReselection else { throw MediaCatalogError.invalidManifest }
        let root = self.root
        let observer = developmentObserver
        let job = Task.detached {
            let asset = try assetID.map { try catalog.resolve(id: $0) }
            let verification: VerifiedMedia?
            if let asset { verification = try await VerifiedMedia.audio(at: asset.url) }
            else { verification = nil }
            try Task.checkCancellation()
            let repository = try FilmRepository(rootURL: root)
            try repository.selectMovieSoundtrack(filmID: filmID, asset: asset, verification: verification,
                                                reselectionPolicy: policy)
            try Task.checkCancellation()
            try await DevelopmentWorker.run(root: root, filmID: filmID, observer: observer)
        }
        jobs[filmID] = job
        defer { jobs[filmID] = nil }
        try await job.value
    }

    public func export<Authorizer: PhotoLibraryAuthorizing, Writer: PhotoLibraryWriting>(
        filmID: UUID, sequences: [Int], originals: Bool,
        coordinator: PhotoExportCoordinator<Authorizer, Writer>
    ) async throws {
        guard !removing.contains(filmID), jobs[filmID] == nil else { throw PersistenceError.operationInProgress }
        let root = self.root
        let job = Task.detached {
            try await FilmExportWorker.export(root: root, filmID: filmID, sequences: sequences,
                originals: originals, coordinator: coordinator)
        }
        jobs[filmID] = job
        defer { jobs[filmID] = nil }
        try await job.value
    }

    private func removeWork(filmID: UUID) throws {
        let directory = root.appendingPathComponent("Work/\(filmID)")
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
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
        guard run.treatmentVersion == NativePhotoRenderer.treatmentVersion else { throw PersistenceError.treatmentConflict }
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
                guard let source = try repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: .source) else {
                    throw PersistenceError.captureNotFound
                }
                if kind == .master {
                    let data = try NativePhotoRenderer.develop(source: source.url, camera: film.camera, seed: treatment.seed,
                        process: run.printProcess ?? .color)
                    if let observer {
                        try await observer(filmID, .afterRendering(sequence: capture.sequenceNumber))
                        try Task.checkCancellation()
                    }
                    try Task.checkCancellation()
                    try repository.writeDevelopedMaster(filmID: filmID, sequenceNumber: capture.sequenceNumber, data: data)
                } else {
                    let output = work.appendingPathComponent("\(capture.sequenceNumber).mov")
                    try await NativeMovieRenderer.developClip(source: source.url, destination: output,
                        camera: film.camera, seed: treatment.seed, orientation: film.movieOrientation!)
                    if let observer {
                        try await observer(filmID, .afterRendering(sequence: capture.sequenceNumber))
                        try Task.checkCancellation()
                    }
                    try Task.checkCancellation()
                    _ = try await VerifiedMedia.movie(at: output)
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
            else { verification = try await VerifiedMedia.movie(at: asset.url); clips.append(asset.url) }
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
            try await NativeMovieRenderer.assemble(clips: clips, destination: output, soundtrack: soundtrack?.url)
            let verification = try await VerifiedMedia.movie(at: output, allowsAudio: soundtrack != nil)
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
        try await cleanup(root: root, filmID: filmID)
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
                else { evidence.append(try await VerifiedMedia.movie(at: asset.url, allowsAudio: kind == .movie)) }
            }
            try repository.cleanupSourceAfterVerifiedMaster(filmID: filmID, sequenceNumber: capture.sequenceNumber, verifiedMedia: evidence)
        }
    }
}
