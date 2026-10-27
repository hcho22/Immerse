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
    /// The zoom steps the iPhone's own lenses give the 6×6's rear camera, empty where the Camera has none, the front
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
    public func focus(at point: CGPoint, alsoExpose: Bool) throws -> FocusPointDecision {
        guard session.isRunning, let device = input?.device, let plan else { return .unsupported }
        guard point.x.isFinite, point.y.isFinite, (0...1).contains(point.x), (0...1).contains(point.y) else {
            throw NativeCaptureError.configurationFailed
        }
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
        try replaceInput(with: camera(at: position), plan: plan)
        self.plan = CaptureSessionPlan(
            request: CaptureSessionRequest(
                preferredPosition: position, mediaKind: plan.mediaKind,
                lockedMovieOrientation: plan.lockedMovieOrientation, behavior: plan.behavior,
                manualLensPosition: manualLensPosition
            ),
            capabilities: AVFoundationCaptureDeviceDiscoverer().capabilities()
        )
        // The capabilities were read with the session running, so the rear lenses are current, and the rear wide lens is
        // the only camera a switch returns to.
        zoomStep = self.plan?.restingZoomStep
        restartMeter()
    }

    /// Takes a zoom step of the iPhone's own lenses (the 6×6, rear camera): changes to that lens, and crops it where the
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
            try replaceInput(with: device, plan: plan)
            plan = plan.updatingRearLenses(AVFoundationCaptureDeviceDiscoverer.rearLenses())
            self.plan = plan
            guard plan.zoomDecision(to: step, during: operations.phase) == .allowed else {
                try replaceInput(with: active, plan: plan)
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
    /// session runs at `.inputPriority`, so the added lens keeps the format chosen here.
    private func replaceInput(with device: AVCaptureDevice, plan: CaptureSessionPlan) throws {
        if plan.mediaKind == .movie { try selectMovieFormat(device) }
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
        plan = current.updatingRearLenses(AVFoundationCaptureDeviceDiscoverer.rearLenses())
        zoomStep = plan?.restingZoomStep
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

    public func startMovie(orientation: CaptureFrameOrientation, remainingFrames: Int) throws {
        guard session.isRunning, let movieOutput else { throw NativeCaptureError.notRunning }
        guard remainingFrames > 0 else {
            throw NativeCaptureError.invalidDuration
        }
        try operations.requireIdle()
        guard !isRecovering, try files.pendingRecords().isEmpty else { throw NativeCaptureError.pendingRecoveryRequired }
        try configureConnection(movieOutput.connection(with: .video), orientation: orientation)
        let id = try operations.begin(.movie)
        do {
            try files.prepare(PendingCaptureRecord(id: id, mediaKind: .movie,
                orientation: orientation.clipOrientation, remainingFrames: remainingFrames))
        } catch { operations.finish(id: id); throw error }
        movieOutput.maxRecordedDuration = CMTime(value: CMTimeValue(remainingFrames), timescale: CMTimeScale(MovieFrames.perSecond))
        movieOutput.metadata = input.flatMap { Self.sceneWhiteBalanceItem($0.device) }.map { [$0] }
        let delegate = MovieSaveDelegate { [weak self] successfullyFinished in
            Task {
                await self?.movieFinished(
                    id: id, orientation: orientation.clipOrientation,
                    remainingFrames: remainingFrames, successfullyFinished: successfullyFinished
                )
            }
        }
        movieDelegate = delegate
        movieOutput.startRecording(to: files.movieDestination(id: id), recordingDelegate: delegate)
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
        session.automaticallyConfiguresApplicationAudioSession = false
        photoOutput = nil
        movieOutput = nil
        input = nil
        plan = nil
        guard session.canAddInput(newInput) else { throw NativeCaptureError.configurationFailed }
        // Only a .video device is ever discovered or added. No microphone input or audio session.
        session.addInput(newInput)
        input = newInput
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
            try selectMovieFormat(newInput.device)
            session.addOutput(output)
            movieOutput = output
        }
        plan = next
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
        Self.applyFocusBehavior(behavior.focus, manualLensPosition: manualLensPosition, to: device)
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

    private func selectMovieFormat(_ device: AVCaptureDevice) throws {
        let rate = Float64(MovieFrames.perSecond)
        let formats = device.formats.filter {
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
        guard let format = MovieCaptureFormat.preferred(among: formats, dimensions: {
            let size = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return (Int(size.width), Int(size.height))
        }, recordsMovieFrameRate: {
            $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= rate && rate <= $0.maxFrameRate }
        }) else { throw NativeCaptureError.configurationFailed }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.activeFormat = format
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(MovieFrames.perSecond))
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
        id: UUID, orientation: ClipOrientation, remainingFrames: Int, successfullyFinished: Bool
    ) async {
        guard operations.operationID == id, operations.pendingSave == nil else { return }
        movieDelegate = nil
        if privacyCancelled { operations.finish(id: id); return }
        operations.stopRecording()
        // Interrupted recordings can carry an error with a successfully-finished file.
        // Even an unsuccessful callback may have salvageable footage: validate the actual file.
        do {
            let event = try await files.movieSavedEvent(
                id: id, orientation: orientation, remainingFrames: remainingFrames
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
