#if os(iOS)
@preconcurrency import AVFoundation
import Dispatch
import FilmDomain
import Foundation
import UIKit

public enum CaptureFrameOrientation: Sendable {
    case portrait, portraitUpsideDown, landscapeLeft, landscapeRight

    var rotationAngle: CGFloat {
        switch self {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeLeft: 180
        case .landscapeRight: 0
        }
    }

    var clipOrientation: ClipOrientation {
        switch self {
        case .portrait, .portraitUpsideDown: .portrait
        case .landscapeLeft, .landscapeRight: .landscape
        }
    }
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

    @MainActor
    public func update(
        _ layer: AVCaptureVideoPreviewLayer,
        position: CapturePosition,
        orientation: CaptureFrameOrientation
    ) throws {
        guard layer.session === session, let connection = layer.connection,
              connection.isVideoRotationAngleSupported(orientation.rotationAngle),
              position != .front || connection.isVideoMirroringSupported else {
            throw NativeCaptureError.unsupportedConnection
        }
        connection.videoRotationAngle = orientation.rotationAngle
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported { connection.isVideoMirrored = position == .front }
    }
}

public actor AVFoundationCaptureBackend {
    private nonisolated let queue = DispatchSerialQueue(label: "com.immerse.capture-session")
    public nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    public nonisolated let events: AsyncStream<CaptureSaveEvent>
    private let eventContinuation: AsyncStream<CaptureSaveEvent>.Continuation
    private let session = AVCaptureSession()
    private let files: CapturedMediaFiles
    private let committer: any CaptureSaveCommitting
    private var operations = CaptureOperationCoordinator()
    private var plan: CaptureSessionPlan?
    private var input: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var photoDelegate: PhotoSaveDelegate?
    private var movieDelegate: MovieSaveDelegate?
    private let notifications = CaptureNotifications()
    public private(set) var retainedCommittedFiles: [CaptureSaveEvent] = []

    public init(stagingDirectory: URL, committer: any CaptureSaveCommitting) throws {
        self.files = try CapturedMediaFiles(directory: stagingDirectory)
        self.committer = committer
        (events, eventContinuation) = AsyncStream.makeStream()
    }

    public var phase: CapturePhase { operations.phase }
    public var activePosition: CapturePosition? { plan?.activePosition }
    public func previewSource() -> CapturePreviewSource { CapturePreviewSource(session: session) }

    public func start(plan next: CaptureSessionPlan) throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw NativeCaptureError.notRunning
        }
        guard operations.operationID == nil else { throw NativeCaptureError.busy }
        guard next.mediaKind != .movie || next.lockedMovieOrientation != nil else {
            throw NativeCaptureError.configurationFailed
        }
        if session.isRunning { session.stopRunning() }
        try configure(next)
        installNotificationsIfNeeded()
        session.startRunning()
        guard session.isRunning else { throw NativeCaptureError.notRunning }
        operations.resumeSession()
    }

    public func switchLens(to position: CapturePosition) throws {
        try operations.requireIdle()
        guard session.isRunning, let plan else { throw NativeCaptureError.notRunning }
        guard plan.lensSwitchDecision(to: position, during: operations.phase) == .allowed else {
            throw NativeCaptureError.configurationFailed
        }
        let device = try camera(at: position)
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
        self.plan = CaptureSessionPlan(
            request: CaptureSessionRequest(
                preferredPosition: position, mediaKind: plan.mediaKind,
                lockedMovieOrientation: plan.lockedMovieOrientation
            ),
            capabilities: AVFoundationCaptureDeviceDiscoverer().capabilities()
        )
        ensureUnmirroredOutput()
    }

    public func capturePhoto(orientation: CaptureFrameOrientation, flash: Bool = false) throws {
        guard session.isRunning, let photoOutput else { throw NativeCaptureError.notRunning }
        try operations.requireIdle()
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
        let id = try operations.begin(.photo)
        let delegate = PhotoSaveDelegate { [weak self] data, failed in
            Task { await self?.photoFinished(id: id, data: data, failed: failed) }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    public func startMovie(orientation: CaptureFrameOrientation, remainingSeconds: TimeInterval) throws {
        guard session.isRunning, let movieOutput else { throw NativeCaptureError.notRunning }
        guard remainingSeconds.isFinite, remainingSeconds > 0 else {
            throw NativeCaptureError.invalidDuration
        }
        try operations.requireIdle()
        try configureConnection(movieOutput.connection(with: .video), orientation: orientation)
        let id = try operations.begin(.movie)
        movieOutput.maxRecordedDuration = CMTime(seconds: remainingSeconds, preferredTimescale: 60_000)
        let delegate = MovieSaveDelegate { [weak self] successfullyFinished in
            Task {
                await self?.movieFinished(
                    id: id, orientation: orientation.clipOrientation,
                    remainingSeconds: remainingSeconds, successfullyFinished: successfullyFinished
                )
            }
        }
        movieDelegate = delegate
        movieOutput.startRecording(to: files.movieDestination(id: id), recordingDelegate: delegate)
    }

    public func stopMovie() {
        operations.stopRecording()
        if movieOutput?.isRecording == true { movieOutput?.stopRecording() }
    }

    public func suspend(reason: NativeCaptureInterruptionReason = .applicationInactive) {
        operations.interrupt()
        if movieOutput?.isRecording == true { movieOutput?.stopRecording() }
        if session.isRunning { session.stopRunning() }
        eventContinuation.yield(.interrupted(reason))
    }

    public func retryPendingSave() async throws {
        let (id, event) = try operations.beginCommit()
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

    public func shutdown() {
        suspend()
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
            photoOutput = output
        } else {
            let output = AVCaptureMovieFileOutput()
            guard session.canAddOutput(output) else { throw NativeCaptureError.configurationFailed }
            if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
            session.addOutput(output)
            movieOutput = output
        }
        plan = next
        ensureUnmirroredOutput()
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
        guard operations.operationID == id, operations.pendingSave == nil else { return }
        photoDelegate = nil
        guard !failed, let data else { failCapture(id: id); return }
        do {
            let url = try files.savePhoto(data, id: id)
            guard operations.stage(.photoSaved(url), id: id) else { return }
        } catch { failCapture(id: id); return }
        try? await retryPendingSave()
    }

    private func movieFinished(
        id: UUID, orientation: ClipOrientation, remainingSeconds: TimeInterval, successfullyFinished: Bool
    ) async {
        guard operations.operationID == id, operations.pendingSave == nil else { return }
        movieDelegate = nil
        operations.stopRecording()
        // Interrupted recordings can carry an error with a successfully-finished file.
        // Even an unsuccessful callback may have salvageable footage: validate the actual file.
        do {
            let event = try await files.movieSavedEvent(
                id: id, orientation: orientation, remainingSeconds: remainingSeconds
            )
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
