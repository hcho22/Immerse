#if os(iOS)
@preconcurrency import AVFoundation
import Dispatch
import FilmDomain
import Foundation
import UIKit

public struct NativeCameraControls: Sendable {
    public var flash = false
    public var manualFocus = false
    public var fixedFocus = false
    public var supportsFocusPoint = false
    public var minimumExposureBias: Float?
    public var maximumExposureBias: Float?
    /// The bias the active lens's automatic exposure holds now, which the 6×6 exposure control shows.
    public var exposureBias: Float = 0
    /// Whether the active lens can hold the Disposable's custom exposure.
    public var fixedExposure = false
    /// The zoom steps the iPhone's own lenses give the 6×6, Super 8 or 16mm rear camera, empty where the Camera has none, the front
    /// camera is active or the iPhone has one rear lens, and the step the camera is on.
    public var zoomSteps: [ZoomStep] = []
    public var zoomStep: ZoomStep?
    public init() {}
}

// The reference is shared only with AVCaptureVideoPreviewLayer on the main actor.
// All session configuration and start/stop calls remain on the backend's serial executor.
public final class CapturePreviewSource: @unchecked Sendable {
    private let session: AVCaptureSession

    fileprivate init(session: AVCaptureSession) { self.session = session }

    @MainActor
    public func makeLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        return layer
    }

    /// `mirrored` reverses the viewfinder left to right (`CaptureBehavior.isViewfinderMirrored`). It is set on
    /// the preview layer's own connection, so saved photos and clips, which use their output connections, never change.
    @MainActor
    public func update(
        _ layer: AVCaptureVideoPreviewLayer,
        mirrored: Bool,
        orientation: CaptureFrameOrientation
    ) throws {
        guard layer.session === session, let connection = layer.connection,
              connection.isVideoRotationAngleSupported(orientation.rotationAngle),
              !mirrored || connection.isVideoMirroringSupported else {
            throw NativeCaptureError.unsupportedConnection
        }
        connection.videoRotationAngle = orientation.rotationAngle
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported { connection.isVideoMirrored = mirrored }
    }
}

