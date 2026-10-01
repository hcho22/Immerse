import CryptoKit
import FilmDomain
import FilmPersistence
import Foundation

struct PendingCaptureCommit: Codable, Sendable {
    let captureID: String
    let filmID: UUID
    let camera: CameraPackage
    let access: FilmAccess
    let expectedSequence: Int
    let kind: CaptureKind
    let savedAt: Date
    let sourceSHA256: String
}

struct CaptureCommitJournal {
    let root: URL

    func pending(filmID: UUID) throws -> [PendingCaptureCommit] {
        let directory = directory(filmID)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { url in
                let operation = try JSONDecoder().decode(PendingCaptureCommit.self, from: Data(contentsOf: url))
                guard operation.filmID == filmID, validID(operation.captureID),
                      url.resolvingSymlinksInPath().path == manifest(operation).resolvingSymlinksInPath().path else {
                    throw PersistenceError.invalidAssetPath
                }
                return operation
            }.sorted { $0.expectedSequence < $1.expectedSequence }
    }

    func prepare(film: Film, access: FilmAccess, source: URL, kind: CaptureKind, savedAt: Date) async throws -> PendingCaptureCommit {
        let id = source.lastPathComponent
        guard validID(id) else { throw PersistenceError.invalidAssetPath }
        let verification = try await Self.verify(source, kind: kind)
        var proposed = film
        let sequence: Int
        switch kind {
        case .photo: sequence = try proposed.recordSavedPhoto(at: savedAt).sequenceNumber
        case let .movieClip(seconds, orientation):
            sequence = try proposed.recordSavedMovieClip(durationSeconds: seconds, orientation: orientation, at: savedAt).sequenceNumber
        }
        let operation = PendingCaptureCommit(captureID: id, filmID: film.id, camera: film.camera,
            access: access, expectedSequence: sequence, kind: kind, savedAt: savedAt, sourceSHA256: verification.sha256)
        var directory = directory(film.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resources = URLResourceValues(); resources.isExcludedFromBackup = false
        try directory.setResourceValues(resources)
        let bytes = try Data(contentsOf: source)
        guard Self.hash(bytes) == verification.sha256 else { throw PersistenceError.mediaChangedDuringVerification }
        try bytes.write(to: media(operation), options: .atomic)
        try synchronize(media(operation))
        try JSONEncoder().encode(operation).write(to: manifest(operation), options: .atomic)
        try synchronize(manifest(operation))
        return operation
    }

    func verifiedBytes(_ operation: PendingCaptureCommit) async throws -> Data {
        let source = media(operation)
        let verification = try await Self.verify(source, kind: operation.kind)
        let bytes = try Data(contentsOf: source)
        guard verification.sha256 == operation.sourceSHA256, Self.hash(bytes) == operation.sourceSHA256 else {
            throw PersistenceError.mediaChangedDuringVerification
        }
        return bytes
    }

    func finish(_ operation: PendingCaptureCommit) throws {
        let url = media(operation)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.removeItem(at: manifest(operation))
    }

    private func directory(_ id: UUID) -> URL { root.appendingPathComponent("Staging/\(id)/Commit") }
    private func manifest(_ operation: PendingCaptureCommit) -> URL {
        directory(operation.filmID).appendingPathComponent("\(operation.captureID).json")
    }
    private func media(_ operation: PendingCaptureCommit) -> URL {
        directory(operation.filmID).appendingPathComponent(operation.captureID)
    }
    private func validID(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && URL(fileURLWithPath: value).lastPathComponent == value
    }
    private func synchronize(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func verify(_ url: URL, kind: CaptureKind) async throws -> VerifiedMedia {
        switch kind {
        case .photo: return try VerifiedMedia.photo(at: url)
        case let .movieClip(seconds, _):
            let verification = try await VerifiedMedia.movie(at: url)
            guard verification.durationSeconds == seconds else { throw PersistenceError.invalidMedia }
            return verification
        }
    }
}
