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
    var message: String?
    var flash = false
    var focus: Double = 0.8
    var exposure: Double = 0
    var orientation = CaptureFrameOrientation.portrait
    var recordingStarted: Date?

    init(authorizer: any CapturePermissionAuthorizing) { self.authorizer = authorizer }

    func open(film: Film, model: JournalModel) async throws {
        guard !busy else { throw JournalError.operationInProgress }
        busy = true
        defer { busy = false }
        let request = sessionRequest
        let allowed = authorizer.authorizationStatus() == .authorized ? true : await authorizer.requestAccess()
        guard allowed else {
            throw JournalError.cameraDenied
        }
        if filmID != film.id {
            if let backend {
                try await backend.finishPendingSaves()
                await backend.shutdown()
            }
            eventsTask?.cancel()
            let receiver = try await model.trial.receiver(filmID: film.id)
            let backend = try AVFoundationCaptureBackend(stagingDirectory: model.repository.captureStagingDirectory(filmID: film.id), committer: receiver)
            self.backend = backend
            filmID = film.id
            eventsTask = Task { [weak self, weak model] in
                for await event in backend.events {
                    guard !Task.isCancelled, let self, let model else { return }
                    phase = await backend.phase
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .photoSaved, .movieClipSaved:
                        recordingStarted = nil
                        message = "Saved"
                        model.refresh()
                        if film.camera.revealRule == .instantPerExposure { model.developSavedPrint(film.id) }
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
        let plan = CaptureSessionPlan(request: CaptureSessionRequest(preferredPosition: position,
            mediaKind: film.camera.medium == .photo ? .photo : .movie, lockedMovieOrientation: film.movieOrientation), capabilities: capabilities)
        try await backend.start(plan: plan)
        // A close requested during start stops the session after it on the backend's executor.
        guard request == sessionRequest else { return }
        controls = await backend.controls()
        if film.camera.id == .disposable1990s { try await backend.lockDisposableFocus() }
        preview = await backend.previewSource()
        phase = await backend.phase
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
            try await backend.startMovie(orientation: orientation, remainingSeconds: film.remainingMovieSeconds ?? 0)
            recordingStarted = Date()
        }
        phase = await backend.phase
    }

    func switchLens(camera: CameraPackage) async throws {
        guard let backend else { return }
        let next: CapturePosition = position == .rear ? .front : .rear
        try await backend.switchLens(to: next)
        position = next
        flash = false
        controls = await backend.controls()
        if camera.id == .disposable1990s { try await backend.lockDisposableFocus() }
    }

    func setFocus() async throws { try await backend?.setManualFocus(Float(focus)) }
    func setExposure() async throws { try await backend?.setExposureBias(Float(exposure)) }

    func suspend() {
        sessionRequest += 1
        preview = nil
        Task { await backend?.suspend(); phase = await backend?.phase ?? .interrupted }
    }

    func finishSaves(filmID: UUID) async throws {
        guard self.filmID == filmID else { return }
        sessionRequest += 1
        preview = nil
        try await backend?.finishPendingSaves()
        phase = await backend?.phase ?? .interrupted
    }

    func cancelForPrivacy(filmID: UUID) async throws {
        guard self.filmID == filmID else { return }
        sessionRequest += 1
        preview = nil
        try await backend?.cancelForPrivacy()
        eventsTask?.cancel()
        eventsTask = nil
        backend = nil
        self.filmID = nil
        phase = .interrupted
        message = nil
        recordingStarted = nil
    }

    func updateOrientation() {
        guard phase != .recordingMovie else { return }
        switch UIDevice.current.orientation {
        case .portrait: orientation = .portrait
        case .portraitUpsideDown: orientation = .portraitUpsideDown
        case .landscapeLeft: orientation = .landscapeLeft
        case .landscapeRight: orientation = .landscapeRight
        default: break
        }
    }
}