public actor AVFoundationCaptureBackend {
    private nonisolated let queue = DispatchSerialQueue(label: "com.immerse.capture-session")
    public nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    public nonisolated let events: AsyncStream<CaptureSaveEvent>
    private let eventContinuation: AsyncStream<CaptureSaveEvent>.Continuation
    /// The scene's light value (`SceneLight.ev100`) as the viewfinder's automatic exposure reads it, for the
    /// Disposable's low-light cue. It is silent while a fixed exposure is held for a capture and while automatic
    /// exposure is still adjusting. It is one stream for the backend's life, so read it from one task.
    public nonisolated let sceneLight: AsyncStream<Double>
    private let sceneLightContinuation: AsyncStream<Double>.Continuation
    private var meter: SceneLightMeter?
    private var fixedExposureHeld = false
    /// Where `.manual` focus holds every lens of this session: the plan's, then wherever the person last set it.
    private var manualLensPosition = FixedFocus.lensPosition
    private let session = AVCaptureSession()
    private let files: CapturedMediaFiles
    private let committer: any CaptureSaveCommitting
    private var operations = CaptureOperationCoordinator()
    private var plan: CaptureSessionPlan?
    private var zoomStep: ZoomStep?
    private var input: AVCaptureDeviceInput?
    /// The microphone, attached only while a clip records (`attachMovieSound`), as the iPhone's Camera app does.
    private var audioInput: AVCaptureDeviceInput?
    /// The size the movie session records at, the wide lens's (`MovieCaptureFormat.preferred`): every zoom step's lens
    /// records exactly this size.
    private var movieFormatSize: (width: Int, height: Int)?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var photoDelegate: PhotoSaveDelegate?
    private var movieDelegate: MovieSaveDelegate?
    private let notifications = CaptureNotifications()
    private var privacyCancelled = false
    private var isRecovering = false
    public private(set) var retainedCommittedFiles: [CaptureSaveEvent] = []

    public init(stagingDirectory: URL, committer: any CaptureSaveCommitting) throws {
        self.files = try CapturedMediaFiles(directory: stagingDirectory)
        self.committer = committer
        (events, eventContinuation) = AsyncStream.makeStream()
        (sceneLight, sceneLightContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    public var phase: CapturePhase { operations.phase }
    public var activePosition: CapturePosition? { plan?.activePosition }
    public func previewSource() -> CapturePreviewSource { CapturePreviewSource(session: session) }

    public func controls() -> NativeCameraControls {
        var result = NativeCameraControls()
        guard let device = input?.device else { return result }
        result.flash = photoOutput?.supportedFlashModes.contains(.on) == true && device.hasFlash
        result.manualFocus = device.isLockingFocusWithCustomLensPositionSupported
        result.fixedFocus = device.isLockingFocusWithCustomLensPositionSupported || device.isFocusModeSupported(.locked)
        result.supportsFocusPoint = device.isFocusPointOfInterestSupported
            && (device.isFocusModeSupported(.continuousAutoFocus) || device.isFocusModeSupported(.autoFocus))
        if device.isExposureModeSupported(.continuousAutoExposure) {
            result.minimumExposureBias = device.minExposureTargetBias
            result.maximumExposureBias = device.maxExposureTargetBias
            result.exposureBias = device.exposureTargetBias
        }
        result.fixedExposure = device.isExposureModeSupported(.custom)
        result.zoomSteps = plan?.zoomSteps ?? []
        result.zoomStep = result.zoomSteps.isEmpty ? nil : zoomStep
        return result
    }

    public func setManualFocus(_ position: Float) throws {
        try operations.requireIdle()
        guard let device = input?.device, device.isLockingFocusWithCustomLensPositionSupported,
              position.isFinite, (0...1).contains(position) else { throw NativeCaptureError.configurationFailed }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.setFocusModeLocked(lensPosition: position)
        manualLensPosition = position
    }

    /// Applies a Film's Auto/Fixed/Manual choice to the active lens without changing exposure, zoom or output format.
    /// A focus mode can change between captures or while a Movie is being recorded.
    public func setFocusBehavior(_ behavior: CaptureBehavior) throws {
        guard session.isRunning, let device = input?.device, let plan else { return }
        guard behavior.viewfinder == plan.behavior.viewfinder,
              behavior.exposure == plan.behavior.exposure,
              behavior.offersZoomSteps == plan.behavior.offersZoomSteps else {
            throw NativeCaptureError.configurationFailed
        }
        switch operations.phase {
        case .idle, .recordingMovie:
            break
        case .savingPhoto, .savingMovieClip, .interrupted:
            throw NativeCaptureError.busy
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        Self.applyFocusBehavior(behavior.focus, manualLensPosition: manualLensPosition, to: device)
        self.plan = plan.updatingBehavior(behavior)
    }

    /// Tap-to-focus is supported in Auto. Movie recording accepts tap adjustments; saves and interruptions defer them.
    /// A point converted from a tap at the very edge of the picture can fall a little outside it, so it is kept inside.
    /// Once the scene the point was on changes, focus and metering return to the centre (`subjectAreaChanged`).
    public func focus(at tapped: CGPoint, alsoExpose: Bool) throws -> FocusPointDecision {
        guard session.isRunning, let device = input?.device, let plan else { return .unsupported }
        guard tapped.x.isFinite, tapped.y.isFinite else { throw NativeCaptureError.configurationFailed }
        let point = CGPoint(x: min(max(tapped.x, 0), 1), y: min(max(tapped.y, 0), 1))
        let phase = operations.phase
        let focusSupported = device.isFocusPointOfInterestSupported
            && (device.isFocusModeSupported(.continuousAutoFocus) || device.isFocusModeSupported(.autoFocus))
        let decision = plan.focusPointDecision(supported: focusSupported, during: phase)
        let exposureSupported = alsoExpose && [.idle, .recordingMovie].contains(phase)
            && device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure)
        guard decision == .allowed || exposureSupported else { return decision }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if decision == .allowed {
            device.focusPointOfInterest = point
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
        }
        if exposureSupported {
            device.exposurePointOfInterest = point
            device.exposureMode = .continuousAutoExposure
        }
        device.isSubjectAreaChangeMonitoringEnabled = true
        return decision
    }

    public func setExposureBias(_ bias: Float) throws {
        try operations.requireIdle()
        guard let device = input?.device, device.isExposureModeSupported(.continuousAutoExposure),
              bias.isFinite, (device.minExposureTargetBias...device.maxExposureTargetBias).contains(bias) else {
            throw NativeCaptureError.configurationFailed
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.exposureMode = .continuousAutoExposure
        device.setExposureTargetBias(bias)
    }

    public func start(plan next: CaptureSessionPlan) throws {
        guard !privacyCancelled, !isRecovering else { throw NativeCaptureError.notRunning }
        guard try files.pendingRecords().isEmpty else { throw NativeCaptureError.pendingRecoveryRequired }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw NativeCaptureError.notRunning
        }
        guard operations.operationID == nil else { throw NativeCaptureError.busy }
        guard next.mediaKind != .movie || next.lockedMovieOrientation != nil,
              (0...1).contains(next.manualLensPosition) else {
            throw NativeCaptureError.configurationFailed
        }
        if session.isRunning { session.stopRunning() }
        manualLensPosition = next.manualLensPosition
        try configure(next)
        restartMeter()
        installNotificationsIfNeeded()
        session.startRunning()
        guard session.isRunning else { throw NativeCaptureError.notRunning }
        refreshRearLenses()
        operations.resumeSession()
    }

    public func switchLens(to position: CapturePosition) throws {
        try operations.requireIdle()
        guard session.isRunning, let plan else { throw NativeCaptureError.notRunning }
        guard plan.lensSwitchDecision(to: position, during: operations.phase) == .allowed else {
            throw NativeCaptureError.configurationFailed
        }
        try replaceInput(with: camera(at: position), plan: plan, movieSize: nil)
        self.plan = CaptureSessionPlan(
            request: CaptureSessionRequest(
                preferredPosition: position, mediaKind: plan.mediaKind,
                lockedMovieOrientation: plan.lockedMovieOrientation, recordsLiveSound: plan.recordsLiveSound,
                behavior: plan.behavior,
                manualLensPosition: manualLensPosition
            ),
            capabilities: AVFoundationCaptureDeviceDiscoverer().capabilities()
        )
        refreshRearLenses()
        restartMeter()
    }

    /// Takes a zoom step of the iPhone's own lenses (the 6×6, Super 8 or 16mm rear camera): changes to that lens, and crops it where the
    /// step is a native sensor crop. Only between exposures, the rule of a lens switch. The person's Focus position and
    /// exposure bias go with them to the new lens, the bias within that lens's range. A lens runs on the format the session
    /// gives it only once it is the input, and that format decides its native crops, so they are read again then. A crop
    /// that format does not report would be a digital enlargement, so it is refused: the camera returns to the step it was
    /// on, and the read leaves the crop out of the steps offered.
    public func selectZoomStep(_ step: ZoomStep) throws {
        try operations.requireIdle()
        guard session.isRunning, var plan, let active = input?.device else { throw NativeCaptureError.notRunning }
        guard plan.zoomDecision(to: step, during: operations.phase) == .allowed else {
            throw NativeCaptureError.configurationFailed
        }
        guard step != zoomStep else { return }
        let device = try camera(for: step.lens)
        let bias = active.exposureTargetBias
        if device !== active {
            try replaceInput(with: device, plan: plan, movieSize: movieFormatSize)
            plan = plan.updatingRearLenses(offeredRearLenses(for: plan))
            self.plan = plan
            guard plan.zoomDecision(to: step, during: operations.phase) == .allowed else {
                try replaceInput(with: active, plan: plan, movieSize: movieFormatSize)
                try applyLensBehavior(plan.behavior, to: active, zoomFactor: zoomStep?.lensZoomFactor ?? 1)
                restartMeter()
                return
            }
        }
        try applyLensBehavior(plan.behavior, to: device, zoomFactor: step.lensZoomFactor, carryingExposureBias: bias)
        zoomStep = step
        restartMeter()
    }

    /// Replaces the session's camera with `device`, keeping its outputs, and holds the Camera's behavior on it. The movie
    /// session runs at `.inputPriority`, so the added lens keeps the format chosen here: exactly `movieSize` for a zoom
    /// step, so every step records the wide lens's size, and the camera's own largest for a switch between cameras.
    private func replaceInput(with device: AVCaptureDevice, plan: CaptureSessionPlan, movieSize: (width: Int, height: Int)?) throws {
        if plan.mediaKind == .movie { try selectMovieFormat(device, size: movieSize) }
        let replacement = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if let input { session.removeInput(input) }
        guard session.canAddInput(replacement) else {
            if let input, session.canAddInput(input) { session.addInput(input) }
            throw NativeCaptureError.configurationFailed
        }
        session.addInput(replacement)
        input = replacement
        ensureUnmirroredOutput()
        try applyLensBehavior(plan.behavior, to: device)
    }

    /// Reads the rear lenses again once the session runs on its preset's format, and returns the zoom to 1x: the rear wide
    /// lens is the only camera a session starts or switches to. Needs a running session, since a lens's native crops
    /// depend on its active format.
    private func refreshRearLenses() {
        guard let current = plan else { return }
        plan = current.updatingRearLenses(offeredRearLenses(for: current))
        zoomStep = plan?.restingZoomStep
    }

    /// The rear lenses as the iPhone reports them, less, on a movie Camera, each lens that cannot record the wide lens's
    /// movie size at the movie frame rate (FR-26 item 4).
    private func offeredRearLenses(for plan: CaptureSessionPlan) -> RearLensCapabilities {
        let lenses = AVFoundationCaptureDeviceDiscoverer.rearLenses()
        guard plan.mediaKind == .movie else { return lenses }
        return MovieCaptureFormat.lensesRecordingTheWideLensFormat(
            lenses, formats: { lens in (try? self.camera(for: lens)).map(Self.movieFormats) ?? [] },
            dimensions: Self.dimensions, recordsMovieFrameRate: Self.recordsMovieFrameRate
        )
    }

    public func capturePhoto(orientation: CaptureFrameOrientation, flash: Bool = false) async throws {
        guard session.isRunning, let photoOutput else { throw NativeCaptureError.notRunning }
        try operations.requireIdle()
        guard !isRecovering, try files.pendingRecords().isEmpty else { throw NativeCaptureError.pendingRecoveryRequired }
        try configureConnection(photoOutput.connection(with: .video), orientation: orientation)
        let settings = AVCapturePhotoSettings()
        if flash {
            guard photoOutput.supportedFlashModes.contains(.on) else {
                throw NativeCaptureError.configurationFailed
            }
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        let holdsFixedExposure = plan?.behavior.exposure == .fixed && input?.device.isExposureModeSupported(.custom) == true
        if holdsFixedExposure { settings.photoQualityPrioritization = .speed }
        let id = try operations.begin(.photo)
        do { try files.prepare(PendingCaptureRecord(id: id, mediaKind: .photo)) }
        catch { operations.finish(id: id); throw error }
        if holdsFixedExposure, let device = input?.device {
            // The operation is open, so no other capture, lens switch or recovery can start while this waits.
            do {
                try await holdFixedExposure(on: device)
                guard session.isRunning, !operations.isInterrupted, !privacyCancelled else {
                    throw NativeCaptureError.interrupted
                }
            } catch {
                releaseFixedExposure()
                try? files.removeUncommitted(id: id)
                operations.finish(id: id)
                throw error
            }
        }
        let delegate = PhotoSaveDelegate { [weak self] data, failed in
            Task { await self?.photoFinished(id: id, data: data, failed: failed) }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    public func startMovie(orientation: CaptureFrameOrientation, remainingFrames: Int) async throws {
        guard session.isRunning, let movieOutput else { throw NativeCaptureError.notRunning }
        guard remainingFrames > 0 else {
            throw NativeCaptureError.invalidDuration
        }
        try operations.requireIdle()
        guard !isRecovering, try files.pendingRecords().isEmpty else { throw NativeCaptureError.pendingRecoveryRequired }
        await attachMovieSound()
        let id: UUID
        do {
            // The wait for the microphone let other work in: the camera may have paused or a capture begun meanwhile.
            guard session.isRunning else { throw NativeCaptureError.notRunning }
            try operations.requireIdle()
            try configureConnection(movieOutput.connection(with: .video), orientation: orientation)
            id = try operations.begin(.movie)
        } catch { detachMovieSound(); throw error }
        do {
            try files.prepare(PendingCaptureRecord(id: id, mediaKind: .movie,
                orientation: orientation.clipOrientation, remainingFrames: remainingFrames,
                allowsAudio: plan?.recordsLiveSound == true))
        } catch { operations.finish(id: id); detachMovieSound(); throw error }
        movieOutput.maxRecordedDuration = CMTime(value: CMTimeValue(remainingFrames), timescale: CMTimeScale(MovieFrames.perSecond))
        movieOutput.metadata = input.flatMap { Self.sceneWhiteBalanceItem($0.device) }.map { [$0] }
        let allowsAudio = plan?.recordsLiveSound == true
        let delegate = MovieSaveDelegate { [weak self] successfullyFinished in
            Task {
                await self?.movieFinished(
                    id: id, orientation: orientation.clipOrientation,
                    remainingFrames: remainingFrames, allowsAudio: allowsAudio,
                    successfullyFinished: successfullyFinished
                )
            }
        }
        movieDelegate = delegate
        movieOutput.startRecording(to: files.movieDestination(id: id), recordingDelegate: delegate)
    }

    /// Attaches the microphone for one clip, as the iPhone's Camera app does: only while a clip records is the microphone
    /// in use and other audio interrupted, and a call or another app's recording between clips leaves the viewfinder
    /// running. The system grant is read for each clip, so returning from Settings changes the next clip without changing
    /// the Film's locked sound capability or asking again; a missing grant or route records the clip silent. The clip
    /// starts only once the microphone's connection is live, at most half a second later, so its first moments carry
    /// sound.
    private func attachMovieSound() async {
        detachMovieSound()
        guard let plan, plan.mediaKind == .movie, plan.recordsLiveSound,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
              let device = AVCaptureDevice.default(for: .audio),
              let microphone = try? AVCaptureDeviceInput(device: device) else { return }
        // The iPhone's Camera app records stereo where the phone can (DEC-19); an input records one channel by default.
        if microphone.isMultichannelAudioModeSupported(.stereo) { microphone.multichannelAudioMode = .stereo }
        session.beginConfiguration()
        guard session.canAddInput(microphone) else { session.commitConfiguration(); return }
        session.addInput(microphone)
        audioInput = microphone
        pinMovieSoundFormat()
        session.commitConfiguration()
        let deadline = ContinuousClock.now + .milliseconds(500)
        while movieOutput?.connection(with: .audio)?.isActive != true, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// The Camera app's sound format, AAC at 48 kHz (DEC-19), where the output lets it be set; the channels stay the
    /// microphone's, stereo where `attachMovieSound` could ask for it. Every other setting stays the output's own.
    private func pinMovieSoundFormat() {
        guard let movieOutput, let connection = movieOutput.connection(with: .audio) else { return }
        let keys = movieOutput.supportedOutputSettingsKeys(for: connection)
        guard keys.contains(AVFormatIDKey) else { return }
        var settings = movieOutput.outputSettings(for: connection)
        settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        if keys.contains(AVSampleRateKey) { settings[AVSampleRateKey] = 48_000 }
        movieOutput.setOutputSettings(settings, for: connection)
    }

    /// Lets the microphone go once a clip ends, or the camera pauses, and gives the sound back to other apps: music the
    /// clip paused plays again, as it does after the iPhone's Camera app records.
    private func detachMovieSound() {
        guard let audioInput else { return }
        session.beginConfiguration()
        session.removeInput(audioInput)
        session.commitConfiguration()
        self.audioInput = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The light the clip starts in, as the lens's white balance judges it, for a Film Stock with a fixed color
    /// balance to develop against. The viewfinder and the recording keep the phone's automatic white balance. Nil
    /// when a gain is outside the range the lens converts, 1 to its largest gain: the clip then carries no record and
    /// develops with the phone's balance.
    private static func sceneWhiteBalanceItem(_ device: AVCaptureDevice) -> AVMetadataItem? {
        let gains = device.deviceWhiteBalanceGains
        guard [gains.redGain, gains.greenGain, gains.blueGain].allSatisfy({ $0 >= 1 && $0 <= device.maxWhiteBalanceGain }) else {
            return nil
        }
        let values = device.temperatureAndTintValues(for: gains)
        let item = AVMutableMetadataItem()
        item.keySpace = .quickTimeMetadata
        item.key = SceneWhiteBalance.metadataKey as NSString
        item.value = SceneWhiteBalance(temperature: Double(values.temperature), tint: Double(values.tint)).metadataValue as NSString
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        return item
    }

    public func stopMovie() {
        operations.stopRecording()
        if movieOutput?.isRecording == true { movieOutput?.stopRecording() }
    }

    public func suspend(reason: NativeCaptureInterruptionReason = .applicationInactive) {
        operations.interrupt()
        releaseFixedExposure()
        if movieOutput?.isRecording == true { movieOutput?.stopRecording() }
        if session.isRunning { session.stopRunning() }
        detachMovieSound()
        eventContinuation.yield(.interrupted(reason))
    }

    public func retryPendingSave() async throws {
        let (id, event) = try operations.beginCommit()
        guard !privacyCancelled else {
            defer { operations.finish(id: id) }
            try files.removeUncommitted(id: id)
            return
        }
        do {
            try await committer.commit(event)
        } catch {
            operations.commitFailed(id: id)
            eventContinuation.yield(.saveFailed("persistenceFailed; staged capture retained"))
            throw error
        }
        do { try files.removeCommittedFile(for: event) }
        catch { retainedCommittedFiles.append(event) }
        operations.finish(id: id)
        eventContinuation.yield(event)
    }

    public func recoverPendingCaptures() async throws {
        guard !privacyCancelled, !isRecovering, operations.operationID == nil else { throw NativeCaptureError.busy }
        isRecovering = true
        defer { isRecovering = false }
        for event in try await files.recoveryEvents() {
            guard !privacyCancelled else { throw CancellationError() }
            try await committer.commit(event)
            try files.removeCommittedFile(for: event)
            eventContinuation.yield(event)
        }
    }

    public func finishPendingSaves() async throws {
        suspend()
        let deadline = ContinuousClock.now + .seconds(30)
        while operations.operationID != nil {
            if operations.pendingSave != nil, !operations.isCommitting {
                try await retryPendingSave()
            } else {
                guard ContinuousClock.now < deadline else { throw NativeCaptureError.busy }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        try await recoverPendingCaptures()
    }

    public func cancelForPrivacy() async throws {
        privacyCancelled = true
        shutdown()
        let deadline = ContinuousClock.now + .seconds(30)
        while operations.operationID != nil || isRecovering {
            if let id = operations.operationID, operations.pendingSave != nil, !operations.isCommitting {
                try files.removeUncommitted(id: id)
                operations.finish(id: id)
            } else {
                guard ContinuousClock.now < deadline else { throw NativeCaptureError.busy }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        for record in try files.pendingRecords() { try files.removeUncommitted(id: record.id) }
    }

    public func shutdown() {
        suspend()
        meter = nil
        notifications.removeAll()
        // Pending save delegates retain their file until commit; shutdown never discards it.
    }

    private func configure(_ next: CaptureSessionPlan) throws {
        let newInput = try AVCaptureDeviceInput(device: camera(at: next.activePosition))
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for old in session.inputs { session.removeInput(old) }
        for old in session.outputs { session.removeOutput(old) }
        session.automaticallyConfiguresApplicationAudioSession = next.mediaKind == .movie && next.recordsLiveSound
        photoOutput = nil
        movieOutput = nil
        input = nil
        audioInput = nil
        plan = nil
        guard session.canAddInput(newInput) else { throw NativeCaptureError.configurationFailed }
        // The Camera remains the only video input; a new movie Film's microphone joins it only while a clip records.
        session.addInput(newInput)
        input = newInput
        plan = next
        if next.mediaKind == .photo {
            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else { throw NativeCaptureError.configurationFailed }
            if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
            session.addOutput(output)
            // A frame from before the custom exposure took effect must never become the exposure.
            if next.behavior.exposure == .fixed, output.isZeroShutterLagSupported { output.isZeroShutterLagEnabled = false }
            photoOutput = output
        } else {
            let output = AVCaptureMovieFileOutput()
            guard session.canAddOutput(output) else { throw NativeCaptureError.configurationFailed }
            // Choosing the input's format switches the session to its `.inputPriority` preset.
            movieFormatSize = nil
            try selectMovieFormat(newInput.device)
            session.addOutput(output)
            movieOutput = output
        }
        ensureUnmirroredOutput()
        try applyLensBehavior(next.behavior, to: newInput.device)
    }

    /// Holds the lens in the Camera's focus and exposure behavior. `.fixed` focus locks the fixed lens position and
    /// `.manual` focus the person's (`manualLensPosition`), wherever the lens supports it; every other mode returns to
    /// the continuous, unbiased automatic default, except `.manualBias`, whose lens takes `carryingExposureBias`
    /// (`CaptureBehavior.lensExposureBias`) or, with none, keeps the bias it holds.
    private func applyLensBehavior(
        _ behavior: CaptureBehavior, to device: AVCaptureDevice, zoomFactor: Double = 1, carryingExposureBias: Float? = nil
    ) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        // A lens keeps its zoom between sessions and Cameras, so every lens starts at its own zoom factor, 1 unless the
        // 6×6's step is a native crop.
        let zoom = min(max(CGFloat(zoomFactor), device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        if device.videoZoomFactor != zoom { device.videoZoomFactor = zoom }
        if device.isExposureModeSupported(.continuousAutoExposure), let bias = behavior.lensExposureBias(
            carrying: carryingExposureBias, within: device.minExposureTargetBias...device.maxExposureTargetBias
        ) {
            // A fixed exposure is held per capture, so the viewfinder always meters automatically.
            if device.exposureMode != .continuousAutoExposure { device.exposureMode = .continuousAutoExposure }
            if device.exposureTargetBias != bias { device.setExposureTargetBias(bias) }
        }
        // A point tapped on another Film, Camera or lens never carries over: every lens starts at the centre.
        if !fixedExposureHeld { Self.recentre(device) }
        Self.applyFocusBehavior(behavior.focus, manualLensPosition: manualLensPosition, to: device)
    }

    /// Returns focus and metering to the centre of the picture and stops watching for a changed scene, as the iPhone's
    /// Camera app does once the scene a tap chose changes. The automatic modes are set again so the point takes effect;
    /// a locked focus is left locked. Call with the device locked for configuration.
    private static func recentre(_ device: AVCaptureDevice) {
        let centre = CGPoint(x: 0.5, y: 0.5)
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = centre
            if device.focusMode == .continuousAutoFocus { device.focusMode = .continuousAutoFocus }
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = centre
            if device.exposureMode == .continuousAutoExposure { device.exposureMode = .continuousAutoExposure }
        }
        device.isSubjectAreaChangeMonitoringEnabled = false
    }

    /// The scene a tapped point was on has changed: focus and metering return to the centre.
    private func subjectAreaChanged(deviceID: String?) {
        guard let device = input?.device, device.uniqueID == deviceID, !fixedExposureHeld,
              (try? device.lockForConfiguration()) != nil else { return }
        Self.recentre(device)
        device.unlockForConfiguration()
    }

    private static func applyFocusBehavior(
        _ behavior: FocusBehavior, manualLensPosition: Float, to device: AVCaptureDevice
    ) {
        switch behavior {
        case .fixed:
            if device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: FixedFocus.lensPosition)
            } else if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }
        case .deviceDefault:
            if device.focusMode != .continuousAutoFocus, device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if !device.isFocusModeSupported(.continuousAutoFocus),
                      device.focusMode != .autoFocus, device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
        case .manual:
            if device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: manualLensPosition)
            }
        }
    }

    private func restartMeter() {
        meter = nil
        guard plan?.behavior.showsLowLightCue == true, let device = input?.device else { return }
        let continuation = sceneLightContinuation
        meter = SceneLightMeter(device: device) { continuation.yield($0) }
    }

    /// Applies the Disposable's fixed exposure and returns once the lens reports it in effect.
    private func holdFixedExposure(on device: AVCaptureDevice) async throws {
        let format = device.activeFormat
        let exposure = FixedExposure.settings(
            aperture: Double(device.lensAperture), isoRange: format.minISO...format.maxISO,
            durationRange: format.minExposureDuration.seconds...format.maxExposureDuration.seconds
        )
        try device.lockForConfiguration()
        fixedExposureHeld = true
        meter?.isPaused = true
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            device.setExposureModeCustom(
                duration: CMTime(seconds: exposure.duration, preferredTimescale: 1_000_000_000), iso: exposure.iso
            ) { _ in once.resume() }
            device.unlockForConfiguration()
            // The handler is documented to run, but a capture must never wait on it forever.
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { once.resume() }
        }
    }

    /// Returns the viewfinder to automatic exposure after a capture, an interruption or a failure.
    private func releaseFixedExposure() {
        guard fixedExposureHeld else { return }
        fixedExposureHeld = false
        if let device = input?.device, device.isExposureModeSupported(.continuousAutoExposure),
           (try? device.lockForConfiguration()) != nil {
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
        }
        meter?.isPaused = false
    }

    /// Sets `device`'s movie format: the largest 4:3 one the session allows (`MovieCaptureFormat.preferred`) on the lens
    /// a session starts on, which sets `movieFormatSize`, and exactly `size` on a zoom step's lens.
    private func selectMovieFormat(_ device: AVCaptureDevice, size: (width: Int, height: Int)? = nil) throws {
        let formats = Self.movieFormats(of: device)
        let chosen = if let size {
            MovieCaptureFormat.matching(size, among: formats, dimensions: Self.dimensions,
                                        recordsMovieFrameRate: Self.recordsMovieFrameRate)
        } else {
            MovieCaptureFormat.preferred(among: formats, dimensions: Self.dimensions,
                                         recordsMovieFrameRate: Self.recordsMovieFrameRate)
        }
        guard let format = chosen else { throw NativeCaptureError.configurationFailed }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.activeFormat = format
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(MovieFrames.perSecond))
        if size == nil { movieFormatSize = Self.dimensions(format) }
    }

    /// A lens's formats a movie can record from: the 420v ones.
    private static func movieFormats(of device: AVCaptureDevice) -> [AVCaptureDevice.Format] {
        device.formats.filter {
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
    }

    private static func dimensions(_ format: AVCaptureDevice.Format) -> (width: Int, height: Int) {
        let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        return (Int(size.width), Int(size.height))
    }

    private static func recordsMovieFrameRate(_ format: AVCaptureDevice.Format) -> Bool {
        let rate = Float64(MovieFrames.perSecond)
        return format.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= rate && rate <= $0.maxFrameRate }
    }

    private func camera(for lens: RearLens) throws -> AVCaptureDevice {
        let type: AVCaptureDevice.DeviceType
        switch lens {
        case .ultraWide: type = .builtInUltraWideCamera
        case .wide: type = .builtInWideAngleCamera
        case .telephoto: type = .builtInTelephotoCamera
        }
        guard let camera = AVCaptureDevice.default(type, for: .video, position: .back) else {
            throw NativeCaptureError.configurationFailed
        }
        return camera
    }

    private func camera(at position: CapturePosition) throws -> AVCaptureDevice {
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: position == .front ? .front : .back
        ) else { throw NativeCaptureError.configurationFailed }
        return camera
    }

    private func configureConnection(_ connection: AVCaptureConnection?, orientation: CaptureFrameOrientation) throws {
        guard let connection, connection.isVideoRotationAngleSupported(orientation.rotationAngle) else {
            throw NativeCaptureError.unsupportedConnection
        }
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported { connection.isVideoMirrored = false }
        connection.videoRotationAngle = orientation.rotationAngle
    }

    private func ensureUnmirroredOutput() {
        for output in session.outputs {
            if let connection = output.connection(with: .video) {
                connection.automaticallyAdjustsVideoMirroring = false
                if connection.isVideoMirroringSupported { connection.isVideoMirrored = false }
            }
        }
    }

    private func photoFinished(id: UUID, data: Data?, failed: Bool) async {
        releaseFixedExposure()
        guard operations.operationID == id, operations.pendingSave == nil else { return }
        photoDelegate = nil
        if privacyCancelled { operations.finish(id: id); return }
        guard !failed, let data else { failCapture(id: id); return }
        do {
            let url = try files.savePhoto(data, id: id)
            guard operations.stage(.photoSaved(url), id: id) else { return }
        } catch { failCapture(id: id); return }
        try? await retryPendingSave()
    }

    private func movieFinished(
        id: UUID, orientation: ClipOrientation, remainingFrames: Int, allowsAudio: Bool,
        successfullyFinished: Bool
    ) async {
        detachMovieSound()
        guard operations.operationID == id, operations.pendingSave == nil else { return }
        movieDelegate = nil
        if privacyCancelled { operations.finish(id: id); return }
        operations.stopRecording()
        // Interrupted recordings can carry an error with a successfully-finished file.
        // Even an unsuccessful callback may have salvageable footage: validate the actual file.
        do {
            let event = try await files.movieSavedEvent(
                id: id, orientation: orientation, remainingFrames: remainingFrames, allowsAudio: allowsAudio
            )
            if privacyCancelled { operations.finish(id: id); return }
            guard operations.stage(event, id: id) else { return }
        } catch { failCapture(id: id); return }
        try? await retryPendingSave()
    }

    private func failCapture(id: UUID) {
        operations.finish(id: id)
        eventContinuation.yield(.saveFailed("captureFileUnavailableOrInvalid"))
    }

    private func installNotificationsIfNeeded() {
        guard notifications.isEmpty else { return }
        notifications.observe(AVCaptureSession.wasInterruptedNotification, object: session) { [weak self] notification in
            let raw = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue
            let reason: NativeCaptureInterruptionReason
            switch raw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:)) {
            case .videoDeviceNotAvailableDueToSystemPressure: reason = .systemPressure
            case .videoDeviceInUseByAnotherClient, .audioDeviceInUseByAnotherClient: reason = .audioVideoInUseByAnotherClient
            case .videoDeviceNotAvailableInBackground, .videoDeviceNotAvailableWithMultipleForegroundApps: reason = .videoDeviceNotAvailable
            default: reason = .unknown
            }
            Task { await self?.suspend(reason: reason) }
        }
        notifications.observe(AVCaptureSession.interruptionEndedNotification, object: session) { [weak self] _ in
            Task { await self?.interruptionEnded() }
        }
        notifications.observe(AVCaptureSession.runtimeErrorNotification, object: session) { [weak self] _ in
            Task { await self?.suspend(reason: .runtimeFailure) }
        }
        notifications.observe(UIApplication.willResignActiveNotification, object: nil) { [weak self] _ in
            Task { await self?.suspend(reason: .applicationInactive) }
        }
        notifications.observe(AVCaptureDevice.subjectAreaDidChangeNotification, object: nil) { [weak self] notification in
            let deviceID = (notification.object as? AVCaptureDevice)?.uniqueID
            Task { await self?.subjectAreaChanged(deviceID: deviceID) }
        }
    }

    private func interruptionEnded() {
        eventContinuation.yield(.interruptionEnded)
        // Restarting the session and recording both require explicit caller actions.
    }
}

/// Reads each settled change of the viewfinder's automatic exposure and reports the scene light it implies, so a
/// lens that is not streaming yet reports nothing. KVO callbacks arrive on arbitrary threads; the pause flag is the
/// only shared state.
private final class SceneLightMeter: @unchecked Sendable {
    private var observations: [NSKeyValueObservation] = []
    private let lock = NSLock()
    private var paused = false

    var isPaused: Bool {
        get { lock.withLock { paused } }
        set { lock.withLock { paused = newValue } }
    }

    init(device: AVCaptureDevice, report: @escaping @Sendable (Double) -> Void) {
        let read: @Sendable (AVCaptureDevice) -> Void = { [weak self] device in
            guard let self, !self.isPaused, !device.isAdjustingExposure else { return }
            report(SceneLight.ev100(
                aperture: Double(device.lensAperture), duration: device.exposureDuration.seconds, iso: device.iso
            ))
        }
        observations = [
            device.observe(\.exposureDuration, options: [.new]) { device, _ in read(device) },
            device.observe(\.iso, options: [.new]) { device, _ in read(device) },
            device.observe(\.isAdjustingExposure, options: [.new]) { device, _ in read(device) }
        ]
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
    func resume() {
        let pending = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume()
    }
}

private final class CaptureNotifications {
    private var tokens: [NSObjectProtocol] = []
    var isEmpty: Bool { tokens.isEmpty }
    func observe(_ name: Notification.Name, object: Any?, handler: @escaping @Sendable (Notification) -> Void) {
        tokens.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: nil, using: handler))
    }
    func removeAll() {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
        tokens.removeAll()
    }
    deinit { removeAll() }
}

private final class PhotoSaveDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var failed = false
    private let completion: @Sendable (Data?, Bool) -> Void
    init(completion: @escaping @Sendable (Data?, Bool) -> Void) { self.completion = completion }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        lock.withLock {
            data = photo.fileDataRepresentation()
            failed = error != nil
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let result = lock.withLock { (data, failed || error != nil) }
        completion(result.0, result.1)
    }
}

private final class MovieSaveDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let completion: @Sendable (Bool) -> Void
    init(completion: @escaping @Sendable (Bool) -> Void) { self.completion = completion }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let succeeded = error == nil || (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
        completion(succeeded)
    }
}
#endif
