import CryptoKit
import FilmDomain
import FilmPersistence
import Foundation

// Non-shipping study: no Security import or production adapter. The injected
// store grants single-item atomicity, quiescent return and authoritative reads.
struct Receipt: Codable, Equatable, Sendable {
    let filmID: UUID
    let captureID: UUID
    let savedAt: Date
}

struct ReceiptRecord: Codable, Sendable {
    let deviceID: UUID
    let receipt: Receipt?
}

protocol ReceiptStoring: Sendable {
    func read() throws -> ReceiptRecord
    func publish(_ receipt: Receipt) throws
}

enum ReceiptFailure: Error, Equatable { case rejected, unknown, unavailable, conflict }
enum StudyError: Error, Equatable {
    case consumed, inProgress, alreadyCommitted, aborted, invalidOperation
}

enum Boundary: String, CaseIterable, Sendable {
    case preparedMetadata, copiedMedia, pendingManifest, beforeReceipt, afterReceipt
    case beforeProjection, afterProjection, beforeCleanup, afterSourceCleanup, afterCleanup
    case beforeAbort, afterAbort, afterAbortCleanup, beforeDelete, afterDelete
}

struct CaptureInput: Sendable {
    let id: UUID
    let filmID: UUID
    let url: URL
    let kind: CaptureKind
    let savedAt: Date
}

struct Operation: Codable, Sendable {
    enum Phase: String, Codable { case preparing, pending, aborted }
    let id: UUID
    let filmID: UUID
    let access: FilmAccess
    let camera: CameraPackage
    let movieOrientation: MovieOrientation?
    let sequence: Int
    let kind: CaptureKind
    let savedAt: Date
    let sha256: String
    var phase: Phase
    var receipt: Receipt { Receipt(filmID: filmID, captureID: id, savedAt: savedAt) }
}

