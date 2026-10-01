import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import ProductionReceiptHarness
import RenderFixtures
import XCTest

final class ProductionProcessExitTests: XCTestCase {
    func testProductionOwnerRecoversActualProcessExitBeforeAndAfterReceiptAndProjection() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ProductionReceiptExit-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 160; settings.photoHeight = 120
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
        let fixtures = root.appendingPathComponent("Fixtures")
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let executable = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("ProductionReceiptCrashWorker")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        for camera in [CameraCatalog.disposable1990s, CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm] {
            for point in ["prepared", "receiptResolved", "projected"] {
                let app = root.appendingPathComponent("\(camera.id)-\(point)")
                let receipt = root.appendingPathComponent("Receipt-\(UUID()).json")
                let source = fixtures.appendingPathComponent(camera.medium == .photo ? "synthetic-developed-photo.jpg" : "synthetic-developed-movie.mov")
                let child = Process()
                child.executableURL = executable
                child.arguments = [app.path, receipt.path, source.path, camera.id.rawValue, point]
                try child.run()
                child.waitUntilExit()
                XCTAssertEqual(child.terminationReason, .exit)
                XCTAssertEqual(child.terminationStatus, 77)
                let repository = try FilmRepository(rootURL: app)
                let film = try XCTUnwrap(repository.allFilms().first)
                let store = KeychainDeviceTrialStore(calls: FileKeychainCalls(url: receipt))
                XCTAssertEqual(try store.read()?.isConsumed, point != "prepared")
                XCTAssertEqual(film.savedCaptureCount, point == "projected" ? 1 : 0)
                XCTAssertTrue(try repository.hasPendingCapture(filmID: film.id))
                try repository.recover()
                let owner = try TrialCoordinator(root: app, store: store)
                try await owner.recoverSavedCaptures()
                try await owner.recoverSavedCaptures()
                let saved = try repository.film(id: film.id)
                XCTAssertEqual(saved.savedCaptureCount, 1)
                XCTAssertEqual(saved.captures.first?.savedAt, Date(timeIntervalSince1970: 1_790_870_000))
                XCTAssertEqual(saved.captures.first?.revealState, .sealed)
                if camera.medium == .movie {
                    XCTAssertEqual(saved.consumedMovieSeconds, manifest.movie.durationSeconds)
                    XCTAssertEqual(saved.movieOrientation, .portrait)
                } else { XCTAssertEqual(saved.remainingExposures, 26) }
                let asset = try XCTUnwrap(repository.mediaAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
                let verified = camera.medium == .photo ? try VerifiedMedia.photo(at: asset.url) : try await VerifiedMedia.movie(at: asset.url)
                XCTAssertEqual(verified.sha256, asset.record.sha256)
                XCTAssertFalse(try repository.hasPendingCapture(filmID: film.id))
                XCTAssertTrue(try repository.pendingTrialConsumptions().isEmpty)
                let consumed = try XCTUnwrap(store.read())
                try await owner.deleteFilm(filmID: film.id)
                XCTAssertEqual(try store.read(), consumed)
                try FileManager.default.removeItem(at: app)
                let emptyInstall = try TrialCoordinator(root: app, store: store)
                guard case .consumed = try await emptyInstall.state() else { return XCTFail("Lost app storage must not refund") }
                print("PRODUCTION_PROCESS_EXIT camera=\(camera.id) point=\(point) status=77 recovered=1 sealed=true hash=\(verified.sha256) storageLoss=consumed")
            }
        }
    }
}
