import FilmDomain
import NativeAdapters
import Observation
import UIKit

@MainActor @Observable
final class CaptureController {
    private let authorizer: any CapturePermissionAuthorizing
    private var backend: AVFoundationCaptureBackend?
    private var eventsTask: Task<Void, Never>?
    /// Changes whenever the camera is closed, so an `open` that was still awaiting never
    /// starts a session after Done, an Instant print or a privacy removal.
    private var sessionRequest = 0
    private(set) var filmID: UUID?
    private(set) var preview: CapturePreviewSource?
    private(set) var position = CapturePosition.rear
    private(set) var phase = CapturePhase.interrupted
    private(set) var busy = false
    private(set) var controls = NativeCameraControls()
    /// The scene is dim enough that the Disposable's fixed exposure would develop dark (`LowLightCue`).
    private(set) var isLowLight = false
    private var lowLightCue = LowLightCue()
    private var lightTask: Task<Void, Never>?
    var message: String?
    var flash = false
    var focus: Double = 0.8
    var exposure: Double = 0
    var orientation = CaptureFrameOrientation.portrait
    var recordingStarted: Date?
    /// Whether the capture screen is on screen; the Journal alert cannot appear over it.
    var presented = false

    init(authorizer: any CapturePermissionAuthorizing) { self.authorizer = authorizer }

