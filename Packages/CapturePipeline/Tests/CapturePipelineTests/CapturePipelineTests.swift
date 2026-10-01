import CapturePipeline
import FilmDomain
import FilmPersistence
import Foundation
import NativeAdapters
import XCTest

final class CapturePipelineTests: XCTestCase {
    func testPhotoSavedEventPersistsSourceAndDebitsOnlyAfterDurableSave() throws {
        let harness = try Harness()
        let film = try harness.repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        let payloadURL = try harness.writeSyntheticPayload("synthetic-photo")
        let pipeline = CapturePersistencePipeline(filmID: film.id, repository: harness.repository)

        let outcome = try pipeline.handle(.photoSaved(payloadURL))
        let persisted = try harness.repository.film(id: film.id)

        XCTAssertEqual(outcome, .photoCommitted(sequenceNumber: 1, remainingExposures: 26))
        XCTAssertEqual(persisted.savedCaptureCount, 1)
        XCTAssertTrue(try harness.repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
    }

    func testUnreadablePhotoPayloadDoesNotDebitCapacity() throws {
        let harness = try Harness()
        let film = try harness.repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        let missingURL = harness.rootURL.appendingPathComponent("missing.heic")
        let pipeline = CapturePersistencePipeline(filmID: film.id, repository: harness.repository)

        XCTAssertThrowsError(try pipeline.handle(.photoSaved(missingURL))) { error in
            guard case .unreadablePayload = error as? CapturePipelineError else {
                return XCTFail("Unexpected error \(error)")
            }
        }

        let persisted = try harness.repository.film(id: film.id)
        XCTAssertEqual(persisted.savedCaptureCount, 0)
        XCTAssertEqual(persisted.remainingExposures, 27)
    }

    func testMovieClipSavedEventPersistsDurationAndLockedOrientation() throws {
        let harness = try Harness()
        let film = try harness.repository.createFilm(
            camera: CameraCatalog.super8HomeMovie,
            title: "Super 8 - Roll #01",
            movieOrientation: .landscape
        )
        let payloadURL = try harness.writeSyntheticPayload("synthetic-movie")
        let pipeline = CapturePersistencePipeline(filmID: film.id, repository: harness.repository)

        let outcome = try pipeline.handle(
            .movieClipSaved(url: payloadURL, durationSeconds: 7, orientation: .landscape)
        )
        let persisted = try harness.repository.film(id: film.id)

        XCTAssertEqual(outcome, .movieClipCommitted(sequenceNumber: 1, remainingSeconds: 193))
        XCTAssertEqual(persisted.consumedMovieSeconds, 7)
        XCTAssertEqual(persisted.captures.last?.kind, .movieClip(seconds: 7, orientation: .landscape))
    }

    func testFailureAndInterruptionEventsDoNotChangeFilmState() throws {
        let harness = try Harness()
        let film = try harness.repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        let pipeline = CapturePersistencePipeline(filmID: film.id, repository: harness.repository)

        XCTAssertEqual(try pipeline.handle(.saveFailed("camera stopped")), .captureFailed("camera stopped"))
        XCTAssertEqual(try pipeline.handle(.interrupted(.systemPressure)), .interrupted(.systemPressure))
        XCTAssertEqual(try pipeline.handle(.interruptionEnded), .interruptionEnded)

        let persisted = try harness.repository.film(id: film.id)
        XCTAssertEqual(persisted.savedCaptureCount, 0)
    }

    func testRecoveryRemovesDurableOrphanLeftBeforeDebit() throws {
        let harness = try Harness()
        let film = try harness.repository.createFilm(
            camera: CameraCatalog.disposable1990s,
            title: "Disposable - Roll #01"
        )
        XCTAssertThrowsError(
            try harness.repository.savePhotoCapture(
                filmID: film.id,
                sourceData: Data("orphan".utf8),
                failureInjection: .afterDurableMoveBeforeDebit
            )
        )
        XCTAssertEqual(try harness.mediaFileCount(), 1)

        let pipeline = CapturePersistencePipeline(filmID: film.id, repository: harness.repository)
        XCTAssertEqual(try pipeline.recoverAfterLaunch(), .recovered)

        XCTAssertEqual(try harness.mediaFileCount(), 0)
        XCTAssertEqual(try harness.repository.film(id: film.id).savedCaptureCount, 0)
    }
}

private struct Harness {
    let rootURL: URL
    let repository: FilmRepository

    init() throws {
        rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CapturePipelineTests-\(UUID().uuidString)", isDirectory: true)
        repository = try FilmRepository(rootURL: rootURL)
    }

    func writeSyntheticPayload(_ name: String) throws -> URL {
        let url = rootURL.appendingPathComponent("\(name)-\(UUID().uuidString).bin")
        try Data(name.utf8).write(to: url, options: [.atomic])
        return url
    }

    func mediaFileCount() throws -> Int {
        let mediaURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        guard FileManager.default.fileExists(atPath: mediaURL.path) else {
            return 0
        }
        let files = FileManager.default.enumerator(
            at: mediaURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        var count = 0
        while let url = files?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                count += 1
            }
        }
        return count
    }
}
