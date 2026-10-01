import FilmDomain
import Foundation

public enum CapturePhase: Equatable, Sendable {
    case idle
    case savingPhoto
    case recordingMovie
    case savingMovieClip
    case interrupted
}

public enum LensSwitchDecision: Equatable, Sendable {
    case allowed
    case unavailable(CapturePosition)
    case blockedDuring(CapturePhase)
    case disabledByConfiguration
}

public struct CaptureSessionRequest: Equatable, Sendable {
    public let preferredPosition: CapturePosition
    public let mediaKind: CaptureMediaKind
    public let permissionPromptPolicy: PermissionPromptPolicy
    public let lockedMovieOrientation: MovieOrientation?

    public init(
        preferredPosition: CapturePosition,
        mediaKind: CaptureMediaKind,
        permissionPromptPolicy: PermissionPromptPolicy = .deferToFlowCoordinator,
        lockedMovieOrientation: MovieOrientation? = nil
    ) {
        self.preferredPosition = preferredPosition
        self.mediaKind = mediaKind
        self.permissionPromptPolicy = permissionPromptPolicy
        self.lockedMovieOrientation = lockedMovieOrientation
    }
}

public struct CaptureSessionPlan: Equatable, Sendable {
    public let activePosition: CapturePosition
    public let mediaKind: CaptureMediaKind
    public let recordsAudio: Bool
    public let lockedMovieOrientation: MovieOrientation?
    private let capabilities: CaptureCapabilities

    public init(request: CaptureSessionRequest, capabilities: CaptureCapabilities) {
        self.activePosition = request.preferredPosition
        self.mediaKind = request.mediaKind
        self.recordsAudio = false
        self.lockedMovieOrientation = request.lockedMovieOrientation
        self.capabilities = capabilities
    }

    public var viewfinderMirrored: Bool {
        activePosition == .front
    }

    public var outputMirrored: Bool {
        false
    }

    public func lensSwitchDecision(
        to target: CapturePosition,
        during phase: CapturePhase
    ) -> LensSwitchDecision {
        guard capabilities.supportsLensSwitchDuringSession else {
            return .disabledByConfiguration
        }
        guard capabilities.isAvailable(target) else {
            return .unavailable(target)
        }
        switch phase {
        case .idle:
            return .allowed
        case .savingPhoto, .recordingMovie, .savingMovieClip, .interrupted:
            return .blockedDuring(phase)
        }
    }
}

public enum NativeCaptureInterruptionReason: Equatable, Sendable {
    case systemPressure
    case audioVideoInUseByAnotherClient
    case videoDeviceNotAvailable
    case applicationInactive
    case runtimeFailure
    case unknown
}

public enum CaptureSaveEvent: Equatable, Sendable {
    case photoSaved(URL)
    case movieClipSaved(url: URL, durationSeconds: TimeInterval, orientation: ClipOrientation)
    case saveFailed(String)
    case interrupted(NativeCaptureInterruptionReason)
    case interruptionEnded
}

public protocol CaptureEventSink: Sendable {
    func receive(_ event: CaptureSaveEvent)
}

public struct CaptureEventEmitter<Sink: CaptureEventSink>: Sendable {
    private let sink: Sink

    public init(sink: Sink) {
        self.sink = sink
    }

    public func photoSaved(at url: URL) {
        sink.receive(.photoSaved(url))
    }

    public func movieClipSaved(at url: URL, durationSeconds: TimeInterval, orientation: ClipOrientation) {
        sink.receive(.movieClipSaved(url: url, durationSeconds: durationSeconds, orientation: orientation))
    }

    public func saveFailed(_ message: String) {
        sink.receive(.saveFailed(message))
    }

    public func interrupted(_ reason: NativeCaptureInterruptionReason) {
        sink.receive(.interrupted(reason))
    }

    public func interruptionEnded() {
        sink.receive(.interruptionEnded)
    }
}
