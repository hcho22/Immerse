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

/// Movies record a native 4:3 format, 3:4 once rotated for portrait, so clips in a Film's
/// locked orientation fill its 4:3 or 3:4 Movie frame and only opposite clips get borders.
public enum MovieCaptureFormat {
    /// Provisional pending DEC-04: no larger than the 1920x1080 `.high` preset Movies used before.
    public static let maximumWidth = 1920
    public static let maximumHeight = 1080

    /// The largest 4:3 format within the maximum size that records `MovieFrames.perSecond`.
    /// Dimensions are the sensor's landscape width and height.
    public static func preferred<Format>(
        among formats: [Format],
        dimensions: (Format) -> (width: Int, height: Int),
        recordsMovieFrameRate: (Format) -> Bool
    ) -> Format? {
        formats.filter { format in
            let size = dimensions(format)
            return size.width * 3 == size.height * 4 && size.width <= maximumWidth
                && size.height <= maximumHeight && recordsMovieFrameRate(format)
        }.max { dimensions($0).width < dimensions($1).width }
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
