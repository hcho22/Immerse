import FilmDomain
import Foundation

public enum SaveFailureInjection: Sendable {
    case beforeDurableMove
    case afterDurableMoveBeforeDebit
}

public enum PersistenceError: Error, Equatable {
    case filmNotFound
    case captureNotFound
    case simulatedFailure(SaveFailureInjection)
    case missingVerifiedMaster
    case masterChecksumMismatch
    case notMovieFilm
    case movieNotDeveloped
    case movieNotPlayable
    case assembledMoviePlanMismatch(expected: [Int], actual: [Int])
    case missingDevelopedClip(Int)
    case clipChecksumMismatch(Int)
}

public final class FilmRepository {
    private let rootURL: URL
    private let mediaRootURL: URL
    private let tempURL: URL
    private let database: SQLiteDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
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
        loadedAt: Date = Date()
    ) throws -> Film {
        let film = try Film(
            camera: camera,
            title: title,
            loadedAt: loadedAt,
            movieOrientation: movieOrientation
        )
        try save(film)
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
        savedAt: Date = Date(),
        failureInjection: SaveFailureInjection? = nil
    ) throws -> Film {
        var film = try film(id: filmID)
        let nextSequence = film.savedCaptureCount + 1
        let destination = sourceURL(filmID: filmID, sequenceNumber: nextSequence)
        try durableWrite(
            sourceData,
            to: destination,
            failureInjection: failureInjection
        )
        let capture = try film.recordSavedPhoto(at: savedAt)

        try database.withTransaction {
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
        }
        return film
    }

    @discardableResult
    public func saveMovieClip(
        filmID: UUID,
        sourceData: Data,
        durationSeconds: Int,
        orientation: ClipOrientation,
        savedAt: Date = Date(),
        failureInjection: SaveFailureInjection? = nil
    ) throws -> Film {
        var film = try film(id: filmID)
        let nextSequence = film.savedCaptureCount + 1
        let destination = sourceURL(filmID: filmID, sequenceNumber: nextSequence)
        try durableWrite(
            sourceData,
            to: destination,
            failureInjection: failureInjection
        )
        let capture = try film.recordSavedMovieClip(
            durationSeconds: durationSeconds,
            orientation: orientation,
            at: savedAt
        )

        try database.withTransaction {
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
        }
        return film
    }

    @discardableResult
    public func startAndFinishDevelopment(filmID: UUID) throws -> Film {
        var film = try film(id: filmID)
        try film.startDevelopment()
        try film.finishDevelopment()
        try save(film)
        return film
    }

    public func writeDevelopedMaster(
        filmID: UUID,
        sequenceNumber: Int,
        data: Data
    ) throws {
        var film = try film(id: filmID)
        guard film.captures.contains(where: { $0.sequenceNumber == sequenceNumber }) else {
            throw PersistenceError.captureNotFound
        }
        if film.developmentState == .notStarted, film.canStartDevelopment {
            try film.startDevelopment()
            try film.finishDevelopment()
            try save(film)
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

    public func writeDevelopedClip(
        filmID: UUID,
        sequenceNumber: Int,
        data: Data
    ) throws {
        let film = try film(id: filmID)
        guard film.camera.medium == .movie else {
            throw PersistenceError.notMovieFilm
        }
        guard film.developmentState == .developed else {
            throw PersistenceError.movieNotDeveloped
        }
        guard film.captures.contains(where: { capture in
            guard capture.sequenceNumber == sequenceNumber else {
                return false
            }
            if case .movieClip = capture.kind {
                return true
            }
            return false
        }) else {
            throw PersistenceError.captureNotFound
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

    public func writeAssembledMovie(
        filmID: UUID,
        data: Data,
        clipSequenceNumbers: [Int]
    ) throws {
        let film = try film(id: filmID)
        guard film.camera.medium == .movie else {
            throw PersistenceError.notMovieFilm
        }
        guard film.developmentState == .developed else {
            throw PersistenceError.movieNotDeveloped
        }

        let expected = film.playableMovieClipSequenceNumbers
        guard !expected.isEmpty else {
            throw PersistenceError.movieNotPlayable
        }
        guard clipSequenceNumbers == expected else {
            throw PersistenceError.assembledMoviePlanMismatch(
                expected: expected,
                actual: clipSequenceNumbers
            )
        }
        try verifyDevelopedClipsExist(filmID: filmID, sequenceNumbers: expected)

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

    @discardableResult
    public func completeEarly(filmID: UUID) throws -> Film {
        var film = try film(id: filmID)
        try film.completeEarly()
        try save(film)
        return film
    }

    public func cleanupSourceAfterVerifiedMaster(
        filmID: UUID,
        sequenceNumber: Int
    ) throws {
        guard let source = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source),
              let master = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .master) else {
            throw PersistenceError.missingVerifiedMaster
        }
        let masterURL = rootURL.appendingPathComponent(master.relativePath)
        guard fileManager.fileExists(atPath: masterURL.path) else {
            throw PersistenceError.missingVerifiedMaster
        }
        guard try Checksum.sha256Hex(contentsOf: masterURL) == master.sha256 else {
            throw PersistenceError.masterChecksumMismatch
        }

        try removeAssetFile(source)
        try database.deleteAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source)
    }

    @discardableResult
    public func discardRevealedCapture(
        filmID: UUID,
        sequenceNumber: Int
    ) throws -> Film {
        var film = try film(id: filmID)
        try film.discardRevealedCapture(sequenceNumber: sequenceNumber)
        try database.withTransaction {
            try save(film)
            for kind in [StoredAsset.Kind.source, .master, .clip] {
                if let asset = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind) {
                    try removeAssetFile(asset)
                    try database.deleteAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind)
                }
            }
            if film.camera.medium == .movie {
                try retireAssembledMovies(filmID: filmID)
            }
        }
        return film
    }

    public func recover() throws {
        try removeTemporaryFiles()
        let referenced = Set(try database.assets().map(\.relativePath))
        guard fileManager.fileExists(atPath: mediaRootURL.path) else {
            return
        }
        let files = fileManager.enumerator(
            at: mediaRootURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        while let fileURL = files?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }
            if !referenced.contains(relativePath(for: fileURL)) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }

    public func deleteFilm(filmID: UUID) throws {
        let filmAssets = try database.assets(filmID: filmID)
        try database.withTransaction {
            for asset in filmAssets {
                try removeAssetFile(asset)
            }
            try database.deleteFilm(id: filmID)
        }

        let filmDirectory = mediaRootURL.appendingPathComponent(filmID.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: filmDirectory.path) {
            try fileManager.removeItem(at: filmDirectory)
        }
    }

    public func assetExists(
        filmID: UUID,
        sequenceNumber: Int,
        kind: StoredAsset.Kind
    ) throws -> Bool {
        guard let asset = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind) else {
            return false
        }
        return fileManager.fileExists(atPath: rootURL.appendingPathComponent(asset.relativePath).path)
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

    private func save(_ film: Film) throws {
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
        try data.write(to: temp, options: [.atomic])
        if failureInjection == .beforeDurableMove {
            try? fileManager.removeItem(at: temp)
            throw PersistenceError.simulatedFailure(.beforeDurableMove)
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temp, to: destination)
        if failureInjection == .afterDurableMoveBeforeDebit {
            throw PersistenceError.simulatedFailure(.afterDurableMoveBeforeDebit)
        }
    }

    private func removeTemporaryFiles() throws {
        guard fileManager.fileExists(atPath: tempURL.path) else {
            return
        }
        for child in try fileManager.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: nil) {
            try fileManager.removeItem(at: child)
        }
    }

    private func removeAssetFile(_ asset: StoredAsset) throws {
        let url = rootURL.appendingPathComponent(asset.relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func retireAssembledMovies(filmID: UUID) throws {
        let assembledMovies = try database.assets(filmID: filmID).filter { $0.kind == .movie }
        for asset in assembledMovies {
            try removeAssetFile(asset)
            try database.deleteAsset(
                filmID: filmID,
                sequenceNumber: asset.sequenceNumber,
                kind: asset.kind
            )
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
            guard fileManager.fileExists(atPath: url.path) else {
                throw PersistenceError.missingDevelopedClip(sequenceNumber)
            }
            guard try Checksum.sha256Hex(contentsOf: url) == clip.sha256 else {
                throw PersistenceError.clipChecksumMismatch(sequenceNumber)
            }
        }
    }

    private func sourceURL(filmID: UUID, sequenceNumber: Int) -> URL {
        mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("source-\(sequenceNumber).bin")
    }

    private func masterURL(filmID: UUID, sequenceNumber: Int) -> URL {
        mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("master-\(sequenceNumber).bin")
    }

    private func clipURL(filmID: UUID, sequenceNumber: Int) -> URL {
        mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("clip-\(sequenceNumber).bin")
    }

    private func movieURL(filmID: UUID, clipSequenceNumbers: [Int]) -> URL {
        let clipFingerprint = clipSequenceNumbers.map(String.init).joined(separator: "-")
        return mediaRootURL
            .appendingPathComponent(filmID.uuidString, isDirectory: true)
            .appendingPathComponent("movie-\(clipFingerprint).bin")
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
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }
}
