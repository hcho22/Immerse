@preconcurrency import AVFoundation
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import XCTest

/// The 16mm Film whose Development stopped on the captain's iPhone on 2026-10-28: the color Film Stock, one Recorded Clip
/// with Live Audio, stopped early. A Development stops when the app leaves the screen (`suspendProcessing`), and iOS takes
/// an app's video encoder away there too ("The asset writer must give up encoding resources when your app goes into the
/// background", AVFoundation's engineers), so the clip being written fails as it stops. The simulator and a Mac keep the
/// encoder, so the observer stands in for iOS: it fails the clip's writer with the error iOS gives, once the stop has
/// reached the Development. Evidence/NativeApp/development-stop-079.md has the reproduction.
final class DevelopmentSuspensionTests: XCTestCase {
    /// iOS's error for a writer whose encoder it took: AVFoundation's "Operation Interrupted", -11847, which macOS's
    /// `AVError.Code` does not name.
    private static let encoderTaken = NativeRenderError.writerFailed(underlying: NSError(
        domain: AVFoundationErrorDomain, code: -11847,
        userInfo: [NSLocalizedDescriptionKey: "Operation Interrupted"]))

    func testADevelopmentStoppedAsTheAppLeavesReportsTheStopAndResumesWithItsClipAndSound() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let leaving = LeavesTheScreen(at: .afterRendering(sequence: 1), failingWith: Self.encoderTaken)
        let processor = try FilmProcessor(root: fixture.root, developmentObserver: { try await leaving.observe($1) })
        await leaving.attach(processor)
        do {
            try await processor.develop(filmID: fixture.film.id)
            XCTFail("A stopped Development reported success")
        } catch is DevelopmentSuspended {
        } catch {
            XCTFail("The stop is reported as the stop, not as what the clip's writer said while it stopped: \(error)")
        }
        let reached = await leaving.stopped
        XCTAssertTrue(reached, "The app left the screen while the clip developed")
        try await fixture.assertStoppedWithEverythingKept()

