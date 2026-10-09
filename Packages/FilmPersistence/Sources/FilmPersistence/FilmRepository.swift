import FilmDomain
import Foundation
import MediaCatalog

public enum SaveFailureInjection: Sendable {
    case beforeDurableMove
    case afterDurableMoveBeforeDebit
    case afterDatabaseCommitBeforeAcknowledgement
}

public enum PersistenceError: Error, Equatable {
    case filmNotFound
    case captureNotFound
    case captureRemoved
    case invalidAssetPath
    case conflictingCaptureReceipt
    case invalidMedia
    case mediaChangedDuringVerification
    case mediaNotRevealed
    case originalChoiceRequired
    case originalChoiceAlreadyMade
    case originalExportPending
    case treatmentConflict
    case operationInProgress
    case capacityChangedSinceConfirmation
    case simulatedFailure(SaveFailureInjection)
    case missingVerifiedMaster
    case masterChecksumMismatch
    case notMovieFilm
    case movieNotDeveloped
    case movieNotPlayable
    case soundtrackSelectionLocked
    case soundtrackChanged
    case soundtrackUnavailable
    case assembledMoviePlanMismatch(expected: [Int], actual: [Int])
    case missingDevelopedClip(Int)
    case clipChecksumMismatch(Int)
}

public final class FilmRepository {
    private let rootURL: URL
    private let mediaRootURL: URL
    private let tempURL: URL
    let database: SQLiteDatabase
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL
        self.mediaRootURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        self.tempURL = rootURL.appendingPathComponent("Temporary", isDirectory: true)
        self.fileManager = fileManager

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: mediaRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
        try Self.excludeFromBackup(tempURL)

