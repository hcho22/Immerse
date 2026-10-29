@preconcurrency import AVFoundation
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import NativeAdapters
import RenderCore
import XCTest
@testable import Immerse

/// What the captain met on 2026-10-28 (Evidence/NativeApp/development-stop-079.md): a 16mm Film on the color Film Stock,
/// one Recorded Clip with Live Audio, stopped early, whose Development stopped with "Could not finish" and advice to check
/// storage on an iPhone with plenty free. The app stops Development when it leaves the screen, as an auto-lock makes it
/// do, and iOS then takes its video encoder, so the clip's writer fails as it stops; the simulator keeps the encoder, so
/// an observer fails the writer as iOS does once the stop has reached the Development. The clip is saved through the
/// camera's own save path, from a file staged as the camera leaves one.
@MainActor
final class DevelopmentStopTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("DevelopmentStop-\(UUID())")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// The app leaves the screen partway through the Development: the alert says so and names no storage, nothing is lost,
    /// and Resume Development finishes the Movie with the clip's sound, with the screen kept on each time and let go after.
    func testADevelopmentStoppedByLeavingTheScreenSaysSoAndResumesWithTheClipsSound() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let screen = ScreenRecord()
        let leaving = LeavesTheScreen()
        // The microphone allowed, as the clip's sound shows it was.
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true),
                                     screenAwake: DevelopmentScreenAwake(hold: screen.hold),
                                     developmentObserver: { try await leaving.observe($1) })
        leaving.model = model
        await model.recoverAtLaunch()
        let film = try await stoppedEarlyReelWithSound(model)

        // Develop Film on the Development sheet.
        model.perform { try await model.develop(film.id) }
        try await waitUntil { model.alert != nil }
        XCTAssertTrue(leaving.left, "The app left the screen while the clip developed")
        let alert = try XCTUnwrap(model.alert)
        XCTAssertEqual(alert.message, "Development stopped because Immerse left the screen. Saved captures are unchanged. Tap Resume Development and keep Immerse open until it finishes.")
        XCTAssertFalse(alert.message.contains("storage"), alert.message)
        let stopped = try XCTUnwrap(model.film(film.id))
        XCTAssertEqual(stopped.developmentState, .developing)
        XCTAssertTrue(stopped.offersResumeDevelopment)
        XCTAssertEqual(stopped.captures.map(\.revealState), [.sealed])
        let source = try XCTUnwrap(model.repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        let kept = try await VerifiedMedia.movie(at: source.url, allowsAudio: true)
        XCTAssertEqual(kept.audioTrackCount, 1, "The Recorded Clip keeps its sound")
        XCTAssertEqual(screen.holds, [true, false], "On while it ran, let go when it stopped")

        // Back on the screen, Resume Development.
        model.alert = nil
        model.sceneChanged(to: .active)
        model.perform { try await model.develop(film.id) }
        try await waitUntil { model.film(film.id)?.developmentState == .developed && model.busyFilms.isEmpty }
        XCTAssertNil(model.alert)
        let movie = try model.repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)
        let developed = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
        XCTAssertEqual(developed.audioTrackCount, 1, "The Developed Movie plays the clip's sound")
        XCTAssertEqual(screen.holds, [true, false, true, false])
    }

    /// The screen stays on while any Development runs and may sleep again however it ends: finished, failed, or stopped
    /// by deleting its Film. Two at once hold it until the second ends. Leaving the Film's screen ends no Development, so
    /// the screen sleeps again when the Development itself ends.
    func testTheScreenStaysOnWhileADevelopmentRunsAndSleepsHoweverItEnds() async throws {
        let screen = ScreenRecord()
        let gate = HeldDevelopment()
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     screenAwake: DevelopmentScreenAwake(hold: screen.hold),
                                     developmentObserver: { try await gate.observe($0, $1) })
        await model.recoverAtLaunch()

        let finishing = try roll(model, title: "Finishing roll")
        let developing = Task { try await model.develop(finishing.id) }
        try await waitUntil { gate.holding.contains(finishing.id) }
        XCTAssertEqual(screen.holds, [true])
        gate.release(finishing.id)
        try await developing.value
        XCTAssertEqual(screen.holds, [true, false], "Finished")

        let failing = try roll(model, title: "Failing roll")
        let failed = Task { try await model.develop(failing.id) }
        try await waitUntil { gate.holding.contains(failing.id) }
        gate.release(failing.id, failing: NativeRenderError.renderFailed)
        do { try await failed.value; XCTFail("The failure reported success") } catch is DevelopmentFailure { }
        XCTAssertEqual(screen.holds, [true, false, true, false], "Failed")

        let deleted = try roll(model, title: "Deleted roll")
        let cancelled = Task { try await model.develop(deleted.id) }
        try await waitUntil { gate.holding.contains(deleted.id) }
        let removal = Task { try await model.remove(deleted.id) }
        try await waitUntil { gate.cancelled.contains(deleted.id) }
        gate.release(deleted.id)
        do { try await cancelled.value; XCTFail("A deleted Film developed") } catch is CancellationError { }
        try await removal.value
        XCTAssertEqual(screen.holds, [true, false, true, false, true, false], "Stopped by deleting its Film")

        let first = try roll(model, title: "First of two"), second = try roll(model, title: "Second of two")
        let both = [first, second].map { film in Task { try await model.develop(film.id) } }
        try await waitUntil { gate.holding.isSuperset(of: [first.id, second.id]) }
        gate.release(first.id)
        try await both[0].value
        XCTAssertEqual(screen.holds.last, true, "Still on while the second develops")
        gate.release(second.id)
        try await both[1].value
        XCTAssertEqual(screen.holds, [true, false, true, false, true, false, true, false])
    }

    /// Every error a Development can end with names what went wrong and what to do, in Development's words and with the
    /// button that carries on, and only a full iPhone is told about storage. The general words for any other failure name
    /// no storage either.
    func testEveryDevelopmentFailureSaysWhatWentWrong() throws {
        let interrupted = NSError(domain: AVFoundationErrorDomain, code: -11847,
                                  userInfo: [NSLocalizedDescriptionKey: "Operation Interrupted"])
        let full: [Error] = [
            CocoaError(.fileWriteOutOfSpace), NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)),
            NSError(domain: AVFoundationErrorDomain, code: AVError.Code.diskFull.rawValue),
            NativeRenderError.writerFailed(underlying: NSError(domain: AVFoundationErrorDomain, code: -11800, userInfo: [
                NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
            ])),
            PersistenceError.outOfSpace
        ]
        for error in full {
            XCTAssertEqual(FailureCopy.message(for: DevelopmentFailure(underlying: error, retry: "Resume Development")),
                           "This iPhone is out of space, so Development stopped. Saved captures are unchanged. Free space in iPhone Settings, then tap Resume Development.",
                           "\(error)")
            XCTAssertEqual(FailureCopy.message(for: error), FailureCopy.outOfSpace, "\(error)")
        }
        let unread = PersistenceError.unreadableMedia(MediaReadFailure(stage: .picture, framesRead: 13, status: 3, errors: [
            .init(domain: AVFoundationErrorDomain, code: -11821, description: "Cannot Decode")
        ]))
        let causes: [(Error, String)] = [
            (DevelopmentSuspended(), "Development stopped because Immerse left the screen."),
            (NativeRenderError.tableReaderUnavailable, "This iPhone could not prepare the colors of the Color Film Stock, so Development stopped."),
            (NativeRenderError.unrenderableTreatment, "This Film began developing in a newer version of Immerse, so this version cannot finish it."),
            (PersistenceError.treatmentConflict, "This Film began developing in a newer version of Immerse, so this version cannot finish it."),
            (NativeRenderError.invalidMovie(underlying: interrupted), "Immerse could not read one of this Film's photos or clips, so Development stopped."),
            (NativeRenderError.unreadableSource, "Immerse could not read one of this Film's photos or clips, so Development stopped."),
            (unread, "Immerse could not read one of this Film's photos or clips, so Development stopped."),
            (PersistenceError.invalidMedia, "Immerse could not read one of this Film's photos or clips, so Development stopped."),
            (PersistenceError.clipChecksumMismatch(1), "Immerse could not read one of this Film's photos or clips, so Development stopped."),
            (NativeRenderError.writerFailed(underlying: interrupted), "Immerse could not finish writing this Film's developed photos or clips, so Development stopped."),
            (NativeRenderError.writerTimedOut, "Immerse could not finish writing this Film's developed photos or clips, so Development stopped."),
            (NativeRenderError.renderFailed, "Immerse could not finish writing this Film's developed photos or clips, so Development stopped."),
            (PersistenceError.soundtrackUnavailable, "The Soundtrack chosen for this Movie could not be read, so the Movie was not made."),
            (PersistenceError.soundtrackChanged, "The Movie's sound changed while the Movie was being made."),
            (PersistenceError.filmNotFound, "This Film is no longer in your Journal, so it was not developed."),
            (FilmDomainError.developmentNotEligible, "Development stopped before it finished."),
            (CocoaError(.fileReadNoPermission), "Development stopped before it finished.")
        ]
        for (error, cause) in causes {
            for retry in ["Resume Development", "Rebuild Movie"] {
                let message = try XCTUnwrap(FailureCopy.message(for: DevelopmentFailure(underlying: error, retry: retry)))
                XCTAssertTrue(message.hasPrefix(cause), "\(error): \(message)")
                XCTAssertFalse(message.localizedCaseInsensitiveContains("storage"), "\(error): \(message)")
                XCTAssertFalse(message.contains("space"), "\(error): \(message)")
                if !(error is PersistenceError && (error as? PersistenceError) == .filmNotFound) {
                    XCTAssertTrue(message.contains(retry), "\(error) names the button that carries on: \(message)")
                }
                for name in ["table", "kernel", "writer", "encoder", "Metal", "Core Image", "AVFoundation", "error"] {
                    XCTAssertFalse(message.contains(name), "\(error): no internal names in \(message)")
                }
            }
        }
        XCTAssertNil(FailureCopy.message(for: DevelopmentFailure(underlying: CancellationError(), retry: "Resume Development")))
        XCTAssertEqual(FailureCopy.message(for: DevelopmentFailure(underlying: PersistenceError.operationInProgress,
                                                                   retry: "Resume Development")),
                       FailureCopy.message(for: PersistenceError.operationInProgress))
        XCTAssertFalse(FailureCopy.retry.contains("storage"), "The general words name no cause")
        XCTAssertEqual(FailureCopy.message(for: NativeRenderError.invalidMovie()), FailureCopy.retry)
        let stoppedRebuild = try XCTUnwrap(FailureCopy.message(for: DevelopmentSuspended()))
        XCTAssertTrue(stoppedRebuild.hasPrefix("This stopped because Immerse left the screen."), stoppedRebuild)
    }

    /// A 16mm Film on the color Film Stock with one Recorded Clip with Live Audio, saved through the camera's save path,
    /// stopped early, with its original to be removed after Development, as on the Development sheet.
    private func stoppedEarlyReelWithSound(_ model: JournalModel) async throws -> Film {
        let film = try model.repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Synthetic reel",
                                                   movieOrientation: .portrait, filmStock: .color, access: .subscription)
        let files = try CapturedMediaFiles(directory: model.repository.captureStagingDirectory(filmID: film.id))
        let id = UUID()
        try await writeClipWithSound(to: files.movieDestination(id: id), seconds: 2)
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: .movie, orientation: .portrait,
                                               remainingFrames: film.remainingMovieFrames ?? 0, allowsAudio: true))
        do { try await model.capture.open(film: film, model: model); XCTFail("The simulator has no camera to start") }
        catch let error as NativeCaptureError where error == .notRunning || error == .configurationFailed { }
        try await waitUntil { model.film(film.id)?.savedCaptureCount == 1 }
        _ = try model.repository.completeEarly(filmID: film.id, confirmedCaptureCount: 1)
        try model.chooseOriginals(film.id, sequences: [1], export: false)
        model.refresh()
        return try XCTUnwrap(model.film(film.id))
    }

    /// A Disposable roll of one exposure, finished early and ready to develop.
    private func roll(_ model: JournalModel, title: String) throws -> Film {
        let film = try model.repository.createFilm(camera: CameraCatalog.disposable1990s, title: title, access: .subscription)
        try model.repository.savePhotoCapture(filmID: film.id, sourceData: syntheticPhoto())
        _ = try model.repository.completeEarly(filmID: film.id)
        model.refresh()
        return film
    }

    /// A clip as the camera writes one: H.264 picture at 30 frames a second and stereo AAC sound at 48 kHz beside it.
    private func writeClipWithSound(to url: URL, seconds: Double) async throws {
        let (width, height, rate) = (320, 240, 48_000.0)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let picture = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: picture, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height
        ])
        let sound = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 2
        ])
        // Real-time inputs, as the camera's movie output writes: neither waits for the other to interleave.
        picture.expectsMediaDataInRealTime = true
        sound.expectsMediaDataInRealTime = true
        writer.add(picture)
        writer.add(sound)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var format = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 4,
            mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
        var description: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &format, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                       magicCookie: nil, extensions: nil, formatDescriptionOut: &description)
        let frames = Int(seconds * 30), packet = 1024
        var soundTime = 0
        for frame in 0..<frames {
            // The sound up to this picture frame, a 440 Hz tone, then the frame.
            while Double(soundTime) / rate < Double(frame + 1) / 30 {
                while !sound.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
                var samples = [Int16](repeating: 0, count: packet * 2)
                for index in 0..<packet {
                    let value = Int16(sin(Double(soundTime + index) * 2 * .pi * 440 / rate) * 4_000)
                    samples[2 * index] = value; samples[2 * index + 1] = value
                }
                var block: CMBlockBuffer?
                CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: packet * 4,
                    blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: packet * 4, flags: 0,
                    blockBufferOut: &block)
                let data = try XCTUnwrap(block)
                samples.withUnsafeBytes { _ = CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: data,
                                                                            offsetIntoDestination: 0, dataLength: packet * 4) }
                var buffer: CMSampleBuffer?
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: data,
                    formatDescription: try XCTUnwrap(description), sampleCount: packet,
                    presentationTimeStamp: CMTime(value: CMTimeValue(soundTime), timescale: CMTimeScale(rate)),
                    packetDescriptions: nil, sampleBufferOut: &buffer)
                XCTAssertTrue(sound.append(try XCTUnwrap(buffer)))
                soundTime += packet
            }
            while !picture.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &buffer)
            let pixels = try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(to: UInt8.self)
            let row = CVPixelBufferGetBytesPerRow(pixels)
            for y in 0..<height {
                for x in 0..<width {
                    // Blue, green, red and alpha: a warm half and a cool half, brightening frame by frame.
                    let pixel = base + y * row + x * 4
                    pixel[0] = x < width / 2 ? 60 : 170
                    pixel[1] = UInt8(80 + frame)
                    pixel[2] = x < width / 2 ? 190 : 70
                    pixel[3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            XCTAssertTrue(adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30)))
        }
        picture.markAsFinished()
        sound.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frames), timescale: 30))
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, writer.error.map { "\($0)" } ?? "")
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(60)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for the Development")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// What `DevelopmentScreenAwake` asked of the screen, in order: true to hold it on, false to let it sleep.
@MainActor private final class ScreenRecord {
    private(set) var holds: [Bool] = []
    func hold(_ on: Bool) { holds.append(on) }
}

