import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import NativeAdapters
import RenderCore
import Security
import Synchronization
import UIKit
import XCTest
@testable import Immerse

@MainActor
final class JournalIntegrationTests: XCTestCase {
    func testExistingFilmDevelopEditResetDiscardArchiveAndDeleteWithoutSubscription() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JournalIntegration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        await model.recoverAtLaunch()
        XCTAssertFalse(model.billing.configured)
        let film = try model.repository.createFilm(camera: CameraCatalog.disposable1990s,
                                                   title: "Synthetic existing Film", access: .subscription)
        let source = try syntheticPhoto()
        for _ in 0..<2 { try model.repository.savePhotoCapture(filmID: film.id, sourceData: source) }
        model.refresh()
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.sealed, .sealed])
        do { _ = try await model.processor.photo(filmID: film.id, sequence: 1); XCTFail("Sealed photo leaked") }
        catch { }
        _ = try model.repository.completeEarly(filmID: film.id, confirmedCaptureCount: 2)
        XCTAssertEqual(try model.repository.film(id: film.id).remainingLabel, "25 exposures wasted")
        XCTAssertEqual(try model.repository.film(id: film.id).progress, 1)
        try model.chooseOriginals(film.id, sequences: [1, 2], export: false)
        XCTAssertThrowsError(try model.repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .source))
        try await model.develop(film.id)
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.revealed, .revealed])
        XCTAssertFalse(try model.repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))
        let original = try await model.processor.photo(filmID: film.id, sequence: 1)
        let second = try await model.processor.photo(filmID: film.id, sequence: 2)
        XCTAssertNotNil(DisplayPhoto.image(original))
        let edited = try await model.processor.saveRecipe(filmID: film.id, sequence: 1,
            recipe: DarkroomRecipe(printExposureStops: 0.5, dodgeBurnMasks: [
                LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 0.4)
            ]))
        XCTAssertNotEqual(edited, original)
        let reset = try await model.processor.saveRecipe(filmID: film.id, sequence: 1, recipe: .original)
        XCTAssertEqual(reset, original)
        let unchanged = try await model.processor.photo(filmID: film.id, sequence: 2)
        XCTAssertEqual(unchanged, second)
        try model.chooseOriginals(film.id, sequences: [1, 2], export: false)
        try await model.processor.cleanupSources(filmID: film.id)
        XCTAssertFalse(try model.repository.assetExists(filmID: film.id, sequenceNumber: 1, kind: .source))

        let master = try model.repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .master)
        let revision = model.mediaRevision
        try await model.remove(film.id, sequence: 1)
        XCTAssertNotEqual(model.mediaRevision, revision)
        XCTAssertEqual(model.film(film.id)?.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertEqual(model.film(film.id)?.remainingExposures, 25)
        XCTAssertEqual(model.film(film.id)?.remainingLabel, "25 exposures wasted")
        XCTAssertEqual(model.film(film.id)?.progress, 1)
        XCTAssertNotEqual(model.film(film.id)?.completionState, .open)
        XCTAssertFalse(FileManager.default.fileExists(atPath: master.url.path))
        XCTAssertThrowsError(try model.repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .master))
        try model.repository.rename(filmID: film.id, title: "Renamed")
        try model.repository.setArchived(filmID: film.id, archived: true)
        let reopened = try JournalModel(root: root)
        await reopened.recoverAtLaunch()
        XCTAssertEqual(reopened.film(film.id)?.title, "Renamed")
        XCTAssertEqual(reopened.film(film.id)?.isArchived, true)
        let retained = try await reopened.processor.photo(filmID: film.id, sequence: 2)
        XCTAssertEqual(retained, second)
        try await reopened.remove(film.id)
        XCTAssertNil(reopened.film(film.id))
        XCTAssertTrue(try reopened.repository.allFilms().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id)").path))
    }

    func testEmptyFilmCannotDevelopAndCanBeDeleted() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EmptyJournalIntegration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        await model.recoverAtLaunch()
        let film = try model.repository.createFilm(camera: CameraCatalog.super8HomeMovie,
                                                   title: "Empty synthetic Movie", movieOrientation: .portrait)
        model.refresh()
        XCTAssertFalse(try XCTUnwrap(model.film(film.id)).canStartDevelopment)
        XCTAssertThrowsError(try model.repository.completeEarly(filmID: film.id, confirmedCaptureCount: 0))
        try await model.remove(film.id)
        XCTAssertNil(model.film(film.id))
    }

    func testLaunchAndResumeSaveUseReceiptOwnerBeforeShowingUsableCapacity() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JournalPending-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let calls = JournalReceiptCalls()
        let store = KeychainDeviceTrialStore(calls: calls)
        let owner = try TrialCoordinator(root: root, store: store)
        let film = try await owner.start(camera: CameraCatalog.disposable1990s, title: "Pending private capture")
        let repository = try FilmRepository(rootURL: root)
        let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
        let source = try files.savePhoto(syntheticPhoto(), id: UUID())
        calls.rejectUpdate = true
        let receiver = try await owner.receiver(filmID: film.id)
        do { try await receiver.commit(.photoSaved(source)); XCTFail("Unknown save must remain pending") } catch { }
        let model = try JournalModel(root: root, trialStore: store)
        XCTAssertTrue(model.hasPendingSave(film.id))
        await model.recoverAtLaunch()
        XCTAssertTrue(model.hasPendingSave(film.id))
        XCTAssertEqual(model.film(film.id)?.savedCaptureCount, 0)
        XCTAssertNotNil(model.alert)
        do { try await model.develop(film.id); XCTFail("Cannot develop a pending capture") }
        catch JournalError.operationInProgress { }
        calls.rejectUpdate = false
        try await model.recoverCapture(film.id)
        XCTAssertFalse(model.hasPendingSave(film.id))
        XCTAssertEqual(model.film(film.id)?.savedCaptureCount, 1)
        XCTAssertEqual(model.film(film.id)?.remainingExposures, 26)
        XCTAssertEqual(model.film(film.id)?.captures.first?.revealState, .sealed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(calls.calledOnMain, "UI-originated recovery must not call Security on main")
        XCTAssertEqual(try store.read()?.consumedCaptureID, source.lastPathComponent)
        try await model.remove(film.id)
        XCTAssertNil(model.film(film.id))
        guard case .consumed = try await model.trial.state() else { return XCTFail("Delete cannot refund") }
    }

    func testWholeFilmDeletionCanRemoveUnresolvedSaveWithoutReadingUnavailableKeychain() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JournalUnknownDelete-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let calls = JournalReceiptCalls()
        let store = KeychainDeviceTrialStore(calls: calls)
        let model = try JournalModel(root: root, trialStore: store)
        await model.recoverAtLaunch()
        let film = try await model.trial.start(camera: CameraCatalog.instant1970s, title: "Unknown first save")
        let files = try CapturedMediaFiles(directory: model.repository.captureStagingDirectory(filmID: film.id))
        let source = try files.savePhoto(syntheticPhoto(), id: UUID())
        calls.hideReadAfterUpdate = true
        let receiver = try await model.trial.receiver(filmID: film.id)
        do { try await receiver.commit(.photoSaved(source)); XCTFail("Readback unavailable") } catch { }
        model.refresh()
        XCTAssertTrue(model.hasPendingSave(film.id))
        try await model.remove(film.id)
        XCTAssertNil(model.film(film.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Staging/\(film.id)").path))
        calls.makeReadable()
        guard case .consumed = try await model.trial.state() else { return XCTFail("Unknown committed outcome cannot refund") }
    }

    private func syntheticPhoto() throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 96), format: format).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 96))
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 64, y: 0, width: 64, height: 96))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }
}

