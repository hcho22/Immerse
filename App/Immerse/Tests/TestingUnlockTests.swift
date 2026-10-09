#if DEBUG
import EntitlementCore
import FilmDomain
import FilmPersistence
import NativeAdapters
import XCTest
@testable import Immerse

/// The Debug-only testing unlock loads every Camera as a subscription Film without reading or
/// writing this iPhone's Trial record, and turning it off restores the original Trial gating.
/// Receipts use in-memory Keychain calls; `Scripts/verify-release-excludes-testing-unlock.sh`
/// proves Release has no unlock.
@MainActor
final class TestingUnlockTests: XCTestCase {
    func testSwitchStartsOnInADebugBuildAndPersistsAcrossLaunches() throws {
        let suite = "TestingUnlock-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(TestingUnlock(defaults: defaults).enabled, "A Debug build starts unlocked")
        TestingUnlock(defaults: defaults).enabled = false
        XCTAssertFalse(TestingUnlock(defaults: defaults).enabled, "Off holds on the next launch")
        TestingUnlock(defaults: defaults).enabled = true
        XCTAssertTrue(TestingUnlock(defaults: defaults).enabled, "On again holds on the next launch")
        XCTAssertFalse(TestingUnlock(defaults: nil).enabled, "Directly constructed Journals keep the shipping gate")
        XCTAssertFalse(try JournalModel(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("TestingUnlockDefault-\(UUID())"),
            trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls())).testingUnlock.enabled)
    }

    func testUnlockLoadsEveryCameraWithoutTouchingTheTrialOrStoreKit() async throws {
        let (root, calls, model) = try await makeModel(unlocked: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for camera in CameraCatalog.all {
            let film = try await model.load(camera: camera, title: "Unlocked \(camera.shortName)", orientation: .landscape, filmStock: camera.defaultFilmStock)
            XCTAssertEqual(try model.repository.filmAccess(filmID: film.id), .subscription, camera.shortName)
            XCTAssertEqual(film.movieOrientation, camera.medium == .movie ? .landscape : nil, camera.shortName)
        }
        XCTAssertEqual(Set(model.films.map(\.camera.id)), Set(CameraCatalog.all.map(\.id)))
        let first = try XCTUnwrap(model.films.first { $0.camera.id == CameraCatalog.disposable1990s.id })
        try await save(first, model)
        XCTAssertEqual(model.film(first.id)?.savedCaptureCount, 1)
        XCTAssertFalse(calls.wasWritten, "Loading and saving while unlocked never writes the Trial record")
        let state = try await model.trial.state()
        XCTAssertEqual(state, .unused)
        XCTAssertEqual(model.billing.access, .notPurchased, "Verified StoreKit access is unchanged")
    }

    func testSwitchedOffTheTrialAndItsLimitsApplyAsInRelease() async throws {
        let (root, calls, model) = try await makeModel(unlocked: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try await model.load(camera: CameraCatalog.cinema16mm, title: "Trial roll", orientation: .portrait, filmStock: .color)
        guard case .trial = try model.repository.filmAccess(filmID: film.id) else { return XCTFail("Uses the Trial") }
        XCTAssertTrue(calls.wasWritten)
        do {
            _ = try await model.load(camera: CameraCatalog.disposable1990s, title: "Second", orientation: .portrait)
            XCTFail("The Trial Film in progress refuses another")
        } catch JournalError.trialInProgress(film.id) { }
        try await model.remove(film.id)
        let used = try await model.load(camera: CameraCatalog.disposable1990s, title: "Trial photos", orientation: .portrait)
        try await save(used, model)
        guard case .consumed = try await model.trial.state() else { return XCTFail("The first save consumes the Trial") }
        do {
            _ = try await model.load(camera: CameraCatalog.instant1970s, title: "Locked", orientation: .portrait)
            XCTFail("A used Trial without a subscription refuses another Film")
        } catch JournalError.subscriptionUnavailable { }
    }

    func testTurningTheUnlockOffKeepsItsFilmsUsableAndRestoresTrialGating() async throws {
        let (root, calls, model) = try await makeModel(unlocked: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let photos = try await model.load(camera: CameraCatalog.mediumFormat6x6, title: "Unlocked 6×6", orientation: .portrait, filmStock: .color)
        let movie = try await model.load(camera: CameraCatalog.super8HomeMovie, title: "Unlocked Super 8", orientation: .portrait)
        try await save(photos, model)

        model.testingUnlock.enabled = false
        XCTAssertFalse(calls.wasWritten)
        let state = try await model.trial.state()
        XCTAssertEqual(state, .unused, "The unlock left the Trial unused")
        try await save(photos, model)
        XCTAssertEqual(model.film(photos.id)?.savedCaptureCount, 2, "An unlocked Film keeps its capture rights")
        _ = try model.repository.completeEarly(filmID: photos.id, confirmedCaptureCount: 2)
        try await model.develop(photos.id)
        XCTAssertEqual(model.film(photos.id)?.captures.map(\.revealState), [.revealed, .revealed])
        XCTAssertNotNil(model.film(movie.id))

        let trial = try await model.load(camera: CameraCatalog.disposable1990s, title: "Trial roll", orientation: .portrait)
        let device = try XCTUnwrap(KeychainDeviceTrialStore(calls: calls).read()?.deviceID)
        XCTAssertEqual(try model.repository.filmAccess(filmID: trial.id), .trial(originDevice: device))
        do {
            _ = try await model.load(camera: CameraCatalog.instant1970s, title: "Second", orientation: .portrait)
            XCTFail("Gating returns once the unlock is off")
        } catch JournalError.trialInProgress(trial.id) { }
    }

    private func makeModel(unlocked: Bool) async throws -> (URL, HeldReceiptCalls, JournalModel) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TestingUnlock-\(UUID())")
        let calls = HeldReceiptCalls()
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: calls),
                                     cameraAuthorizer: SyntheticCamera(granted: true))
        model.testingUnlock.enabled = unlocked
        await model.recoverAtLaunch()
        return (root, calls, model)
    }

    /// Commits a staged photo through the Trial owner, exactly as the capture backend's save does.
    private func save(_ film: Film, _ model: JournalModel) async throws {
        let files = try CapturedMediaFiles(directory: model.repository.captureStagingDirectory(filmID: film.id))
        let source = try files.savePhoto(syntheticPhoto(), id: UUID())
        try await model.trial.receiver(filmID: film.id).commit(.photoSaved(source))
        try files.removeCommittedFile(for: .photoSaved(source))
        model.refresh()
    }
}
#endif