/// Stands in for the app leaving the screen partway through a Development, on an iPhone: once the clip has developed,
/// the scene goes to the background as at an auto-lock, and once that stop reaches the Development the clip's writer
/// fails as iOS makes it fail when it takes the encoder ("Operation Interrupted").
@MainActor private final class LeavesTheScreen {
    weak var model: JournalModel?
    private var armed = true
    private(set) var left = false

    nonisolated func observe(_ stage: DevelopmentStage) async throws {
        guard stage == .afterRendering(sequence: 1), await leave() else { return }
        let deadline = ContinuousClock.now + .seconds(10)
        while !Task.isCancelled, ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        throw NativeRenderError.writerFailed(underlying: NSError(domain: AVFoundationErrorDomain, code: -11847,
            userInfo: [NSLocalizedDescriptionKey: "Operation Interrupted"]))
    }

    private func leave() -> Bool {
        guard armed, let model else { return false }
        armed = false
        left = true
        model.sceneChanged(to: .inactive)
        model.sceneChanged(to: .background)
        return true
    }
}

/// Holds each Film's Development once its treatments are assigned until the test lets it go, failing it if asked.
@MainActor private final class HeldDevelopment {
    private(set) var holding: Set<UUID> = []
    private(set) var cancelled: Set<UUID> = []
    private var released: [UUID: Error?] = [:]

    func release(_ film: UUID, failing failure: Error? = nil) { released[film] = .some(failure) }

    nonisolated func observe(_ film: UUID, _ stage: DevelopmentStage) async throws {
        guard stage == .afterAssignments else { return }
        await hold(film)
        while await outcome(film) == nil {
            if Task.isCancelled { await markCancelled(film) }
            try? await Task.sleep(for: .milliseconds(5))
        }
        if let failure = await outcome(film).flatMap({ $0 }) { throw failure }
    }

    private func hold(_ film: UUID) { holding.insert(film) }
    private func markCancelled(_ film: UUID) { cancelled.insert(film) }
    private func outcome(_ film: UUID) -> Error?? { released[film] }
}