        database = try SQLiteDatabase(url: rootURL.appendingPathComponent("film-store.sqlite"))
        try migrate()
    }

    public func createFilm(
        camera: CameraPackage,
        title: String,
        movieOrientation: MovieOrientation? = nil,
        filmStock: FilmStock? = nil,
        loadedAt: Date = Date(),
        access: FilmAccess = .subscription
    ) throws -> Film {
        let film = try Film(
            camera: camera,
            title: title,
            loadedAt: loadedAt,
            movieOrientation: movieOrientation,
            filmStock: filmStock
        )
        try database.withTransaction {
            if case let .trial(device) = access {
                guard try !allFilms().contains(where: { try filmAccess(filmID: $0.id) == access }),
                      try !pendingTrialConsumptions().contains(where: { $0.originDevice == device }) else {
                    throw PersistenceError.operationInProgress
                }
            }
            try save(film)
            try database.setValue(filmID: film.id, key: "access", data: encoder.encode(access))
        }
        return film
    }

    public func film(id: UUID) throws -> Film {
        guard let data = try database.filmData(id: id.uuidString) else {
            throw PersistenceError.filmNotFound
        }
        return try decoder.decode(Film.self, from: data)
    }

    @discardableResult
    public func savePhotoCapture(
        filmID: UUID,
        sourceData: Data,
        captureID: String = UUID().uuidString,
        savedAt: Date = Date(),
        failureInjection: SaveFailureInjection? = nil
    ) throws -> Film {
        let result = try database.withTransaction {
            var film = try film(id: filmID)
            if let receipt = try captureReceipt(filmID: filmID, captureID: captureID) {
                try validate(receipt, kind: .photo, data: sourceData)
                return film
            }
            let capture = try film.recordSavedPhoto(at: savedAt)
            let destination = sourceURL(filmID: filmID, sequenceNumber: capture.sequenceNumber)
            try durableWrite(sourceData, to: destination, failureInjection: failureInjection)
            try save(film)
            try database.upsertAsset(
                StoredAsset(
                    filmID: filmID,
                    sequenceNumber: capture.sequenceNumber,
                    kind: .source,
                    relativePath: relativePath(for: destination),
                    sha256: Checksum.sha256Hex(sourceData)
                )
            )
            try saveReceipt(captureID: captureID, filmID: filmID, capture: capture, data: sourceData)
            return film
        }
        if failureInjection == .afterDatabaseCommitBeforeAcknowledgement {
            throw PersistenceError.simulatedFailure(.afterDatabaseCommitBeforeAcknowledgement)
        }
        return result
    }

    @discardableResult
    public func saveMovieClip(
        filmID: UUID,
        sourceData: Data,
        durationSeconds: TimeInterval,
        orientation: ClipOrientation,
        captureID: String = UUID().uuidString,
        savedAt: Date = Date(),
        failureInjection: SaveFailureInjection? = nil
    ) throws -> Film {
        let result = try database.withTransaction {
            var film = try film(id: filmID)
            if let receipt = try captureReceipt(filmID: filmID, captureID: captureID) {
                try validate(receipt, kind: .movieClip(seconds: durationSeconds, orientation: orientation), data: sourceData)
                return film
            }
            let capture = try film.recordSavedMovieClip(
                durationSeconds: durationSeconds,
                orientation: orientation,
                at: savedAt
            )
            let destination = sourceURL(filmID: filmID, sequenceNumber: capture.sequenceNumber, fileExtension: "mov")
            try durableWrite(sourceData, to: destination, failureInjection: failureInjection)
            try save(film)
            try database.upsertAsset(
                StoredAsset(
                    filmID: filmID,
                    sequenceNumber: capture.sequenceNumber,
                    kind: .source,
                    relativePath: relativePath(for: destination),
                    sha256: Checksum.sha256Hex(sourceData)
                )
            )
            try saveReceipt(captureID: captureID, filmID: filmID, capture: capture, data: sourceData)
            return film
        }
        if failureInjection == .afterDatabaseCommitBeforeAcknowledgement {
            throw PersistenceError.simulatedFailure(.afterDatabaseCommitBeforeAcknowledgement)
        }
        return result
    }

    public func captureReceipt(filmID: UUID, captureID: String) throws -> CaptureCommitReceipt? {
        guard let data = try database.receiptData(filmID: filmID, captureID: captureID) else { return nil }
        return try decoder.decode(CaptureCommitReceipt.self, from: data)
    }

    private func saveReceipt(captureID: String, filmID: UUID, capture: CaptureRecord, data: Data) throws {
        guard !captureID.isEmpty, ![".", ".."].contains(captureID),
              URL(fileURLWithPath: captureID).lastPathComponent == captureID else { throw PersistenceError.invalidAssetPath }
        let receipt = CaptureCommitReceipt(
            captureID: captureID, filmID: filmID, sequenceNumber: capture.sequenceNumber,
            kind: capture.kind, sourceSHA256: Checksum.sha256Hex(data)
        )
        try database.insertReceipt(receipt, data: encoder.encode(receipt))
        if capture.sequenceNumber == 1, case let .trial(device) = try filmAccess(filmID: filmID) {
            let consumption = PendingTrialConsumption(filmID: filmID, originDevice: device, savedAt: capture.savedAt)
            try database.insertTrialConsumption(filmID: filmID, data: encoder.encode(consumption))
        }
    }

    private func validate(_ receipt: CaptureCommitReceipt, kind: CaptureKind, data: Data) throws {
        guard receipt.kind == kind, receipt.sourceSHA256 == Checksum.sha256Hex(data) else {
            throw PersistenceError.conflictingCaptureReceipt
        }
    }

    public func writeDevelopedMaster(
        filmID: UUID,
        sequenceNumber: Int,
        data: Data
    ) throws {
        try database.withTransaction {
            let film = try film(id: filmID)
            guard let capture = film.captures.first(where: { $0.sequenceNumber == sequenceNumber }) else {
                throw PersistenceError.captureNotFound
            }
            guard !capture.isDiscarded else { throw PersistenceError.captureRemoved }
            if let existing = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .master) {
                guard existing.sha256 == Checksum.sha256Hex(data) else { throw PersistenceError.treatmentConflict }
                return
            }
            let destination = masterURL(filmID: filmID, sequenceNumber: sequenceNumber)
            try durableWrite(data, to: destination, failureInjection: nil)
            try database.upsertAsset(
                StoredAsset(
                    filmID: filmID,
                    sequenceNumber: sequenceNumber,
                    kind: .master,
                    relativePath: relativePath(for: destination),
                    sha256: Checksum.sha256Hex(data)
                )
            )
        }
    }

    public func writeDevelopedClip(
        filmID: UUID,
        sequenceNumber: Int,
        data: Data
    ) throws {
        try database.withTransaction {
            let film = try film(id: filmID)
            guard film.camera.medium == .movie else { throw PersistenceError.notMovieFilm }
            guard film.developmentState != .notStarted else { throw PersistenceError.movieNotDeveloped }
            guard let capture = film.captures.first(where: { $0.sequenceNumber == sequenceNumber }),
                  case .movieClip = capture.kind else {
                throw PersistenceError.captureNotFound
            }
            guard !capture.isDiscarded else { throw PersistenceError.captureRemoved }
            if let existing = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .clip) {
                guard existing.sha256 == Checksum.sha256Hex(data) else { throw PersistenceError.treatmentConflict }
                return
            }
            let destination = clipURL(filmID: filmID, sequenceNumber: sequenceNumber)
            try durableWrite(data, to: destination, failureInjection: nil)
            try database.upsertAsset(
                StoredAsset(
                    filmID: filmID,
                    sequenceNumber: sequenceNumber,
                    kind: .clip,
                    relativePath: relativePath(for: destination),
                    sha256: Checksum.sha256Hex(data)
                )
            )
        }
    }

    public func writeAssembledMovie(
        filmID: UUID,
        data: Data,
        clipSequenceNumbers: [Int],
        verification: VerifiedMedia? = nil,
        soundtrackRevision: UUID? = nil
    ) throws {
        try database.withTransaction {
            let film = try film(id: filmID)
            guard film.camera.medium == .movie else { throw PersistenceError.notMovieFilm }
            guard film.developmentState != .notStarted else { throw PersistenceError.movieNotDeveloped }
            let expected = film.captures.filter { !$0.isDiscarded }.map(\.sequenceNumber)
            guard !expected.isEmpty else { throw PersistenceError.movieNotPlayable }
            guard clipSequenceNumbers == expected else {
                throw PersistenceError.assembledMoviePlanMismatch(expected: expected, actual: clipSequenceNumbers)
            }
            let audio = try movieAudioSelection(filmID: filmID)
            guard audio?.revision == soundtrackRevision else { throw PersistenceError.soundtrackChanged }
            try verifyDevelopedClipsExist(filmID: filmID, sequenceNumbers: expected)
            guard let verification, verification.kind == .movie, verification.sha256 == Checksum.sha256Hex(data),
                  verification.audioTrackCount == (audio?.asset == nil ? 0 : 1) else {
                throw PersistenceError.invalidMedia
            }
            let destination = movieURL(filmID: filmID, clipSequenceNumbers: expected)
            try retireAssembledMovies(filmID: filmID)
            try durableWrite(data, to: destination, failureInjection: nil)
            try database.upsertAsset(
                StoredAsset(
                    filmID: filmID,
                    sequenceNumber: 0,
                    kind: .movie,
                    relativePath: relativePath(for: destination),
                    sha256: Checksum.sha256Hex(data)
                )
            )
        }
        try finishPendingDeletions(filmID: filmID)
    }

    public func movieAudioSelection(filmID: UUID) throws -> MovieAudioSelection? {
        _ = try film(id: filmID)
        guard let data = try database.value(filmID: filmID, key: "movie-audio") else { return nil }
        return try decoder.decode(MovieAudioSelection.self, from: data)
    }

    public func retainedSoundtrack(filmID: UUID) throws -> StoredMediaAsset? {
        guard let selected = try movieAudioSelection(filmID: filmID)?.asset else { return nil }
        guard let audio = try mediaAsset(filmID: filmID, sequenceNumber: 0, kind: .soundtrack),
              let license = try mediaAsset(filmID: filmID, sequenceNumber: 0, kind: .soundtrackLicense),
              audio.record.sha256 == selected.sha256,
              try Checksum.sha256Hex(contentsOf: audio.url) == selected.sha256,
              try Checksum.sha256Hex(contentsOf: license.url) == selected.rights.licenseSHA256 else {
            throw PersistenceError.soundtrackUnavailable
        }
        return audio
    }

    public func selectMovieSoundtrack(
        filmID: UUID, asset: VerifiedCatalogAsset?, verification: VerifiedMedia?,
        reselectionPolicy: SoundtrackReselectionPolicy
    ) throws {
        let data = try asset?.data()
        try database.withTransaction {
            let film = try film(id: filmID)
            guard film.canPlaybackDevelopedMovie else { throw PersistenceError.movieNotPlayable }
            let current = try movieAudioSelection(filmID: filmID)
            if let current, current.asset == asset?.metadata { return }
            guard current == nil || reselectionPolicy == .allowed else { throw PersistenceError.soundtrackSelectionLocked }
            if let asset, let data {
                guard asset.metadata.purpose == .instrumental, asset.metadata.kind == .audio,
                      asset.metadata.cameraIDs.contains(film.camera.id), asset.metadata.rights.permitsMovieExport,
                      let verification, verification.kind == .audio, verification.sha256 == Checksum.sha256Hex(data) else {
                    throw PersistenceError.invalidMedia
                }
            } else if asset != nil || verification != nil { throw PersistenceError.invalidMedia }

            let selection = MovieAudioSelection(revision: UUID(), asset: asset?.metadata)
            for kind in [StoredAsset.Kind.soundtrack, .soundtrackLicense] {
                if let old = try database.asset(filmID: filmID, sequenceNumber: 0, kind: kind) {
                    try database.enqueueDeletion(filmID: filmID, relativePath: old.relativePath)
                    try database.deleteAsset(filmID: filmID, sequenceNumber: 0, kind: kind)
                }
            }
            if let asset, let data {
                let directory = mediaRootURL.appendingPathComponent(filmID.uuidString)
                for (kind, bytes) in [(StoredAsset.Kind.soundtrack, data), (.soundtrackLicense, asset.license)] {
                    let suffix = kind == .soundtrack ? asset.url.pathExtension : "txt"
                    let url = directory.appendingPathComponent("\(kind.rawValue)-\(selection.revision).\(suffix)")
                    try durableWrite(bytes, to: url, failureInjection: nil)
                    try database.upsertAsset(StoredAsset(filmID: filmID, sequenceNumber: 0, kind: kind,
                        relativePath: relativePath(for: url), sha256: Checksum.sha256Hex(bytes)))
                }
            }
            try database.setValue(filmID: filmID, key: "movie-audio", data: encoder.encode(selection))
            try retireAssembledMovies(filmID: filmID)
        }
        try finishPendingDeletions(filmID: filmID)
    }

    @discardableResult
    public func completeEarly(filmID: UUID, confirmedCaptureCount: Int? = nil) throws -> Film {
        try database.withTransaction {
            var film = try film(id: filmID)
            if let confirmedCaptureCount, film.savedCaptureCount != confirmedCaptureCount {
                throw PersistenceError.capacityChangedSinceConfirmation
            }
            try film.completeEarly()
            try save(film)
            return film
        }
    }

    public func cleanupSourceAfterVerifiedMaster(
        filmID: UUID,
        sequenceNumber: Int,
        verifiedMedia: [VerifiedMedia] = []
    ) throws {
        try database.withTransaction {
            let film = try film(id: filmID)
            guard let capture = film.captures.first(where: { $0.sequenceNumber == sequenceNumber }),
                  capture.revealState == .revealed else { throw PersistenceError.mediaNotRevealed }
            guard let source = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source) else { return }
            guard let disposition = try originalDisposition(filmID: filmID, sequenceNumber: sequenceNumber) else {
                throw PersistenceError.originalChoiceRequired
            }
            switch disposition {
            case .declined: break
            case .exportRequested: throw PersistenceError.originalExportPending
            case let .exported(hash, identifier):
                guard hash == source.sha256, !identifier.isEmpty else { throw PersistenceError.originalExportPending }
            }
            let required: [(Int, StoredAsset.Kind)] = film.camera.medium == .photo
                ? [(sequenceNumber, .master)] : [(sequenceNumber, .clip), (0, .movie)]
            for (sequence, kind) in required {
                guard let master = try database.asset(filmID: filmID, sequenceNumber: sequence, kind: kind) else {
                    throw PersistenceError.missingVerifiedMaster
                }
                let url = rootURL.appendingPathComponent(master.relativePath)
                guard try fileManager.itemExists(at: url) else { throw PersistenceError.missingVerifiedMaster }
                guard try Checksum.sha256Hex(contentsOf: url) == master.sha256 else {
                    throw PersistenceError.masterChecksumMismatch
                }
                guard verifiedMedia.contains(where: {
                    $0.sha256 == master.sha256 && $0.kind == (kind == .master ? .photo : .movie)
                }) else { throw PersistenceError.invalidMedia }
            }
            try database.enqueueDeletion(filmID: filmID, relativePath: source.relativePath)
            try database.deleteAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source)
        }
        try finishPendingDeletions(filmID: filmID)
    }

    public func originalDisposition(filmID: UUID, sequenceNumber: Int) throws -> OriginalDisposition? {
        guard let data = try database.value(filmID: filmID, key: "original-\(sequenceNumber)") else { return nil }
        return try decoder.decode(OriginalDisposition.self, from: data)
    }

    public func chooseOriginalExport(filmID: UUID, sequenceNumber: Int, export: Bool) throws {
        try database.withTransaction {
            let film = try film(id: filmID)
            guard let capture = film.captures.first(where: { $0.sequenceNumber == sequenceNumber }), !capture.isDiscarded,
                  film.canStartDevelopment || film.developmentState != .notStarted || film.camera.revealRule == .instantPerExposure else {
                throw PersistenceError.mediaNotRevealed
            }
            let choice: OriginalDisposition = export ? .exportRequested : .declined
            if let previous = try originalDisposition(filmID: filmID, sequenceNumber: sequenceNumber) {
                guard previous == choice else { throw PersistenceError.originalChoiceAlreadyMade }
                return
            }
            try database.setValue(filmID: filmID, key: "original-\(sequenceNumber)", data: encoder.encode(choice))
        }
    }

    public func recordSuccessfulOriginalExport(
        filmID: UUID, sequenceNumber: Int, sourceSHA256: String, photosIdentifier: String
    ) throws {
        try database.withTransaction {
            _ = try revealedAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source)
            guard try originalDisposition(filmID: filmID, sequenceNumber: sequenceNumber) == .exportRequested,
                  let source = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source),
                  source.sha256 == sourceSHA256, !photosIdentifier.isEmpty else {
                throw PersistenceError.originalExportPending
            }
            let receipt = OriginalDisposition.exported(sourceSHA256: sourceSHA256, photosIdentifier: photosIdentifier)
            try database.setValue(filmID: filmID, key: "original-\(sequenceNumber)", data: encoder.encode(receipt))
        }
    }

    public func mediaAsset(filmID: UUID, sequenceNumber: Int, kind: StoredAsset.Kind) throws -> StoredMediaAsset? {
        guard let asset = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind) else { return nil }
        return StoredMediaAsset(record: asset, url: rootURL.appendingPathComponent(asset.relativePath))
    }

    public func captureStagingDirectory(filmID: UUID) throws -> URL {
        _ = try film(id: filmID)
        return rootURL.appendingPathComponent("Staging/\(filmID)", isDirectory: true)
    }

    /// A presentation guard, not a replacement for the runtime's serialized save
    /// owner. Include malformed metadata so unavailable recovery stays visible.
    public func hasPendingCapture(filmID: UUID) throws -> Bool {
        let staging = try captureStagingDirectory(filmID: filmID)
        for directory in [staging, staging.appendingPathComponent("Commit")] {
            if try fileManager.contentsOfDirectoryIfPresent(at: directory)
                .contains(where: { $0.pathExtension == "json" }) { return true }
        }
        return false
    }

    public func revealedAsset(filmID: UUID, sequenceNumber: Int, kind: StoredAsset.Kind) throws -> StoredMediaAsset {
        let film = try film(id: filmID)
        if kind == .movie {
            guard film.canPlaybackDevelopedMovie else { throw PersistenceError.mediaNotRevealed }
        } else {
            guard film.captures.contains(where: { $0.sequenceNumber == sequenceNumber && $0.revealState == .revealed }) else {
                throw PersistenceError.mediaNotRevealed
            }
        }
        guard let asset = try mediaAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind) else {
            throw PersistenceError.missingVerifiedMaster
        }
        return asset
    }

    @discardableResult
    public func discardRevealedCapture(
        filmID: UUID,
        sequenceNumber: Int
    ) throws -> Film {
        let film = try database.withTransaction {
            var film = try self.film(id: filmID)
            if film.captures.contains(where: { $0.sequenceNumber == sequenceNumber && $0.isDiscarded }) {
                return film
            }
            try film.discardRevealedCapture(sequenceNumber: sequenceNumber)
            try save(film)
            try database.deleteValue(filmID: filmID, key: "recipe-\(sequenceNumber)")
            try database.deleteValue(filmID: filmID, key: "original-\(sequenceNumber)")
            try database.enqueueDeletion(filmID: filmID, relativePath: "Work/\(filmID)")
            for data in try database.allReceiptData(filmID: filmID) {
                let receipt = try decoder.decode(CaptureCommitReceipt.self, from: data)
                guard receipt.sequenceNumber == sequenceNumber else { continue }
                let path = "Staging/\(filmID)/\(receipt.captureID)"
                try database.enqueueDeletion(filmID: filmID, relativePath: path)
                let metadata = (path as NSString).deletingPathExtension + ".json"
                try database.enqueueDeletion(filmID: filmID, relativePath: metadata)
            }
            for kind in [StoredAsset.Kind.source, .master, .clip] {
                if let asset = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind) {
                    try database.enqueueDeletion(filmID: filmID, relativePath: asset.relativePath)
                    try database.deleteAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind)
                }
            }
            if film.camera.medium == .movie {
                for asset in try database.assets(filmID: filmID) where asset.kind == .movie {
                    try database.enqueueDeletion(filmID: filmID, relativePath: asset.relativePath)
                    try database.deleteAsset(filmID: filmID, sequenceNumber: asset.sequenceNumber, kind: .movie)
                }
            }
            return film
        }
        // The tombstone and logical asset retirement survive even if filesystem cleanup fails.
        try finishPendingDeletions(filmID: filmID)
        return film
    }

    /// Every cleanup step runs even when an earlier one fails, so one uninspectable
    /// path never leaves another Film's private files behind; the first failure is rethrown.
    public func recover() throws {
        var failure: Error?
        try database.withTransaction {
            let work = rootURL.appendingPathComponent("Work", isDirectory: true)
            let steps: [() throws -> Void] = [
                { try self.finishPendingDeletions() },
                { try self.removeChildren(of: self.tempURL) },
                { try self.removeChildren(of: work) },
                { try self.removeUnreferencedMedia(in: self.mediaRootURL, referenced: Set(try self.database.assets().map(\.relativePath))) }
            ]
            for step in steps {
                do { try step() } catch { failure = failure ?? error }
            }
        }
        if let failure { throw failure }
    }

    public func deleteFilm(filmID: UUID) throws {
        let filmDirectory = mediaRootURL.appendingPathComponent(filmID.uuidString, isDirectory: true)
        try database.withTransaction {
            for asset in try database.assets(filmID: filmID) {
                try database.enqueueDeletion(filmID: filmID, relativePath: asset.relativePath)
            }
            try database.enqueueDeletion(filmID: filmID, relativePath: relativePath(for: filmDirectory))
            try database.enqueueDeletion(filmID: filmID, relativePath: "Staging/\(filmID)")
            try database.enqueueDeletion(filmID: filmID, relativePath: "Work/\(filmID)")
            try database.deleteFilm(id: filmID)
        }
        try finishPendingDeletions(filmID: filmID)
    }

    public func assetExists(
        filmID: UUID,
        sequenceNumber: Int,
        kind: StoredAsset.Kind
    ) throws -> Bool {
        guard let asset = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind) else {
            return false
        }
        return try fileManager.itemExists(at: rootURL.appendingPathComponent(asset.relativePath))
    }

    public func assembledMovieExists(filmID: UUID) throws -> Bool {
        try assetExists(filmID: filmID, sequenceNumber: 0, kind: .movie)
    }

    public func temporaryDirectoryIsExcludedFromBackup() throws -> Bool {
        let values = try tempURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values.isExcludedFromBackup == true
    }

    public func mediaDirectoryIsExcludedFromBackup() throws -> Bool {
        let values = try mediaRootURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values.isExcludedFromBackup == true
    }

    func save(_ film: Film) throws {
        try database.upsertFilm(id: film.id.uuidString, data: encoder.encode(film))
    }

    private func durableWrite(
        _ data: Data,
        to destination: URL,
        failureInjection: SaveFailureInjection?
    ) throws {
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temp = tempURL.appendingPathComponent(UUID().uuidString)
        do {
            try data.write(to: temp, options: [.atomic])
            let handle = try FileHandle(forWritingTo: temp)
            do {
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
            if failureInjection == .beforeDurableMove {
                throw PersistenceError.simulatedFailure(.beforeDurableMove)
            }
            try fileManager.removeItemIfPresent(at: destination)
            try fileManager.moveItem(at: temp, to: destination)
        } catch {
            try? fileManager.removeItemIfPresent(at: temp)
            throw error
        }
        if failureInjection == .afterDurableMoveBeforeDebit {
            throw PersistenceError.simulatedFailure(.afterDurableMoveBeforeDebit)
        }
    }

    private func removeChildren(of directory: URL) throws {
        try attemptEach(fileManager.contentsOfDirectoryIfPresent(at: directory)) { try fileManager.removeItem(at: $0) }
    }

    /// Walks every Media folder; an unreadable folder throws instead of reading as empty.
    private func removeUnreferencedMedia(in directory: URL, referenced: Set<String>) throws {
        try attemptEach(fileManager.contentsOfDirectoryIfPresent(at: directory)) { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                try removeUnreferencedMedia(in: url, referenced: referenced)
            } else if values.isRegularFile == true, !referenced.contains(relativePath(for: url)) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    /// Attempts every item, then rethrows the first failure.
    private func attemptEach<Item>(_ items: [Item], _ body: (Item) throws -> Void) throws {
        var failure: Error?
        for item in items {
            do { try body(item) } catch { failure = failure ?? error }
        }
        if let failure { throw failure }
    }

    private func removeAssetFile(_ asset: StoredAsset) throws {
        try fileManager.removeItemIfPresent(at: rootURL.appendingPathComponent(asset.relativePath))
    }

    private func retireAssembledMovies(filmID: UUID) throws {
        let assembledMovies = try database.assets(filmID: filmID).filter { $0.kind == .movie }
        for asset in assembledMovies {
            try database.enqueueDeletion(filmID: filmID, relativePath: asset.relativePath)
            try database.deleteAsset(
                filmID: filmID,
                sequenceNumber: asset.sequenceNumber,
                kind: asset.kind
            )
        }
    }

    private func finishPendingDeletions(filmID: UUID? = nil) throws {
        let roots = [mediaRootURL, rootURL.appendingPathComponent("Staging"), rootURL.appendingPathComponent("Work")]
            .map { $0.resolvingSymlinksInPath().path + "/" }
        try attemptEach(database.pendingDeletionPaths(filmID: filmID)) { path in
            let url = rootURL.appendingPathComponent(path).standardizedFileURL
            guard roots.contains(where: { url.resolvingSymlinksInPath().path.hasPrefix($0) }) else {
                throw PersistenceError.invalidAssetPath
            }
            // An uninspectable path keeps its tombstone; only a confirmed absence finishes it.
            try fileManager.removeItemIfPresent(at: url)
            try database.finishDeletion(relativePath: path)
        }
    }

    private func verifyDevelopedClipsExist(
        filmID: UUID,
        sequenceNumbers: [Int]
    ) throws {
        for sequenceNumber in sequenceNumbers {
            guard let clip = try database.asset(
                filmID: filmID,
                sequenceNumber: sequenceNumber,
                kind: .clip
            ) else {
                throw PersistenceError.missingDevelopedClip(sequenceNumber)
            }
            let url = rootURL.appendingPathComponent(clip.relativePath)
            guard try fileManager.itemExists(at: url) else {
                throw PersistenceError.missingDevelopedClip(sequenceNumber)
            }
            guard try Checksum.sha256Hex(contentsOf: url) == clip.sha256 else {
                throw PersistenceError.clipChecksumMismatch(sequenceNumber)
            }
        }
    }

    private func sourceURL(filmID: UUID, sequenceNumber: Int, fileExtension: String = "bin") -> URL {
        mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("source-\(sequenceNumber).\(fileExtension)")
    }

    private func masterURL(filmID: UUID, sequenceNumber: Int) -> URL {
        mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("master-\(sequenceNumber).bin")
    }

    private func clipURL(filmID: UUID, sequenceNumber: Int) -> URL {
        mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("clip-\(sequenceNumber).mov")
    }

    private func movieURL(filmID: UUID, clipSequenceNumbers: [Int]) -> URL {
        let clipFingerprint = clipSequenceNumbers.map(String.init).joined(separator: "-")
        return mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("movie-\(clipFingerprint)-\(UUID()).mov")
    }

    private func relativePath(for url: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else {
            return url.lastPathComponent
        }
        return String(path.dropFirst(root.count + 1))
    }

    private func migrate() throws {
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS films (
                id TEXT PRIMARY KEY NOT NULL,
                data BLOB NOT NULL,
                updated_at REAL NOT NULL
            );
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS assets (
                film_id TEXT NOT NULL,
                sequence INTEGER NOT NULL,
                kind TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                sha256 TEXT NOT NULL,
                PRIMARY KEY (film_id, sequence, kind),
                FOREIGN KEY (film_id) REFERENCES films(id) ON DELETE CASCADE
            );
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS pending_deletions (
                film_id TEXT NOT NULL,
                relative_path TEXT PRIMARY KEY NOT NULL
            );
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS capture_receipts (
                film_id TEXT NOT NULL,
                capture_id TEXT NOT NULL,
                data BLOB NOT NULL,
                PRIMARY KEY (film_id, capture_id),
                FOREIGN KEY (film_id) REFERENCES films(id) ON DELETE CASCADE
            );
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS film_values (
                film_id TEXT NOT NULL,
                key TEXT NOT NULL,
                data BLOB NOT NULL,
                PRIMARY KEY (film_id, key),
                FOREIGN KEY (film_id) REFERENCES films(id) ON DELETE CASCADE
            );
            """
        )
        try database.execute("CREATE TABLE IF NOT EXISTS trial_outbox (film_id TEXT PRIMARY KEY NOT NULL, data BLOB NOT NULL);")
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }
}