        // Resume Development, with the app on the screen.
        try await FilmProcessor(root: fixture.root).develop(filmID: fixture.film.id)
        try await fixture.assertDevelopedWithItsClipAndSound()
    }

    /// The same failure with the app on the screen is the failure it is.
    func testAWriterFailureWithoutTheStopIsReportedAsItself() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let failure = Self.encoderTaken
        let processor = try FilmProcessor(root: fixture.root, developmentObserver: { _, stage in
            if stage == .afterRendering(sequence: 1) { throw failure }
        })
        do {
            try await processor.develop(filmID: fixture.film.id)
            XCTFail("The failure reported success")
        } catch let error as NativeRenderError {
            XCTAssertEqual(error, failure)
        }
        try await fixture.assertStoppedWithEverythingKept()
    }

    /// A Film the build before this one left stopped, as on the captain's iPhone, finishes with Resume Development and
    /// nothing lost, with no change to what it stored: stopped while its clip developed, and stopped after the clip was
    /// saved but before the Movie was.
    func testAFilmTheEarlierBuildLeftStoppedFinishesWithResumeDevelopment() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let whileTheClipDeveloped = try await Fixture()
        defer { whileTheClipDeveloped.remove() }
        // What Development records before it renders: Development started and each capture's treatment assigned.
        _ = try whileTheClipDeveloped.repository.beginDevelopment(filmID: whileTheClipDeveloped.film.id)
        try await whileTheClipDeveloped.assertStoppedWithEverythingKept()
        try await FilmProcessor(root: whileTheClipDeveloped.root).develop(filmID: whileTheClipDeveloped.film.id)
        try await whileTheClipDeveloped.assertDevelopedWithItsClipAndSound()

        let beforeTheMovie = try await Fixture()
        defer { beforeTheMovie.remove() }
        let failure = Self.encoderTaken
        let stopping = try FilmProcessor(root: beforeTheMovie.root, developmentObserver: { _, stage in
            if stage == .afterPersistence(sequence: 1) { throw failure }
        })
        do { try await stopping.develop(filmID: beforeTheMovie.film.id); XCTFail("The failure reported success") }
        catch let error as NativeRenderError { XCTAssertEqual(error, failure) }
        let stopped = try beforeTheMovie.repository.film(id: beforeTheMovie.film.id)
        XCTAssertEqual(stopped.developmentState, .developing)
        XCTAssertNotNil(try beforeTheMovie.repository.mediaAsset(filmID: stopped.id, sequenceNumber: 1, kind: .clip))
        XCTAssertNil(try beforeTheMovie.repository.mediaAsset(filmID: stopped.id, sequenceNumber: 0, kind: .movie))
        try await FilmProcessor(root: beforeTheMovie.root).develop(filmID: beforeTheMovie.film.id)
        try await beforeTheMovie.assertDevelopedWithItsClipAndSound()
    }

    private struct Fixture {
        let directory: URL
        let root: URL
        let repository: FilmRepository
        let film: Film
        let source: Data

        /// A 16mm Film on the color Film Stock with one Recorded Clip with Live Audio, stopped early with its original
        /// to be removed once its Development is verified, as the Development sheet asks.
        init() async throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("DevelopmentSuspension-\(UUID())")
            root = directory.appendingPathComponent("App")
            let clip = try await RecordedSound.clip(seconds: 2, in: directory.appendingPathComponent("Fixtures"))
            source = try Data(contentsOf: clip.url)
            repository = try FilmRepository(rootURL: root)
            let loaded = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Synthetic reel",
                                                   movieOrientation: .portrait, filmStock: .color)
            try repository.saveMovieClip(filmID: loaded.id, sourceData: source, durationSeconds: clip.seconds,
                                         orientation: .portrait)
            film = try repository.completeEarly(filmID: loaded.id, confirmedCaptureCount: 1)
            try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false)
        }

        func remove() { try? FileManager.default.removeItem(at: directory) }

        /// Still developing and resumable, with the Recorded Clip and its sound as saved, and no developed result shown.
        func assertStoppedWithEverythingKept() async throws {
            let stopped = try repository.film(id: film.id)
            XCTAssertEqual(stopped.developmentState, .developing)
            XCTAssertEqual(stopped.captures.map(\.revealState), [.sealed])
            let kept = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
            XCTAssertEqual(try Data(contentsOf: kept.url), source, "The Recorded Clip is kept as it was saved")
            let sound = try await VerifiedMedia.movie(at: kept.url, allowsAudio: true)
            XCTAssertEqual(sound.audioTrackCount, 1, "with its Live Audio")
            XCTAssertNil(try repository.mediaAsset(filmID: film.id, sequenceNumber: 0, kind: .movie))
        }

        /// Developed, revealed, with the Developed Clip and the Developed Movie each carrying the clip's sound, and the
        /// original removed only after that, as chosen.
        func assertDevelopedWithItsClipAndSound() async throws {
            let developed = try repository.film(id: film.id)
            XCTAssertEqual(developed.developmentState, .developed)
            XCTAssertEqual(developed.captures.map(\.revealState), [.revealed])
            let clip = try repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .clip)
            let developedClip = try await VerifiedMedia.movie(at: clip.url, allowsAudio: true)
            XCTAssertEqual(developedClip.audioTrackCount, 1, "The Developed Clip keeps the clip's sound")
            let movie = try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)
            let developedMovie = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
            XCTAssertEqual(developedMovie.audioTrackCount, 1, "The Movie plays the recorded sound")
            XCTAssertEqual(try XCTUnwrap(developedMovie.durationSeconds), try XCTUnwrap(developedClip.durationSeconds),
                           accuracy: 0.001)
            XCTAssertNil(try repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source),
                         "The original goes once Development is verified, as chosen")
        }
    }
}

/// Stands in for the app leaving the screen partway through a Development, on an iPhone: at `stage` it stops processing
/// as the app does (`suspendProcessing`), waits for the stop to reach the Development, then fails as the clip's writer
/// does once iOS has taken its encoder.
private actor LeavesTheScreen {
    private let stage: DevelopmentStage
    private let failure: Error
    private var processor: FilmProcessor?
    private var armed = true
    private(set) var stopped = false

    init(at stage: DevelopmentStage, failingWith failure: Error) {
        self.stage = stage
        self.failure = failure
    }

    func attach(_ processor: FilmProcessor) { self.processor = processor }

    func observe(_ reached: DevelopmentStage) async throws {
        guard armed, reached == stage, let processor else { return }
        armed = false
        Task { await processor.suspendProcessing() }
        let deadline = ContinuousClock.now + .seconds(10)
        while !Task.isCancelled, ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        stopped = Task.isCancelled
        throw failure
    }
}
