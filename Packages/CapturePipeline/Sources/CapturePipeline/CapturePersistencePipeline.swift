import FilmDomain
import FilmPersistence
import Foundation
import NativeAdapters

public enum CapturePipelineOutcome: Equatable {
    case photoCommitted(sequenceNumber: Int, remainingExposures: Int?)
    case movieClipCommitted(sequenceNumber: Int, remainingSeconds: Int?)
    case captureFailed(String)
    case interrupted(NativeCaptureInterruptionReason)
    case interruptionEnded
    case recovered
}

public enum CapturePipelineError: Error, Equatable {
    case unreadablePayload(String)
    case persistenceFailed(String)
}

public struct CapturePersistencePipeline<Reader: CapturePayloadReading> {
    private let filmID: UUID
    private let repository: FilmRepository
    private let reader: Reader

    public init(
        filmID: UUID,
        repository: FilmRepository,
        reader: Reader = FileCapturePayloadReader()
    ) {
        self.filmID = filmID
        self.repository = repository
        self.reader = reader
    }

    public func handle(_ event: CaptureSaveEvent) throws -> CapturePipelineOutcome {
        switch event {
        case let .photoSaved(url):
            return try persistPhoto(url)
        case let .movieClipSaved(url, durationSeconds, orientation):
            return try persistMovieClip(
                url: url,
                durationSeconds: durationSeconds,
                orientation: orientation
            )
        case let .saveFailed(message):
            return .captureFailed(message)
        case let .interrupted(reason):
            return .interrupted(reason)
        case .interruptionEnded:
            return .interruptionEnded
        }
    }

    public func recoverAfterLaunch() throws -> CapturePipelineOutcome {
        do {
            try repository.recover()
            return .recovered
        } catch {
            throw CapturePipelineError.persistenceFailed(String(describing: error))
        }
    }

    private func persistPhoto(_ url: URL) throws -> CapturePipelineOutcome {
        let payload = try read(url)
        do {
            let film = try repository.savePhotoCapture(filmID: filmID, sourceData: payload)
            guard let capture = film.captures.last else {
                throw CapturePipelineError.persistenceFailed("photo save returned no capture")
            }
            return .photoCommitted(
                sequenceNumber: capture.sequenceNumber,
                remainingExposures: film.remainingExposures
            )
        } catch let error as CapturePipelineError {
            throw error
        } catch {
            throw CapturePipelineError.persistenceFailed(String(describing: error))
        }
    }

    private func persistMovieClip(
        url: URL,
        durationSeconds: Int,
        orientation: ClipOrientation
    ) throws -> CapturePipelineOutcome {
        let payload = try read(url)
        do {
            let film = try repository.saveMovieClip(
                filmID: filmID,
                sourceData: payload,
                durationSeconds: durationSeconds,
                orientation: orientation
            )
            guard let capture = film.captures.last else {
                throw CapturePipelineError.persistenceFailed("movie save returned no capture")
            }
            return .movieClipCommitted(
                sequenceNumber: capture.sequenceNumber,
                remainingSeconds: film.remainingMovieSeconds
            )
        } catch let error as CapturePipelineError {
            throw error
        } catch {
            throw CapturePipelineError.persistenceFailed(String(describing: error))
        }
    }

    private func read(_ url: URL) throws -> Data {
        do {
            return try reader.data(for: url)
        } catch {
            throw CapturePipelineError.unreadablePayload(String(describing: error))
        }
    }
}
