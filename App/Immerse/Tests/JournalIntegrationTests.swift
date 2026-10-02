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

    func testPermissionAndStorageFailuresGiveGuidanceWithoutPlaceholderErrorText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FailureCopy-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        model.report(FilmExportError.permissionDenied)
        let alert = try XCTUnwrap(model.alert)
        XCTAssertEqual(alert.title, "Could not finish")
        XCTAssertTrue(alert.message.contains("Photos access is off"), alert.message)
        XCTAssertFalse(alert.message.contains("storage"), alert.message)
        model.alert = nil
        model.report(CancellationError())
        XCTAssertNil(model.alert)

        // The simulator cannot stage a denied camera, so the reopen copy is checked here.
        let camera = try XCTUnwrap(FailureCopy.message(for: JournalError.cameraDenied))
        XCTAssertTrue(camera.contains("iPhone Settings"), camera)
        XCTAssertFalse(camera.contains("No new Film"), "Reopening an existing Film's camera loads nothing")
        let keychain = try XCTUnwrap(FailureCopy.message(for: trialRecordFailure(errSecInteractionNotAllowed)))
        XCTAssertFalse(keychain.contains("storage"), keychain)
        XCTAssertTrue(keychain.contains("has not been reset"), keychain)
        let storage = try XCTUnwrap(FailureCopy.message(for: CocoaError(.fileWriteOutOfSpace)))
        XCTAssertTrue(storage.hasPrefix(FailureCopy.retry), storage)
        XCTAssertTrue(storage.contains("enough space"), storage)
        let failures: [Error] = [JournalError.cameraDenied, FilmExportError.permissionDenied, FilmExportError.needsPermission,
                                 FilmExportError.writeFailed("synthetic"), FilmExportError.missingReceipt,
                                 PersistenceError.invalidMedia, NativeCaptureError.invalidMedia, CocoaError(.fileReadNoPermission),
                                 trialRecordFailure(errSecNotAvailable)]
        for failure in failures {
            let message = try XCTUnwrap(FailureCopy.message(for: failure))
            XCTAssertFalse(message.contains("couldn’t be completed"), message)
            XCTAssertFalse(message.contains("error"), message)
        }
    }

    func testJournalThatCannotOpenItsStorageFailsWithoutCrashing() async throws {
        // A regular file where the Journal directory belongs, as when app storage cannot be opened.
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("JournalBlocked-\(UUID())")
        try Data().write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        XCTAssertThrowsError(try JournalModel(root: blocker.appendingPathComponent("FilmJournal")))
    }

    func testTryAgainWhileTheJournalIsOpeningOpensOnlyOneJournal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JournalLauncher-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        var opened = 0
        let launcher = JournalLauncher {
            opened += 1
            return try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                    cameraAuthorizer: SyntheticCamera(granted: true))
        }
        async let first: Void = launcher.open()
        async let second: Void = launcher.open()
        _ = await (first, second)
        XCTAssertEqual(opened, 1, "A second open would add a second Trial owner for the same storage")
        XCTAssertNotNil(launcher.model)
        XCTAssertFalse(launcher.opening)
    }

    func testRemovalWhileTheFilmIsAlreadyBeingRemovedIsRefusedAndKeepsItHidden() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JournalRemoval-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        await model.recoverAtLaunch()
        let film = try model.repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic roll")
        model.refresh()
        // A Discard or Delete Film for this Film is still in flight.
        model.hiddenFilms.insert(film.id)
        do { try await model.remove(film.id); XCTFail("A second removal must wait for the first") }
        catch JournalError.operationInProgress { }
        XCTAssertTrue(model.hiddenFilms.contains(film.id))
        XCTAssertNotNil(model.film(film.id))
        XCTAssertEqual(FailureCopy.message(for: JournalError.operationInProgress),
                       "Another change to this Film is still finishing. Try again when it completes.")
    }

    func testEarlyCompletionWarningShowsUnusedSecondsLikeTheOtherMovieLabels() throws {
        var film = try Film(camera: CameraCatalog.super8HomeMovie, title: "Synthetic reel", movieOrientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(104), orientation: .landscape)
        XCTAssertEqual(film.exactWasteLabel, "196.533 unused seconds")
        XCTAssertEqual(film.remainingLabel, "196.533 seconds left")
    }

    func testLoadSheetDescribesTheEntitlementThatLoadingWillUse() {
        XCTAssertEqual(LoadCopy.note(access: .active, trial: .unused, medium: .photo, subscriptionsAvailable: true),
                       "This Film is included in your subscription. Your Camera cannot change after loading.")
        XCTAssertEqual(LoadCopy.note(access: .notPurchased, trial: .unused, medium: .movie, subscriptionsAvailable: true),
                       "The first saved capture uses this iPhone's Trial. Your Camera and Movie Orientation cannot change after loading.")
        let consumed = DeviceTrialState.consumed(record: DeviceTrialConsumptionRecord(filmID: UUID(), consumedAt: Date()))
        XCTAssertEqual(LoadCopy.note(access: .expired, trial: consumed, medium: .photo, subscriptionsAvailable: true),
                       "This iPhone's Trial is used. A subscription is required to load another Film. Your Camera cannot change after loading.")
        XCTAssertEqual(LoadCopy.note(access: .notPurchased, trial: nil, medium: .photo, subscriptionsAvailable: true),
                       "Your Camera cannot change after loading.")
    }

    func testLoadSheetNeverSuggestsSubscribingInABuildWithoutSubscriptions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LoadCopyUnconfigured-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        XCTAssertFalse(model.billing.configured)
        let consumed = DeviceTrialState.consumed(record: DeviceTrialConsumptionRecord(filmID: UUID(), consumedAt: Date()))
        XCTAssertEqual(LoadCopy.note(access: model.billing.access, trial: consumed, medium: .photo,
                                     subscriptionsAvailable: model.billing.configured),
                       "This iPhone's Trial is used. Subscriptions are not available in this build. Your Camera cannot change after loading.")
        XCTAssertEqual(LoadCopy.note(access: model.billing.access, trial: .emptyFilmInProgress(filmID: UUID()), medium: .movie,
                                     subscriptionsAvailable: model.billing.configured),
                       "This iPhone's Trial Film is already loaded. Open or delete it first. Your Camera and Movie Orientation cannot change after loading.")
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
}

/// The error the production store raises when Keychain returns `status`.
private func trialRecordFailure(_ status: OSStatus) -> Error {
    do { _ = try KeychainDeviceTrialStore(calls: FailingReceiptCalls(status: status)).read() }
    catch { return error }
    XCTFail("Keychain status \(status) did not fail the Trial record read")
    return CancellationError()
}

private struct FailingReceiptCalls: TrialKeychainCalling {
    let status: OSStatus
    func read(service: String) -> TrialKeychainRead { TrialKeychainRead(status: status, data: nil) }
    func add(service: String, data: Data) -> OSStatus { status }
    func update(service: String, data: Data) -> OSStatus { status }
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