    /// The Disposable's viewfinder advises flash in low light, only when flash is available and still off:
    /// a cue for a control the active lens lacks would advise something it cannot do.
    var showsLowLightCue: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ImmerseForceLowLightCue") { return true }
        #endif
        return isLowLight && controls.flash && !flash
    }

    /// The session a Film's Camera asks for: its capture behavior travels with the plan to the backend.
    static func sessionPlan(for film: Film, position: CapturePosition, capabilities: CaptureCapabilities) -> CaptureSessionPlan {
        CaptureSessionPlan(request: CaptureSessionRequest(
            preferredPosition: position, mediaKind: film.camera.medium == .photo ? .photo : .movie,
            lockedMovieOrientation: film.movieOrientation, behavior: .for(film.camera.id)
        ), capabilities: capabilities)
    }

    func open(film: Film, model: JournalModel) async throws {
        guard !busy else { throw JournalError.operationInProgress }
        busy = true
        defer { busy = false }
        let request = sessionRequest
        updateOrientation()
        let allowed = authorizer.authorizationStatus() == .authorized ? true : await authorizer.requestAccess()
        guard allowed else {
            throw JournalError.cameraDenied
        }
        if filmID != film.id {
            let receiver = try await model.trial.receiver(filmID: film.id)
            let next = try AVFoundationCaptureBackend(stagingDirectory: model.repository.captureStagingDirectory(filmID: film.id), committer: receiver)
            if let backend {
                try await backend.finishPendingSaves()
                await backend.shutdown()
            }
            eventsTask?.cancel()
            backend = next
            filmID = film.id
            eventsTask = Task { [weak self, weak model] in
                for await event in next.events {
                    guard !Task.isCancelled, let self, let model else { return }
                    await updatePhase(next)
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .photoSaved, .movieClipSaved:
                        recordingStarted = nil
                        message = "Saved"
                        model.refresh()
                        if film.camera.revealRule == .instantPerExposure {
                            model.developSavedPrint(film.id) { [weak self, weak model] text in
                                if self?.presented == true { self?.message = text } else { model?.alert = .failure(text) }
                            }
                        }
                    case .saveFailed:
                        recordingStarted = nil
                        message = "Capture could not finish saving. Retry before taking another capture."
                        model.refresh()
                    case .interrupted:
                        recordingStarted = nil
                        message = "Camera paused. Saved captures are unchanged."
                    case .interruptionEnded: message = "Camera is available. Resume when ready."
                    }
                }
            }
        }
        guard let backend else { throw NativeCaptureError.notRunning }
        let currentPhase = await backend.phase
        if currentPhase == .savingPhoto || currentPhase == .savingMovieClip {
            try await backend.retryPendingSave()
        }
        try await backend.recoverPendingCaptures()
        try await model.trial.reconcile(filmID: film.id)
        model.refresh()
        guard model.film(film.id)?.completionState == .open, request == sessionRequest else { return }
        let capabilities = AVFoundationCaptureDeviceDiscoverer().capabilities()
        if !capabilities.isAvailable(position) { position = .rear }
        let plan = Self.sessionPlan(for: film, position: position, capabilities: capabilities)
        try await backend.start(plan: plan)
        // A close requested during start stops the session after it on the backend's executor.
        guard request == sessionRequest else { return }
        controls = await backend.controls()
        watchSceneLight(backend, behavior: plan.behavior)
        preview = await backend.previewSource()
        await updatePhase(backend)
        message = nil
    }

    func shutter(film: Film) async throws {
        guard let backend, !busy else { throw NativeCaptureError.notRunning }
        busy = true
        defer { busy = false }
        if phase == .recordingMovie {
            await backend.stopMovie()
        } else if film.camera.medium == .photo {
            try await backend.capturePhoto(orientation: orientation, flash: flash && controls.flash)
        } else {
            try await backend.startMovie(orientation: orientation, remainingFrames: film.remainingMovieFrames ?? 0)
            recordingStarted = Date()
        }
        await updatePhase(backend)
    }

    func switchLens(camera: CameraPackage) async throws {
        guard let backend else { return }
        let next: CapturePosition = position == .rear ? .front : .rear
        try await backend.switchLens(to: next)
        position = next
        flash = false
        controls = await backend.controls()
        watchSceneLight(backend, behavior: .for(camera.id))
    }

    /// Feeds the backend's scene light to the low-light cue for Cameras that show one.
    private func watchSceneLight(_ backend: AVFoundationCaptureBackend, behavior: CaptureBehavior) {
        stopWatchingSceneLight()
        guard behavior.showsLowLightCue else { return }
        let readings = backend.sceneLight
        lightTask = Task { [weak self] in
            for await sceneEV100 in readings {
                guard !Task.isCancelled, let self else { return }
                self.lowLightCue.update(sceneEV100: sceneEV100)
                self.isLowLight = self.lowLightCue.isShowing
            }
        }
    }

    private func stopWatchingSceneLight() {
        lightTask?.cancel()
        lightTask = nil
        lowLightCue = LowLightCue()
        isLowLight = false
    }

    func setFocus() async throws { try await backend?.setManualFocus(Float(focus)) }
    func setExposure() async throws { try await backend?.setExposureBias(Float(exposure)) }

    func suspend() {
        sessionRequest += 1
        preview = nil
        stopWatchingSceneLight()
        Task { await backend?.suspend(); await updatePhase(backend) }
    }

    func finishSaves(filmID: UUID) async throws {
        guard self.filmID == filmID else { return }
        sessionRequest += 1
        preview = nil
        stopWatchingSceneLight()
        try await backend?.finishPendingSaves()
        await updatePhase(backend)
    }

    func cancelForPrivacy(filmID: UUID) async throws {
        guard self.filmID == filmID else { return }
        sessionRequest += 1
        preview = nil
        stopWatchingSceneLight()
        try await backend?.cancelForPrivacy()
        eventsTask?.cancel()
        eventsTask = nil
        backend = nil
        self.filmID = nil
        phase = .interrupted
        message = nil
        recordingStarted = nil
    }

    /// A clip keeps the orientation it started in; every other capture uses how the iPhone is held now.
    func updateOrientation() {
        guard phase != .recordingMovie, let held = CaptureFrameOrientation(device: UIDevice.current.orientation) else { return }
        orientation = held
    }

    private func updatePhase(_ backend: AVFoundationCaptureBackend?) async {
        phase = await backend?.phase ?? .interrupted
        updateOrientation()
    }
}

extension CaptureFrameOrientation {
    /// Face-up, face-down and unknown keep the last held orientation.
    init?(device: UIDeviceOrientation) {
        switch device {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }

    /// The held orientation an interface orientation shows; their landscape names are swapped.
    init?(interface: UIInterfaceOrientation) {
        switch interface {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}

#if DEBUG
extension CaptureController {
    /// Hosted tests have no camera, so they set what a lens would report.
    func setForTesting(controls: NativeCameraControls, sceneEV100: Double? = nil) {
        self.controls = controls
        if let sceneEV100 {
            lowLightCue.update(sceneEV100: sceneEV100)
            isLowLight = lowLightCue.isShowing
        }
    }
}
#endif
