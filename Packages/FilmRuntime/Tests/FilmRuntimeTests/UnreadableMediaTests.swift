@preconcurrency import AVFoundation
import CoreImage
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderCore
import RenderFixtures
import Synchronization
import XCTest

/// A movie read that does not finish now throws `PersistenceError.unreadableMedia` with what AVFoundation said, where it
/// threw a bare `invalidMedia` before. Development, a save to Photos and a capture's save each stop there as they did,
/// keep what they had, and finish once the media reads again. A clip cut off partway stands in for a decoder that fails
/// partway (`Evidence/NativeApp/developed-clip-reader-failure-070.md`): both end the read with status failed.
final class UnreadableMediaTests: XCTestCase {
    func testDevelopmentStopsWhereItWasWhenAStoredClipCannotBeRead() async throws {
        let root = makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (repository, film) = try await movieFilm(root: root)
        let unreadable = try await Self.cutOffClip(in: root)
        let replaced = Mutex<Data?>(nil)
        // Development stores the clip and then reads it back; the stored clip stops reading partway in between.
        let processor = try FilmProcessor(root: root, developmentObserver: { filmID, stage in
            guard stage == .afterPersistence(sequence: 1) else { return }
            let clip = try XCTUnwrap(FilmRepository(rootURL: root).mediaAsset(filmID: filmID, sequenceNumber: 1, kind: .clip)).url
            let developed = try Data(contentsOf: clip)
            replaced.withLock { $0 = developed }
            try unreadable.write(to: clip)
        })
        do {
            try await processor.develop(filmID: film.id)
            XCTFail("A Film whose stored clip cannot be read developed")
        } catch let PersistenceError.unreadableMedia(failure) {
            Self.assertNamesAVFoundationsError(failure)
        }
        let stopped = try repository.film(id: film.id)
        XCTAssertEqual(stopped.captures.map(\.revealState), [.sealed])
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertEqual(try repository.developmentRun(filmID: film.id)?.assignments.keys.sorted(), [1])
        XCTAssertFalse(try repository.assembledMovieExists(filmID: film.id))
        let clip = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .clip)).url
        try XCTUnwrap(replaced.withLock { $0 }).write(to: clip)
        try await FilmProcessor(root: root).develop(filmID: film.id)
        XCTAssertEqual(try repository.film(id: film.id).captures.map(\.revealState), [.revealed])
        XCTAssertTrue(try repository.assembledMovieExists(filmID: film.id))
    }

    func testSavingToPhotosSavesNothingWhenTheMovieCannotBeRead() async throws {
        let root = makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (repository, film) = try await movieFilm(root: root)
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: film.id)
        let movie = try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie)
        let whole = try Data(contentsOf: movie.url)
        try await Self.cutOffClip(in: root).write(to: movie.url)
        let writer = CountingWriter()
        let coordinator = PhotoExportCoordinator(authorizer: AllowedPhotos(), writer: writer)
        do {
            try await processor.export(filmID: film.id, sequences: [1], originals: false, coordinator: coordinator)
            XCTFail("A Movie that cannot be read was saved to Photos")
        } catch let PersistenceError.unreadableMedia(failure) {
            Self.assertNamesAVFoundationsError(failure)
        }
        let attempts = await writer.attempts
        XCTAssertEqual(attempts, 0)
        XCTAssertEqual(try repository.film(id: film.id).captures.map(\.revealState), [.revealed])
        XCTAssertEqual(try repository.revealedAsset(filmID: film.id, sequenceNumber: 0, kind: .movie).record, movie.record)
        try whole.write(to: movie.url)
        try await processor.export(filmID: film.id, sequences: [1], originals: false, coordinator: coordinator)
        let retried = await writer.attempts
        XCTAssertEqual(retried, 1)
    }

    func testACaptureThatCannotBeReadWaitsUnsavedForItsRetry() async throws {
        let root = makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = MemoryDeviceStore()
        let coordinator = try TrialCoordinator(root: root, store: store)
        let film = try await coordinator.start(camera: CameraCatalog.super8HomeMovie, title: "Unreadable capture",
                                               orientation: .portrait)
        let repository = try FilmRepository(rootURL: root)
        let staging = try repository.captureStagingDirectory(filmID: film.id)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let whole = root.appendingPathComponent("whole.mov")
        try await Self.writeClip(to: whole)
        let seconds = try await AVURLAsset(url: whole).loadTracks(withMediaType: .video)[0].load(.timeRange).duration.seconds
        let source = staging.appendingPathComponent("\(UUID()).mov")
        try await Self.cutOffClip(in: root).write(to: source)
        let receiver = try await coordinator.receiver(filmID: film.id)
        let event = CaptureSaveEvent.movieClipSaved(url: source, durationSeconds: seconds, orientation: .landscape)
        do {
            try await receiver.commit(event)
            XCTFail("A capture that cannot be read was saved")
        } catch let PersistenceError.unreadableMedia(failure) {
            Self.assertNamesAVFoundationsError(failure)
        }
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "The recording waits for its retry")
        XCTAssertFalse(try XCTUnwrap(store.read()).isConsumed)
        let commits = try FileManager.default.contentsOfDirectoryIfPresent(at: staging.appendingPathComponent("Commit"))
        XCTAssertTrue(commits.isEmpty, "\(commits)")
        try Data(contentsOf: whole).write(to: source)
        try await receiver.commit(event)
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
    }

    /// A Super 8 Film of one synthetic clip, completed early, its original declined.
    private func movieFilm(root: URL) async throws -> (FilmRepository, Film) {
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        let fixtures = root.appendingPathComponent("Fixtures")
        let generated = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let repository = try FilmRepository(rootURL: root)
        let camera = CameraCatalog.super8HomeMovie
        let film = try repository.createFilm(camera: camera, title: "Unreadable media", movieOrientation: .portrait,
                                             filmStock: camera.defaultFilmStock, access: .subscription)
        try repository.saveMovieClip(filmID: film.id,
            sourceData: Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov")),
            durationSeconds: generated.movie.durationSeconds, orientation: .landscape)
        try repository.completeEarly(filmID: film.id)
        try repository.chooseOriginalExport(filmID: film.id, sequenceNumber: 1, export: false)
        return (repository, film)
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("UnreadableMediaTests-\(UUID())")
    }

    private static func assertNamesAVFoundationsError(_ failure: MediaReadFailure, file: StaticString = #filePath,
                                                      line: UInt = #line) {
        XCTAssertEqual(failure.stage, .picture, "\(failure)", file: file, line: line)
        XCTAssertEqual(failure.errors.first?.domain, AVFoundationErrorDomain, "\(failure)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(failure.errors.count, 2, "\(failure)", file: file, line: line)
    }

    /// The bytes of a clip whose index leads the file, cut off three quarters of the way through, so it opens and then
    /// stops reading partway.
    private static func cutOffClip(in root: URL) async throws -> Data {
        let url = root.appendingPathComponent("cut-\(UUID()).mov")
        try await writeClip(to: url)
        let data = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        return data.prefix(data.count * 3 / 4)
    }

    /// Two seconds of H.264 at 30 fps with its index first, a different color each frame.
    private static func writeClip(to url: URL) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 240)
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &buffer)
            let gray = CGFloat(frame % 10) / 10
            context.render(CIImage(color: CIColor(red: gray, green: 1 - gray, blue: gray / 2)).cropped(to: bounds),
                           to: try XCTUnwrap(buffer), bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
            XCTAssertTrue(adaptor.append(try XCTUnwrap(buffer), withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
    }
}

private struct AllowedPhotos: PhotoLibraryAuthorizing {
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus { .authorized }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus { .authorized }
}

private actor CountingWriter: PhotoLibraryWriting {
    private(set) var attempts = 0
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        attempts += 1
        return PhotoExportReceipt(localIdentifier: "synthetic-unreadable-media-\(attempts)")
    }
}
