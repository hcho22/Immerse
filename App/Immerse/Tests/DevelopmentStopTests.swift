@preconcurrency import AVFoundation
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import NativeAdapters
import RenderCore
import Synchronization
import XCTest
@testable import Immerse

/// What the captain met on 2026-10-28 (Evidence/NativeApp/development-stop-079.md): a 16mm Film on the color Film Stock,
/// one Recorded Clip with Live Audio, stopped early, whose Development stopped with "Could not finish" and advice to check
/// storage on an iPhone with plenty free. The app stops Development when it leaves the screen, as an auto-lock makes it
/// do, and iOS then takes its video encoder, so the clip's writer fails as the stop reaches it or before; the simulator
/// keeps the encoder, so an observer fails the writer as iOS does, in either order. The clip is saved through the
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

    /// The other order an iPhone can take: iOS takes the clip's encoder as Immerse leaves the screen, and the writer's
    /// failure reaches Development before the stop does. The scene's move to the background is recorded as it is
    /// reported, so the failure still reads as the stop, and the Film stays resumable with nothing lost.
    func testAWriterFailureThatReachesDevelopmentBeforeTheStopReadsAsTheStop() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let encoder = EncoderTakenFirst()
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true),
                                     developmentObserver: { try await encoder.observe($1) })
        await model.recoverAtLaunch()
        let film = try await stoppedEarlyReelWithSound(model)

        // Develop Film, its outcome taken off the main actor so that it can come back while the main actor is held.
        let processor = model.processor, filmID = film.id
        let returned = DispatchSemaphore(value: 0)
        let development = Task.detached {
            defer { returned.signal() }
            try await processor.develop(filmID: filmID)
        }
        try await waitUntil { encoder.reached }
        // The scene leaves on the main actor, as SwiftUI reports it, and the stop's own task waits for the main actor,
        // which stays held until the writer's failure has come back from Development.
        model.sceneChanged(to: .inactive)
        model.sceneChanged(to: .background)
        encoder.take()
        XCTAssertTrue(holdTheMainActor(until: returned), "Development came back")
        XCTAssertFalse(encoder.stopReachedFirst, "The writer failed before the stop reached the Development")
        var ended: Error?
        do { try await development.value } catch { ended = error }
        let stop = try XCTUnwrap(ended, "A stopped Development reported success")
        XCTAssertTrue(stop is DevelopmentSuspended, "Reported as the stop, not as the writer's failure: \(stop)")
        XCTAssertEqual(FailureCopy.message(for: DevelopmentFailure(underlying: stop, retry: "Resume Development")),
                       "Development stopped because Immerse left the screen. Saved captures are unchanged. Tap Resume Development and keep Immerse open until it finishes.")
        model.refresh()
        let stopped = try XCTUnwrap(model.film(film.id))
        XCTAssertEqual(stopped.developmentState, .developing)
        XCTAssertTrue(stopped.offersResumeDevelopment)
        XCTAssertEqual(stopped.captures.map(\.revealState), [.sealed])
        let source = try XCTUnwrap(model.repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        let kept = try await VerifiedMedia.movie(at: source.url, allowsAudio: true)
        XCTAssertEqual(kept.audioTrackCount, 1, "The Recorded Clip keeps its sound")

        // Back on the screen, Resume Development.
        model.sceneChanged(to: .active)
        model.perform { try await model.develop(film.id) }
        try await waitUntil { model.film(film.id)?.developmentState == .developed && model.busyFilms.isEmpty }
        XCTAssertNil(model.alert)
        let movie = try model.repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)
        let developed = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
        XCTAssertEqual(developed.audioTrackCount, 1, "The Developed Movie plays the clip's sound")
    }

    /// An Instant print develops as it is saved, at the camera, which shows its failure in place of the Resume Development
    /// the Film's screen offers: a print stopped as Immerse leaves the screen says to open the Film and tap it there.
    func testAnInstantPrintStoppedAtTheCameraSaysToOpenTheFilmAndResume() async throws {
        let leaving = LeavesTheScreen()
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     developmentObserver: { try await leaving.observe($1) })
        leaving.model = model
        await model.recoverAtLaunch()
        let film = try model.repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic Instant pack",
                                                   access: .subscription)
        try model.repository.savePhotoCapture(filmID: film.id, sourceData: syntheticPhoto())
        model.refresh()

        // The camera's notice, as the camera shows a print's failure while it is up.
        let notice = CameraNotice()
        model.developSavedPrint(film.id) { notice.text = $0 }
        try await waitUntil { notice.text != nil }
        XCTAssertTrue(leaving.left, "The app left the screen while the print developed")
        XCTAssertEqual(notice.text, "Development stopped because Immerse left the screen. Saved captures are unchanged. Open the Film and tap Resume Development and keep Immerse open until it finishes.")
        XCTAssertNil(model.alert, "The camera shows it, not the Journal")
        XCTAssertTrue(try XCTUnwrap(model.film(film.id)).offersResumeDevelopment)

        // Back on the screen, the Film's Resume Development reveals the print.
        model.sceneChanged(to: .active)
        try await model.develop(film.id)
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.revealed])
    }

    /// A Movie's sound change and a clip's discard each develop the Movie again, and their failures say what went wrong in
    /// Development's words with the button that tries again where the message shows: Apply sound choice on the Movie
    /// sound sheet, and Rebuild Movie on the Film's screen. A discard that fails before it is recorded is no Development.
    func testASoundChangeAndADiscardsRebuildSayWhatWentWrongWithTheirOwnButton() async throws {
        let failing = FailsNextDevelopment()
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     developmentObserver: { try await failing.observe($1) })
        await model.recoverAtLaunch()
        let film = try model.repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Synthetic reel",
                                                   movieOrientation: .portrait, filmStock: .blackAndWhite,
                                                   access: .subscription)
        for index in 1...2 {
            let clip = root.appendingPathComponent("clip-\(index).mov")
            try await writeClipWithSound(to: clip, seconds: 1)
            try model.repository.saveMovieClip(filmID: film.id, sourceData: Data(contentsOf: clip), durationSeconds: 1,
                                               orientation: .portrait)
        }
        _ = try model.repository.completeEarly(filmID: film.id, confirmedCaptureCount: 2)
        model.refresh()
        try await model.develop(film.id)
        XCTAssertEqual(model.film(film.id)?.developmentState, .developed)

        let writer = NativeRenderError.writerFailed(underlying: NSError(domain: AVFoundationErrorDomain, code: -11800))
        failing.arm(writer)
        let sound = try await failure { try await model.selectMovieSound(film.id, choice: .silent, assetID: nil) }
        XCTAssertEqual(FailureCopy.message(for: sound), "Immerse could not finish writing this Film's developed photos or clips, so Development stopped. Saved captures are unchanged. Tap Apply sound choice to try again.")
        failing.arm(PersistenceError.soundtrackUnavailable)
        let soundtrack = try await failure { try await model.selectMovieSound(film.id, choice: .recordedSound, assetID: nil) }
        XCTAssertEqual(FailureCopy.message(for: soundtrack), "The Soundtrack chosen for this Movie could not be read, so the Movie was not made. Saved captures are unchanged. Choose the Movie's sound again, or tap Apply sound choice.")

        failing.arm(writer)
        let discard = try await failure { try await model.remove(film.id, sequence: 1) }
        XCTAssertEqual(FailureCopy.message(for: discard), "Immerse could not finish writing this Film's developed photos or clips, so Development stopped. Saved captures are unchanged. Tap Rebuild Movie to try again.")
        let unbuilt = try XCTUnwrap(model.film(film.id))
        XCTAssertEqual(unbuilt.captures.map(\.isDiscarded), [true, false])
        XCTAssertTrue(unbuilt.canPlaybackDevelopedMovie, "The Film's screen offers Rebuild Movie in the Movie's place")
        XCTAssertNil(try model.repository.mediaAsset(filmID: film.id, sequenceNumber: 0, kind: .movie))
        let unrecorded = try await failure { try await model.remove(film.id, sequence: 9) }
        XCTAssertFalse(unrecorded is DevelopmentFailure, "\(unrecorded)")

        // Rebuild Movie.
        try await model.develop(film.id)
        XCTAssertNotNil(try model.repository.mediaAsset(filmID: film.id, sequenceNumber: 0, kind: .movie))
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
            for retry in ["Resume Development", "Rebuild Movie", "Apply sound choice"] {
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
            // The camera has no Resume Development: its words send the person to the Film's screen for it.
            let atTheCamera = try XCTUnwrap(FailureCopy.message(for: DevelopmentFailure(
                underlying: error, retry: "Resume Development", atTheCamera: true)))
            XCTAssertTrue(atTheCamera.hasPrefix(cause), "\(error): \(atTheCamera)")
            if !(error is PersistenceError && (error as? PersistenceError) == .filmNotFound) {
                XCTAssertTrue(atTheCamera.localizedCaseInsensitiveContains("open the Film and tap Resume Development"),
                              "\(error): \(atTheCamera)")
            }
            XCTAssertFalse(atTheCamera.contains("Tap Resume Development"), "\(error): \(atTheCamera)")
        }
        XCTAssertEqual(FailureCopy.message(for: DevelopmentFailure(underlying: PersistenceError.outOfSpace,
                                                                   retry: "Resume Development", atTheCamera: true)),
                       "This iPhone is out of space, so Development stopped. Saved captures are unchanged. Free space in iPhone Settings, then open the Film and tap Resume Development.")
        XCTAssertNil(FailureCopy.message(for: DevelopmentFailure(underlying: CancellationError(), retry: "Resume Development")))
        XCTAssertEqual(FailureCopy.message(for: DevelopmentFailure(underlying: PersistenceError.operationInProgress,
                                                                   retry: "Resume Development")),
                       FailureCopy.message(for: PersistenceError.operationInProgress))
        XCTAssertFalse(FailureCopy.retry.contains("storage"), "The general words name no cause")
        XCTAssertEqual(FailureCopy.message(for: NativeRenderError.invalidMovie()), FailureCopy.retry)
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

    /// The error `operation` throws.
    private func failure(_ operation: () async throws -> Void) async throws -> Error {
        do { try await operation() } catch { return error }
        XCTFail("The failure reported success")
        throw CancellationError()
    }

    /// Holds the main thread, and with it the main actor, until `semaphore` is signalled, for up to a minute.
    private func holdTheMainActor(until semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + 60) == .success
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

