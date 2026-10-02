import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderCore
import RenderFixtures
import XCTest

final class FilmExportTests: XCTestCase {
    func testPartialOriginalFailureRetainsSourcesAndRetrySkipsReceiptAlreadySaved() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (repository, film, processor, original) = try await setup(root: root, count: 2)
        let writer = RecordingWriter(failAt: 2)
        let coordinator = PhotoExportCoordinator(authorizer: Authorization(status: .authorized), writer: writer)
        do { try await processor.export(filmID: film.id, sequences: [1, 2], originals: true, coordinator: coordinator); XCTFail("Expected write failure") }
        catch FilmExportError.writeFailed { }
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 2, kind: .source))
        if case .exported = try repository.originalDisposition(filmID: film.id, sequenceNumber: 1) { }
        else { XCTFail("First successful write needs a durable receipt") }
        XCTAssertEqual(try repository.originalDisposition(filmID: film.id, sequenceNumber: 2), .exportRequested)
        let reopened = try FilmProcessor(root: root)
        try await reopened.export(filmID: film.id, sequences: [1, 2], originals: true, coordinator: coordinator)
        let writes = await writer.saved
        let attempts = await writer.attempts
        XCTAssertEqual(writes, [original, original])
        XCTAssertEqual(attempts, 3)
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertFalse(try repository.assetExists(filmID: film.id, sequenceNumber: 2, kind: .source))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .master))
    }

    func testDeniedAndSealedSelectionsNeverCallWriterOrCleanSources() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (repository, film, processor, original) = try await setup(root: root, count: 1)
        let writer = RecordingWriter()
        let denied = PhotoExportCoordinator(authorizer: Authorization(status: .denied), writer: writer)
        do { try await processor.export(filmID: film.id, sequences: [1], originals: true, coordinator: denied); XCTFail("Expected permission denial") }
        catch FilmExportError.permissionDenied { }
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        try repository.savePhotoCapture(filmID: film.id, sourceData: original)
        let authorized = PhotoExportCoordinator(authorizer: Authorization(status: .authorized), writer: writer)
        do { try await processor.export(filmID: film.id, sequences: [1, 2], originals: false, coordinator: authorized); XCTFail("Expected sealed rejection") }
        catch PersistenceError.mediaNotRevealed { }
        let calls = await writer.attempts
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(try repository.film(id: film.id).captures.map(\.revealState), [.revealed, .sealed])
    }

    func testDevelopedExportUsesEditWithoutChoosingOrDeletingOriginals() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (repository, film, processor, _) = try await setup(root: root, count: 1)
        let edited = try await processor.saveRecipe(filmID: film.id, sequence: 1, recipe: DarkroomRecipe(printExposureStops: 0.5))
        let writer = RecordingWriter()
        let coordinator = PhotoExportCoordinator(authorizer: Authorization(status: .authorized), writer: writer)
        try await processor.export(filmID: film.id, sequences: [1], originals: false, coordinator: coordinator)
        let exported = await writer.saved
        XCTAssertEqual(exported, [edited])
        XCTAssertNil(try repository.originalDisposition(filmID: film.id, sequenceNumber: 1))
        XCTAssertTrue(try repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        XCTAssertEqual(try repository.film(id: film.id).savedCaptureCount, 1)
    }

    func testSuspendingProcessingNeverCancelsAnExportWhosePhotosWriteIsInFlight() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (_, film, processor, _) = try await setup(root: root, count: 3)
        let writer = HeldWriter()
        let coordinator = PhotoExportCoordinator(authorizer: Authorization(status: .authorized), writer: writer)
        let export = Task { try await processor.export(filmID: film.id, sequences: [1, 2, 3], originals: false, coordinator: coordinator) }
        try await waitUntil { await writer.attempts == 1 }
        let suspension = Task { await processor.suspendProcessing() }
        try await Task.sleep(for: .milliseconds(100))
        await writer.release()
        await suspension.value
        try await export.value
        let attempts = await writer.attempts
        XCTAssertEqual(attempts, 3)
    }

    func testExportCancelledAfterAPhotosWriteReportsWhatWasAlreadySaved() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (repository, film, processor, _) = try await setup(root: root, count: 3)
        let writer = HeldWriter()
        let coordinator = PhotoExportCoordinator(authorizer: Authorization(status: .authorized), writer: writer)
        let export = Task { try await processor.export(filmID: film.id, sequences: [1, 2, 3], originals: false, coordinator: coordinator) }
        try await waitUntil { await writer.attempts == 1 }
        let discard = Task { try await processor.discard(filmID: film.id, sequence: 3) }
        try await Task.sleep(for: .milliseconds(100))
        await writer.release()
        do { try await export.value; XCTFail("A cancelled export cannot report full success") }
        catch FilmExportError.interrupted(saved: 1, total: 3) { }
        try await discard.value
        XCTAssertEqual(try repository.film(id: film.id).discardedPlaceholderSequenceNumbers, [3])
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(30)
        while !(await condition()) {
            guard ContinuousClock.now < deadline else { throw CancellationError() }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func setup(root: URL, count: Int) async throws -> (FilmRepository, Film, FilmProcessor, Data) {
        let fixtures = root.appendingPathComponent("Fixtures")
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures)
        let data = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.instant1970s, title: "Synthetic")
        for _ in 0..<count { try repository.savePhotoCapture(filmID: film.id, sourceData: data) }
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: film.id)
        return (repository, film, processor, data)
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("FilmExportTests-\(UUID())")
    }
}

private struct Authorization: PhotoLibraryAuthorizing {
    let status: PhotoLibraryAuthorizationStatus
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus { status }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus { status }
}

/// Holds the first Photos write until the test releases it.
private actor HeldWriter: PhotoLibraryWriting {
    private(set) var attempts = 0
    private var held: CheckedContinuation<Void, Never>?
    private var released = false
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        attempts += 1
        if attempts == 1, !released { await withCheckedContinuation { held = $0 } }
        return PhotoExportReceipt(localIdentifier: "synthetic-held-\(attempts)")
    }
    func release() {
        released = true
        held?.resume()
        held = nil
    }
}

private actor RecordingWriter: PhotoLibraryWriting {
    let failAt: Int?
    var attempts = 0
    var saved: [Data] = []
    init(failAt: Int? = nil) { self.failAt = failAt }
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        attempts += 1
        if attempts == failAt { throw CocoaError(.fileWriteOutOfSpace) }
        guard ["jpg", "jpeg", "heic", "mov"].contains(request.fileURL.pathExtension) else { throw PersistenceError.invalidMedia }
        saved.append(try Data(contentsOf: request.fileURL))
        return PhotoExportReceipt(localIdentifier: "synthetic-success-\(attempts)")
    }
}
