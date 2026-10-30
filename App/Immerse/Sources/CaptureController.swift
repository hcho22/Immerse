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
    /// The Zoom Steps the iPhone's rear camera offers, read from its camera list as the shooting screen appears, before
    /// any session starts and without asking for the camera, so the 6×6's strip keeps their room while they do not show,
    /// on the front camera or before a lens reports them. Empty on an iPhone with one rear lens, such as the iPhone SE.
    private(set) var rearZoomSteps: [ZoomStep] = []
    /// The scene is dim enough that the Disposable's fixed exposure would develop dark (`LowLightCue`).
    private(set) var isLowLight = false
    /// A permission note independent of transient camera errors, so an unavailable or interrupted camera cannot hide it.
    private(set) var microphoneUnavailable = false
    private var lowLightCue = LowLightCue()
    private var lightTask: Task<Void, Never>?
    /// Whether scene light reaches the cue: the viewfinder is live for a Camera that shows one.
    private var metersSceneLight = false
    var message: String?
    /// How many captures this controller has saved, so a screen can show "Saved" for a moment after each.
    private(set) var savedCount = 0
    /// The camera is stopped only to show an Instant print, so it starts again by itself when the last print and its
    /// question close, and the wait lasts until that restart's `open` ends. The app going inactive meanwhile (a
    /// permission prompt, Control Center) keeps it; any other stop (`suspend`, a real interruption, a failed save) ends it.
    private var resumesAfterReveal = false
    var flash = false
    var focus: Double = 0.8
    var exposure: Double = 0
    var orientation = CaptureFrameOrientation.portrait
    /// How the iPhone is held, which the shooting screen turns its words and icons to. Unlike `orientation`, it keeps
    /// following the iPhone while a clip records.
    private(set) var held = CaptureFrameOrientation.portrait
    var recordingStarted: Date?
    /// Whether the capture screen is on screen; the Journal alert cannot appear over it.
    var presented = false
    #if DEBUG
    fileprivate var heldForTesting: CaptureFrameOrientation?
    fileprivate var lensSetForTesting = false
    #endif

    init(authorizer: any CapturePermissionAuthorizing) { self.authorizer = authorizer }

    /// Whether a lens is running, so `controls` are what it reports: the viewfinder is live.
    var lensIsLive: Bool {
        #if DEBUG
        if lensSetForTesting { return true }
        #endif
        return preview != nil
    }

    /// The Disposable's viewfinder advises flash in low light, only when flash is available and still off:
    /// a cue for a control the active lens lacks would advise something it cannot do.
    var showsLowLightCue: Bool { isLowLight && controls.flash && !flash }

    /// The session a Film's Camera asks for: its capture behavior and the Focus control's position travel with the
    /// plan to the backend.
    static func sessionPlan(
        for film: Film, position: CapturePosition, focus: Double, capabilities: CaptureCapabilities
    ) -> CaptureSessionPlan {
        CaptureSessionPlan(request: CaptureSessionRequest(
            preferredPosition: position, mediaKind: film.camera.medium == .photo ? .photo : .movie,
            lockedMovieOrientation: film.movieOrientation,
            recordsLiveSound: film.camera.recordsLiveSound == true,
            behavior: .for(film.camera.id, focusSetting: film.effectiveFocusSetting),
            manualLensPosition: Float(focus)
        ), capabilities: capabilities)
    }

    func open(film: Film, model: JournalModel) async throws {
        guard !busy else { throw JournalError.operationInProgress }
        busy = true
        updateOrientation()
        microphoneUnavailable = false
        // iOS makes the app inactive while it asks for the camera or the microphone, which pauses the camera
        // (`pauseForInactiveScene`) and so ends any open that has already taken its session request. The questions come
        // first, so the answer leads straight on to the camera starting.
        let allowed = authorizer.authorizationStatus() == .authorized ? true : await authorizer.requestAccess()
        if allowed, film.camera.recordsLiveSound == true {
            let status = authorizer.microphoneAuthorizationStatus()
            let hasMicrophone: Bool
            if status == .notDetermined { hasMicrophone = await authorizer.requestMicrophoneAccess() }
            else { hasMicrophone = status == .authorized }
            microphoneUnavailable = !hasMicrophone
        }
        let request = sessionRequest
        defer {
            busy = false
            // Whatever stopped the camera during this open owns the wait for a print now.
            if request == sessionRequest { resumesAfterReveal = false }
        }
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
            #if DEBUG
            model.developedPreviews.cameraAttached(to: film)
            #endif
            read(sceneLight: next.sceneLight)
            eventsTask = Task { [weak self, weak model] in
                for await event in next.events {
                    guard !Task.isCancelled, let self, let model else { return }
                    await updatePhase(next)
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .photoSaved, .movieClipSaved:
                        recordingStarted = nil
                        message = "Saved"
                        savedCount += 1
                        model.refresh()
                        #if DEBUG
                        if let saved = model.film(film.id) { model.developedPreviews.captureSaved(saved) }
                        #endif
                        if film.camera.revealRule == .instantPerExposure {
                            model.developSavedPrint(film.id) { [weak self, weak model] text in
                                if self?.presented == true { self?.message = text } else { model?.alert = .failure(text) }
                            }
                        }
                    case .saveFailed:
                        resumesAfterReveal = false
                        recordingStarted = nil
                        message = "Capture could not finish saving. Retry before taking another capture."
                        model.refresh()
                    case .interrupted(let reason):
                        recordingStarted = nil
                        // A camera already stopped for a print is not interrupted by that stop or by the app going inactive.
                        if resumesAfterReveal && reason == .applicationInactive { break }
                        resumesAfterReveal = false
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
        let plan = Self.sessionPlan(for: film, position: position, focus: focus, capabilities: capabilities)
        try await backend.start(plan: plan)
        // A close requested during start stops the session after it on the backend's executor.
        guard request == sessionRequest else { return }
        watchSceneLight(behavior: plan.behavior)
        controls = await backend.controls()
        exposure = Double(controls.exposureBias)
        preview = await backend.previewSource()
        await updatePhase(backend)
        // The camera runs again, so a note that it was paused, left by the last close or an interruption, is over.
        message = nil
        if film.camera.recordsLiveSound == true,
           authorizer.microphoneAuthorizationStatus() != .authorized {
            microphoneUnavailable = true
        }
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
            if film.camera.recordsLiveSound == true {
                microphoneUnavailable = authorizer.microphoneAuthorizationStatus() != .authorized
            }
            try await backend.startMovie(orientation: orientation, remainingFrames: film.remainingMovieFrames ?? 0)
            recordingStarted = Date()
        }
        await updatePhase(backend)
    }

    func switchLens(film: Film) async throws {
        guard let backend else { return }
        let request = sessionRequest
        let next: CapturePosition = position == .rear ? .front : .rear
        try await backend.switchLens(to: next)
        position = next
        flash = false
        if request == sessionRequest {
            watchSceneLight(behavior: .for(film.camera.id, focusSetting: film.effectiveFocusSetting))
        }
        controls = await backend.controls()
        exposure = Double(controls.exposureBias)
    }

    func updateFocusSetting(for film: Film) async throws {
        guard let backend else { return }
        let phase = await backend.phase
        guard phase == .idle || phase == .recordingMovie else { return }
        try await backend.setFocusBehavior(.for(film.camera.id, focusSetting: film.effectiveFocusSetting))
    }

    func focus(at point: CGPoint, for film: Film) async throws -> FocusPointDecision {
        let behavior = CaptureBehavior.for(film.camera.id, focusSetting: film.effectiveFocusSetting)
        return try await backend?.focus(at: point, alsoExpose: behavior.exposure == .automatic) ?? .unsupported
    }

    /// Takes a zoom step on the 6×6, Super 8 or 16mm rear camera. Only between photo exposures or Recorded Clips.
    func selectZoomStep(_ step: ZoomStep) async throws {
        guard let backend else { return }
        try await backend.selectZoomStep(step)
        controls = await backend.controls()
        exposure = Double(controls.exposureBias)
    }

    /// The one reader of a backend's scene light. Readings reach the cue only while `metersSceneLight`.
    private func read(sceneLight readings: AsyncStream<Double>) {
        lightTask?.cancel()
        lightTask = Task { [weak self] in
            for await sceneEV100 in readings {
                guard !Task.isCancelled, let self else { return }
                guard self.metersSceneLight else { continue }
                self.lowLightCue.update(sceneEV100: sceneEV100)
                self.isLowLight = self.lowLightCue.isShowing
            }
        }
    }

    /// Starts the low-light cue afresh for a live viewfinder, for Cameras that show one.
    private func watchSceneLight(behavior: CaptureBehavior) {
        stopWatchingSceneLight()
        metersSceneLight = behavior.showsLowLightCue
    }

    private func stopWatchingSceneLight() {
        metersSceneLight = false
        lowLightCue = LowLightCue()
        isLowLight = false
    }

    func setFocus() async throws { try await backend?.setManualFocus(Float(focus)) }
    func setExposure() async throws { try await backend?.setExposureBias(Float(exposure)) }

    /// Whether a shooting screen's session is under way: between `beginShootingSession` and `endShootingSession`.
    private(set) var shootingSessionActive = false

    /// Starts a shooting screen's session: the iPhone's hold is read and followed, and the window held portrait. Only
    /// once, however often the screen appears behind the prints and questions it shows.
    func beginShootingSession() {
        guard !shootingSessionActive else { return }
        shootingSessionActive = true
        rearZoomSteps = AVFoundationCaptureDeviceDiscoverer().capabilities().rearLenses.zoomSteps
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        updateOrientation()
        presented = true
        InterfaceOrientationLock.hold(.portrait)
    }

    /// Ends the shooting screen's session exactly once, however the screen left: the camera stops, the hold is no longer
    /// read, and the window turns back to how the iPhone is held.
    func endShootingSession() {
        guard shootingSessionActive else { return }
        shootingSessionActive = false
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        presented = false
        suspend()
        InterfaceOrientationLock.release(turningTo: InterfaceOrientationLock.mask(held: held))
    }

    /// Stops the camera while an Instant print shows. Unlike `suspend`, it is meant to end: `printsClosed`.
    func pauseForReveal() {
        suspend()
        resumesAfterReveal = true
    }

    /// Whether the camera starts again now that the last print and its question are closed: only if `allowingRestart`
    /// and nothing else stopped it meanwhile. Otherwise the wait ends here; a restart keeps it until its `open` ends, so
    /// Resume Camera stays hidden while the camera starts.
    func printsClosed(allowingRestart: Bool) -> Bool {
        resumesAfterReveal = allowingRestart && resumesAfterReveal && presented && message?.contains("Retry") != true
        return resumesAfterReveal
    }

    /// Whether the capture screen offers Resume Camera: only while the Film is open, and then when the camera stopped
    /// for anything but an Instant print, the screen shows an error or a save needs a retry.
    func offersResume(for film: Film, showingError: Bool) -> Bool {
        film.completionState == .open
            && ((phase == .interrupted && !resumesAfterReveal) || showingError || message?.contains("Retry") == true)
    }

    /// The app went inactive (Control Center, a call, a permission prompt). A camera stopped only for an Instant print
    /// stays stopped and still starts again when the prints close; a running or starting camera is suspended.
    func pauseForInactiveScene() {
        if resumesAfterReveal && !busy { return }
        suspend()
    }

    func suspend() {
        resumesAfterReveal = false
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
        lightTask?.cancel()
        lightTask = nil
        backend = nil
        self.filmID = nil
        phase = .interrupted
        message = nil
        microphoneUnavailable = false
        recordingStarted = nil
    }

    /// A clip keeps the orientation it started in; every other capture uses how the iPhone is held now. The shooting
    /// screen's words and icons follow `held`, also while a clip records; its preview stays upright in the portrait
    /// interface it holds.
    func updateOrientation() {
        guard let reading = heldReading else { return }
        held = reading
        if phase != .recordingMovie { orientation = reading }
    }

    private var heldReading: CaptureFrameOrientation? {
        #if DEBUG
        if let heldForTesting { return heldForTesting }
        #endif
        return CaptureFrameOrientation(device: UIDevice.current.orientation)
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
}

#if DEBUG
extension CaptureController {
    /// Hosted tests cannot turn the iPhone, so they set how it is held.
    func hold(forTesting held: CaptureFrameOrientation) {
        heldForTesting = held
        updateOrientation()
    }

    /// Hosted tests have no backend, so they set the phase it would report.
    func setForTesting(phase: CapturePhase) { self.phase = phase }

    /// Hosted tests have no camera, so they set what a running lens would report.
    func setForTesting(controls: NativeCameraControls, sceneEV100: Double? = nil) {
        self.controls = controls
        lensSetForTesting = true
        if let sceneEV100 {
            lowLightCue.update(sceneEV100: sceneEV100)
            isLowLight = lowLightCue.isShowing
        }
    }

    /// Hosted tests have no camera list, so they set the Zoom Steps an iPhone's rear camera would offer.
    func setForTesting(rearZoomSteps: [ZoomStep]) { self.rearZoomSteps = rearZoomSteps }

    /// Stands in for attaching a backend's scene light.
    func attachForTesting(sceneLight: AsyncStream<Double>) { read(sceneLight: sceneLight) }

    /// Stands in for a session starting on a Camera with this behavior.
    func startForTesting(behavior: CaptureBehavior) { watchSceneLight(behavior: behavior) }
}
#endif