/// Stands in for iOS taking the clip's encoder as Immerse leaves the screen, before the stop reaches the Development:
/// once the clip has developed it waits for the test to take the encoder, then fails the clip's writer at once with the
/// error iOS gives ("Operation Interrupted"), noting whether the stop had reached it by then. Later Developments go on.
private final class EncoderTakenFirst: Sendable {
    private let state = Mutex((armed: true, reached: false, taken: false, stopReachedFirst: false))
    var reached: Bool { state.withLock { $0.reached } }
    var stopReachedFirst: Bool { state.withLock { $0.stopReachedFirst } }
    func take() { state.withLock { $0.taken = true } }

    func observe(_ stage: DevelopmentStage) async throws {
        guard stage == .afterRendering(sequence: 1), state.withLock({ $0.armed }) else { return }
        state.withLock { $0.armed = false; $0.reached = true }
        while !state.withLock({ $0.taken }) { try? await Task.sleep(for: .milliseconds(5)) }
        state.withLock { $0.stopReachedFirst = Task.isCancelled }
        throw NativeRenderError.writerFailed(underlying: NSError(domain: AVFoundationErrorDomain, code: -11847,
            userInfo: [NSLocalizedDescriptionKey: "Operation Interrupted"]))
    }
}

/// What the camera shows of a print's failure while it is up.
@MainActor private final class CameraNotice {
    var text: String?
}

/// Fails the next Development, a Movie's rebuild included, as it begins, with the error the test arms it with.
@MainActor private final class FailsNextDevelopment {
    private var armed: Error?

    func arm(_ failure: Error) { armed = failure }

    nonisolated func observe(_ stage: DevelopmentStage) async throws {
        guard stage == .beforeBegin, let failure = await take() else { return }
        throw failure
    }

    private func take() -> Error? {
        defer { armed = nil }
        return armed
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
