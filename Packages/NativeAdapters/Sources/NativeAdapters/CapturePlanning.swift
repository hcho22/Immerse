import FilmDomain
import Foundation

/// How the iPhone is held, named like `UIDeviceOrientation`. In `landscapeLeft` the home
/// side is on the right, which is the camera sensors' native frame and needs no rotation.
public enum CaptureFrameOrientation: Equatable, Sendable {
    case portrait, portraitUpsideDown, landscapeLeft, landscapeRight

    /// The `AVCaptureConnection.videoRotationAngle` that shows this orientation upright.
    public var rotationAngle: CGFloat {
        switch self {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeLeft: 0
        case .landscapeRight: 180
        }
    }

    public var clipOrientation: ClipOrientation {
        switch self {
        case .portrait, .portraitUpsideDown: .portrait
        case .landscapeLeft, .landscapeRight: .landscape
        }
    }
}

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

/// Whether a zoom step can be taken now: only between photo exposures or Recorded Clips.
public enum ZoomDecision: Equatable, Sendable {
    case allowed
    /// The Camera has no zoom steps, or the active camera is the front one.
    case notOffered
    /// The iPhone does not have this step.
    case unavailable(ZoomStep)
    case blockedDuring(CapturePhase)
}

/// Whether an automatic-focus point can move to a tapped location now.
public enum FocusPointDecision: Equatable, Sendable {
    case allowed
    case notAutomatic
    case unsupported
    case blockedDuring(CapturePhase)
}

public struct CaptureSessionRequest: Equatable, Sendable {
    public let preferredPosition: CapturePosition
    public let mediaKind: CaptureMediaKind
    public let permissionPromptPolicy: PermissionPromptPolicy
    public let lockedMovieOrientation: MovieOrientation?
    public let behavior: CaptureBehavior
    /// Where `.manual` focus holds the lens (0 is closest, 1 furthest): the person's Focus control.
    public let manualLensPosition: Float

    public init(
        preferredPosition: CapturePosition,
        mediaKind: CaptureMediaKind,
        permissionPromptPolicy: PermissionPromptPolicy = .deferToFlowCoordinator,
        lockedMovieOrientation: MovieOrientation? = nil,
        behavior: CaptureBehavior = .deviceDefault,
        manualLensPosition: Float = FixedFocus.lensPosition
    ) {
        self.preferredPosition = preferredPosition
        self.mediaKind = mediaKind
        self.permissionPromptPolicy = permissionPromptPolicy
        self.lockedMovieOrientation = lockedMovieOrientation
        self.behavior = behavior
        self.manualLensPosition = manualLensPosition
    }
}

public struct CaptureSessionPlan: Equatable, Sendable {
    public let activePosition: CapturePosition
    public let mediaKind: CaptureMediaKind
    public let lockedMovieOrientation: MovieOrientation?
    public let behavior: CaptureBehavior
    public let manualLensPosition: Float
    private let capabilities: CaptureCapabilities

    public init(request: CaptureSessionRequest, capabilities: CaptureCapabilities) {
        self.activePosition = request.preferredPosition
        self.mediaKind = request.mediaKind
        self.lockedMovieOrientation = request.lockedMovieOrientation
        self.behavior = request.behavior
        self.manualLensPosition = request.manualLensPosition
        self.capabilities = capabilities
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

    /// The zoom steps this plan offers: the iPhone's own, on the rear camera of a Camera that zooms.
    public var zoomSteps: [ZoomStep] {
        behavior.offersZoomSteps && activePosition == .rear ? capabilities.rearLenses.zoomSteps : []
    }

    /// The step a session starts on and returns to: the wide lens as a whole, 1x.
    public var restingZoomStep: ZoomStep? {
        behavior.offersZoomSteps && activePosition == .rear ? capabilities.rearLenses.restingStep : nil
    }

    /// The same plan once the camera API has been read again for the rear lenses, which depend on the format the
    /// session's preset gave the wide lens.
    public func updatingRearLenses(_ lenses: RearLensCapabilities) -> CaptureSessionPlan {
        CaptureSessionPlan(
            request: CaptureSessionRequest(
                preferredPosition: activePosition, mediaKind: mediaKind, lockedMovieOrientation: lockedMovieOrientation,
                behavior: behavior, manualLensPosition: manualLensPosition
            ),
            capabilities: CaptureCapabilities(
                availablePositions: capabilities.availablePositions,
                supportsLensSwitchDuringSession: capabilities.supportsLensSwitchDuringSession, rearLenses: lenses
            )
        )
    }

    public func updatingBehavior(_ behavior: CaptureBehavior) -> CaptureSessionPlan {
        CaptureSessionPlan(
            request: CaptureSessionRequest(
                preferredPosition: activePosition, mediaKind: mediaKind, lockedMovieOrientation: lockedMovieOrientation,
                behavior: behavior, manualLensPosition: manualLensPosition
            ),
            capabilities: capabilities
        )
    }

    /// Tapping focuses in Auto. A live Movie keeps accepting focus points during recording; captures that are saving
    /// remain unchanged until the next idle or recording state.
    public func focusPointDecision(supported: Bool, during phase: CapturePhase) -> FocusPointDecision {
        guard behavior.focus == .deviceDefault else { return .notAutomatic }
        guard supported else { return .unsupported }
        return switch phase {
        case .idle, .recordingMovie: .allowed
        case .savingPhoto, .savingMovieClip, .interrupted: .blockedDuring(phase)
        }
    }

    public func zoomDecision(to step: ZoomStep, during phase: CapturePhase) -> ZoomDecision {
        guard !zoomSteps.isEmpty else { return .notOffered }
        guard zoomSteps.contains(step) else { return .unavailable(step) }
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
