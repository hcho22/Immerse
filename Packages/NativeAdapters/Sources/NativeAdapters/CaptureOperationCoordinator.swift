import FilmDomain
import Foundation

public enum NativeCaptureError: Error, Equatable, Sendable {
    case notRunning
    case busy
    case interrupted
    case wrongMediaKind
    case invalidDuration
    case invalidMedia
    case unsupportedConnection
    case configurationFailed
    case noPendingSave
}

public protocol CaptureSaveCommitting: Sendable {
    func commit(_ event: CaptureSaveEvent) async throws
}

struct CaptureOperationCoordinator {
    private(set) var phase: CapturePhase = .idle
    private(set) var operationID: UUID?
    private(set) var pendingSave: CaptureSaveEvent?
    private(set) var isInterrupted = false
    private(set) var isCommitting = false

    mutating func begin(_ media: CaptureMediaKind) throws -> UUID {
        try requireIdle()
        let id = UUID()
        operationID = id
        phase = media == .photo ? .savingPhoto : .recordingMovie
        return id
    }

    func requireIdle() throws {
        guard !isInterrupted else { throw NativeCaptureError.interrupted }
        guard operationID == nil else { throw NativeCaptureError.busy }
    }

    mutating func stopRecording() {
        if phase == .recordingMovie { phase = .savingMovieClip }
    }

    mutating func interrupt() {
        isInterrupted = true
        stopRecording()
        if operationID == nil { phase = .interrupted }
    }

    mutating func resumeSession() {
        isInterrupted = false
        if operationID == nil { phase = .idle }
    }

    mutating func stage(_ event: CaptureSaveEvent, id: UUID) -> Bool {
        guard operationID == id, pendingSave == nil else { return false }
        pendingSave = event
        if case .movieClipSaved = event { phase = .savingMovieClip }
        return true
    }

    mutating func beginCommit() throws -> (UUID, CaptureSaveEvent) {
        guard let operationID, let pendingSave else { throw NativeCaptureError.noPendingSave }
        guard !isCommitting else { throw NativeCaptureError.busy }
        isCommitting = true
        return (operationID, pendingSave)
    }

    mutating func commitFailed(id: UUID) {
        guard operationID == id else { return }
        isCommitting = false
    }

    mutating func finish(id: UUID) {
        guard operationID == id else { return }
        operationID = nil
        pendingSave = nil
        isCommitting = false
        phase = isInterrupted ? .interrupted : .idle
    }
}