private final class JournalReceiptCalls: TrialKeychainCalling, Sendable {
    private struct State {
        var data = try! JSONEncoder().encode(DeviceTrialRecord())
        var rejectUpdate = false
        var hideReadAfterUpdate = false
        var unreadable = false
        var onMain = false
    }
    private let state = Mutex(State())
    var rejectUpdate: Bool {
        get { state.withLock { $0.rejectUpdate } }
        set { state.withLock { $0.rejectUpdate = newValue } }
    }
    var hideReadAfterUpdate: Bool {
        get { state.withLock { $0.hideReadAfterUpdate } }
        set { state.withLock { $0.hideReadAfterUpdate = newValue } }
    }
    var calledOnMain: Bool { state.withLock { $0.onMain } }
    func makeReadable() { state.withLock { $0.unreadable = false; $0.hideReadAfterUpdate = false } }
    func read(service: String) -> TrialKeychainRead {
        state.withLock {
            $0.onMain = $0.onMain || Thread.isMainThread
            return TrialKeychainRead(status: $0.unreadable ? errSecInteractionNotAllowed : errSecSuccess,
                data: $0.unreadable ? nil : $0.data)
        }
    }
    func add(service: String, data: Data) -> OSStatus { errSecDuplicateItem }
    func update(service: String, data: Data) -> OSStatus {
        state.withLock {
            $0.onMain = $0.onMain || Thread.isMainThread
            if !$0.rejectUpdate { $0.data = data }
            $0.unreadable = $0.hideReadAfterUpdate
            return $0.rejectUpdate ? errSecNotAvailable : errSecSuccess
        }
    }
}