actor ReceiptCoordinator {
    private let root: URL
    private let repository: FilmRepository
    private let store: any ReceiptStoring
    private let boundary: @Sendable (Boundary) async throws -> Void
    private let projectionFailure: SaveFailureInjection?
    private var occupied = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(root: URL, store: any ReceiptStoring, projectionFailure: SaveFailureInjection? = nil,
         boundary: @escaping @Sendable (Boundary) async throws -> Void = { _ in }) throws {
        self.root = root
        self.repository = try FilmRepository(rootURL: root)
        self.store = store
        self.boundary = boundary
        self.projectionFailure = projectionFailure
    }

    func start(camera: CameraPackage) async throws -> Film {
        await enter(); defer { leave() }
        try await reconcileLocked()
        let record = try store.read()
        guard record.receipt == nil else { throw StudyError.consumed }
        guard try !repository.allFilms().contains(where: {
            try repository.filmAccess(filmID: $0.id) == .trial(originDevice: record.deviceID)
        }) else { throw StudyError.inProgress }
        return try repository.createFilm(camera: camera, title: "Private receipt study",
            movieOrientation: camera.medium == .movie ? .portrait : nil,
            filmStock: camera.defaultFilmStock,
            access: .trial(originDevice: record.deviceID))
    }

    func reconcile() async throws {
        await enter(); defer { leave() }
        try await reconcileLocked()
    }

    func queuedOperations() -> Int { waiters.count }

    func save(_ input: CaptureInput) async throws {
        await enter(); defer { leave() }
        try await reconcileLocked()
        var film = try repository.film(id: input.filmID)
        let verified = try await verify(input.url, kind: input.kind)
        if let prior = try repository.captureReceipt(filmID: input.filmID, captureID: input.id.uuidString) {
            guard prior.sourceSHA256 == verified.sha256, prior.kind == input.kind else { throw StudyError.invalidOperation }
            return
        }
        let sequence = try debit(&film, kind: input.kind, at: input.savedAt)
        let operation = Operation(id: input.id, filmID: input.filmID,
            access: try repository.filmAccess(filmID: input.filmID), camera: film.camera,
            movieOrientation: film.movieOrientation, sequence: sequence, kind: input.kind,
            savedAt: input.savedAt, sha256: verified.sha256, phase: .preparing)
        let metadata = try manifestURL(operation)
        // Terminal aborts remain until whole-Film removal, so duplicate delivery
        // cannot quietly turn a rejected operation back into a pending one.
        guard !FileManager.default.fileExists(atPath: metadata.path) else { throw StudyError.aborted }
        try write(operation)
        try await boundary(.preparedMetadata)
        try Data(contentsOf: input.url).write(to: mediaURL(operation), options: .withoutOverwriting)
        try synchronize(mediaURL(operation))
        try await boundary(.copiedMedia)
        try await finish(operation)
    }

    func abort(filmID: UUID, captureID: UUID) async throws {
        await enter(); defer { leave() }
        let operation = try readOperation(filmID: filmID, id: captureID)
        if operation.phase == .aborted { return }
        let record = try store.read()
        guard record.receipt != operation.receipt,
              try repository.captureReceipt(filmID: filmID, captureID: captureID.uuidString) == nil else {
            throw StudyError.alreadyCommitted
        }
        try await reject(operation)
    }

    func deleteFilm(_ id: UUID) async throws {
        await enter(); defer { leave() }
        try await boundary(.beforeDelete)
        // The lease has quiesced every publish/projection, including lost replies.
        // Unknown outcomes do not delay private removal or refund consumption.
        try repository.deleteFilm(filmID: id)
        try await boundary(.afterDelete)
    }

    private func reconcileLocked() async throws {
        _ = try store.read() // Unknown destination identity fails closed.
        try repository.recover()
        var operations: [Operation] = []
        for film in try repository.allFilms() {
            let directory = try directory(film.id)
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                where file.pathExtension == "json" {
                let operation = try JSONDecoder().decode(Operation.self, from: Data(contentsOf: file))
                guard operation.filmID == film.id,
                      file.resolvingSymlinksInPath().standardizedFileURL.path ==
                        (try manifestURL(operation)).resolvingSymlinksInPath().standardizedFileURL.path else {
                    throw StudyError.invalidOperation
                }
                operations.append(operation)
            }
        }
        for operation in operations.sorted(by: { $0.savedAt == $1.savedAt
            ? $0.id.uuidString < $1.id.uuidString : $0.savedAt < $1.savedAt }) {
            if operation.phase == .aborted {
                try removeMedia(operation)
            } else if try operation.phase == .preparing && !FileManager.default.fileExists(atPath: mediaURL(operation).path) {
                try await reject(operation)
            } else {
                try await finish(operation)
            }
        }
    }

    private func finish(_ original: Operation) async throws {
        var operation = original
        let film = try repository.film(id: operation.filmID)
        guard operation.camera == film.camera, operation.movieOrientation == film.movieOrientation,
              operation.access == (try repository.filmAccess(filmID: film.id)) else { throw StudyError.invalidOperation }
        if let projected = try repository.captureReceipt(filmID: film.id, captureID: operation.id.uuidString) {
            guard projected.kind == operation.kind, projected.sequenceNumber == operation.sequence,
                  projected.sourceSHA256 == operation.sha256 else { throw StudyError.invalidOperation }
            try repository.finishTrialConsumption(filmID: film.id)
            try await cleanup(operation)
            return
        }
        let source = try mediaURL(operation)
        let verified = try await verify(source, kind: operation.kind)
        guard verified.sha256 == operation.sha256, operation.sequence == film.savedCaptureCount + 1 else {
            throw StudyError.invalidOperation
        }
        var proposed = film
        _ = try debit(&proposed, kind: operation.kind, at: operation.savedAt)
        if operation.phase == .preparing {
            operation.phase = .pending
            try write(operation)
            try await boundary(.pendingManifest)
        }
        let record = try store.read()
        if operation.sequence == 1, operation.access == .trial(originDevice: record.deviceID) {
            if let receipt = record.receipt {
                guard receipt == operation.receipt else { throw ReceiptFailure.conflict }
            } else {
                try await boundary(.beforeReceipt)
                do { try store.publish(operation.receipt) }
                catch ReceiptFailure.rejected {
                    try await reject(operation)
                    throw ReceiptFailure.rejected
                } catch {
                    // Even a lost success response is not a failed capture. No
                    // abort, projection, next capture or Trial start on ambiguity.
                    throw error
                }
                guard try store.read().receipt == operation.receipt else { throw ReceiptFailure.unknown }
                try await boundary(.afterReceipt)
            }
        }
        try await boundary(.beforeProjection)
        let bytes = try Data(contentsOf: source)
        guard Self.hash(bytes) == operation.sha256 else { throw StudyError.invalidOperation }
        switch operation.kind {
        case .photo:
            try repository.savePhotoCapture(filmID: film.id, sourceData: bytes, captureID: operation.id.uuidString,
                savedAt: operation.savedAt, failureInjection: projectionFailure)
        case let .movieClip(seconds, orientation):
            try repository.saveMovieClip(filmID: film.id, sourceData: bytes, durationSeconds: seconds,
                orientation: orientation, captureID: operation.id.uuidString,
                savedAt: operation.savedAt, failureInjection: projectionFailure)
        }
        try await boundary(.afterProjection)
        try repository.finishTrialConsumption(filmID: film.id)
        try await cleanup(operation)
    }

    private func reject(_ original: Operation) async throws {
        try await boundary(.beforeAbort)
        var operation = original
        operation.phase = .aborted
        try write(operation)
        try await boundary(.afterAbort)
        try removeMedia(operation)
        try await boundary(.afterAbortCleanup)
    }

    private func cleanup(_ operation: Operation) async throws {
        try await boundary(.beforeCleanup)
        try removeMedia(operation)
        try await boundary(.afterSourceCleanup)
        try FileManager.default.removeItem(at: manifestURL(operation))
        try await boundary(.afterCleanup)
    }

    private func verify(_ url: URL, kind: CaptureKind) async throws -> VerifiedMedia {
        switch kind {
        case .photo: return try VerifiedMedia.photo(at: url)
        case let .movieClip(seconds, _):
            let value = try await VerifiedMedia.movie(at: url)
            guard value.durationSeconds == seconds else { throw StudyError.invalidOperation }
            return value
        }
    }

    private func debit(_ film: inout Film, kind: CaptureKind, at date: Date) throws -> Int {
        switch kind {
        case .photo: return try film.recordSavedPhoto(at: date).sequenceNumber
        case let .movieClip(seconds, orientation):
            return try film.recordSavedMovieClip(durationSeconds: seconds, orientation: orientation, at: date).sequenceNumber
        }
    }

    private func directory(_ filmID: UUID) throws -> URL {
        try repository.captureStagingDirectory(filmID: filmID).appendingPathComponent("ReceiptStudy")
    }
    private func manifestURL(_ operation: Operation) throws -> URL {
        try directory(operation.filmID).appendingPathComponent("\(operation.id).json")
    }
    private func mediaURL(_ operation: Operation) throws -> URL {
        let suffix = operation.kind == .photo ? "photo" : "mov"
        return try directory(operation.filmID).appendingPathComponent("\(operation.id).\(suffix)")
    }
    private func write(_ operation: Operation) throws {
        let url = try manifestURL(operation)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(operation).write(to: url, options: .atomic)
        try synchronize(url)
    }
    private func readOperation(filmID: UUID, id: UUID) throws -> Operation {
        let url = try directory(filmID).appendingPathComponent("\(id).json")
        let operation = try JSONDecoder().decode(Operation.self, from: Data(contentsOf: url))
        guard operation.filmID == filmID, operation.id == id else { throw StudyError.invalidOperation }
        return operation
    }
    private func removeMedia(_ operation: Operation) throws {
        let url = try mediaURL(operation)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    private func synchronize(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    static func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    // Actor reentrancy alone is not serialization across AVFoundation awaits.
    private func enter() async {
        if occupied { await withCheckedContinuation { waiters.append($0) } }
        else { occupied = true }
    }
    private func leave() {
        if waiters.isEmpty { occupied = false }
        else { waiters.removeFirst().resume() }
    }
}
