import EntitlementCore
import FilmDomain
import FilmPersistence
import NativeAdapters
import Security
import Synchronization
import UIKit
import XCTest
@testable import Immerse

/// Drives the actual `CaptureController` and `AVFoundationCaptureBackend` attached to real
/// repository, Trial owner and processor state. The simulator has no camera, so `open`
/// attaches the backend and recovers staged saves, then fails before a session starts.
/// A staged photo stands in for a capture whose save has not finished: it is exactly what
/// the backend leaves in the Film's staging directory. Receipts use in-memory Keychain calls.
@MainActor
final class CaptureControllerIntegrationTests: XCTestCase {
    func testDiscardingRevealedPrintKeepsAnotherCapturesUnfinishedSave() async throws {
        let (root, _, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try model.repository.createFilm(camera: CameraCatalog.instant1970s,
                                                   title: "Synthetic Instant pack", access: .subscription)
        try model.repository.savePhotoCapture(filmID: film.id, sourceData: syntheticPhoto())
        try await model.develop(film.id)
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.revealed])
        try await openWithoutSimulatorCamera(film, model)
        XCTAssertEqual(model.capture.filmID, film.id)

        let unfinished = try stageUnfinishedSave(film, model)
        model.refresh()
        XCTAssertTrue(model.hasPendingSave(film.id))
        try await model.remove(film.id, sequence: 1)
        XCTAssertEqual(model.film(film.id)?.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertTrue(FileManager.default.fileExists(atPath: unfinished.path),
                      "Discarding print 1 must not delete another capture's unfinished save")
        XCTAssertTrue(model.hasPendingSave(film.id))

        try await model.recoverCapture(film.id)
        XCTAssertFalse(model.hasPendingSave(film.id))
        XCTAssertEqual(model.film(film.id)?.savedCaptureCount, 2)
        XCTAssertEqual(model.film(film.id)?.remainingExposures, 8)
        XCTAssertEqual(model.film(film.id)?.discardedPlaceholderSequenceNumbers, [1])
        XCTAssertFalse(FileManager.default.fileExists(atPath: unfinished.path))
    }

    func testResumeSaveForAttachedInstantCameraShowsNoFailure() async throws {
        let (root, _, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try model.repository.createFilm(camera: CameraCatalog.instant1970s,
                                                   title: "Synthetic Instant pack", access: .subscription)
        try await openWithoutSimulatorCamera(film, model)
        _ = try stageUnfinishedSave(film, model)
        model.refresh()

        try await model.recoverCapture(film.id)
        try await settle(model)
        XCTAssertNil(model.alert, model.alert?.message ?? "")
        XCTAssertEqual(model.film(film.id)?.savedCaptureCount, 1)
        XCTAssertFalse(model.hasPendingSave(film.id))
        // A print saved while Resume Save owns the Film stays sealed for Resume Development.
        if model.film(film.id)?.captures.first?.revealState == .sealed { try await model.develop(film.id) }
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.revealed])
    }

    func testDoneDuringCameraOpenFinishesTheSaveWithoutStartingTheSession() async throws {
        let (root, calls, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try await model.trial.start(camera: CameraCatalog.disposable1990s, title: "Synthetic Trial roll")
        let unfinished = try stageUnfinishedSave(film, model)
        calls.holdNextUpdate()
        let opening = Task { try await model.capture.open(film: film, model: model) }
        try await waitUntil { calls.isHolding }

        model.capture.suspend()
        calls.release()
        let result = await opening.result
        XCTAssertNoThrow(try result.get(), "After Done, open must stop instead of starting the camera session")
        XCTAssertNil(model.capture.preview)
        XCTAssertEqual(model.capture.phase, .interrupted)
        model.refresh()
        XCTAssertEqual(model.film(film.id)?.savedCaptureCount, 1)
        XCTAssertEqual(model.film(film.id)?.captures.map(\.revealState), [.sealed])
        XCTAssertFalse(model.hasPendingSave(film.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: unfinished.path))
        guard case .consumed = try await model.trial.state() else { return XCTFail("The saved first capture consumes the Trial") }
    }

    func testDeletingFilmWhileItsSaveIsHeldIgnoresTheLateSaveEvent() async throws {
        let (root, calls, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try await model.trial.start(camera: CameraCatalog.instant1970s, title: "Synthetic Trial pack")
        _ = try stageUnfinishedSave(film, model)
        calls.holdNextUpdate()
        let opening = Task { try await model.capture.open(film: film, model: model) }
        try await waitUntil { calls.isHolding }

        model.capture.suspend()
        let removal = Task { try await model.remove(film.id) }
        try await waitUntil { model.hiddenFilms.contains(film.id) }
        calls.release()
        try await removal.value
        _ = await opening.result
        try await settle(model)
        XCTAssertNil(model.film(film.id))
        XCTAssertNil(model.alert, model.alert?.message ?? "")
        XCTAssertNil(model.capture.filmID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Staging/\(film.id)").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Media/\(film.id)").path))
        guard case .consumed = try await model.trial.state() else { return XCTFail("Deleting a saved Trial Film cannot refund") }
    }

    func testOpeningAnotherFilmFinishesThePreviousFilmsSaveFirst() async throws {
        let (root, calls, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try await model.trial.start(camera: CameraCatalog.disposable1990s, title: "Synthetic Trial roll")
        let second = try model.repository.createFilm(camera: CameraCatalog.mediumFormat6x6,
                                                     title: "Synthetic paid roll", access: .subscription)
        try await openWithoutSimulatorCamera(first, model)
        let unfinished = try stageUnfinishedSave(first, model)

        calls.rejectUpdates = true
        do {
            try await model.capture.open(film: second, model: model)
            XCTFail("An unfinished save on the previous Film must finish before another Film attaches")
        } catch { }
        XCTAssertEqual(model.capture.filmID, first.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unfinished.path))
        model.refresh()
        XCTAssertTrue(model.hasPendingSave(first.id))
        XCTAssertEqual(model.film(first.id)?.savedCaptureCount, 0)

        calls.rejectUpdates = false
        try await openWithoutSimulatorCamera(second, model)
        XCTAssertEqual(model.capture.filmID, second.id)
        model.refresh()
        XCTAssertFalse(model.hasPendingSave(first.id))
        XCTAssertEqual(model.film(first.id)?.savedCaptureCount, 1)
        XCTAssertEqual(model.film(second.id)?.savedCaptureCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: unfinished.path))
    }

    func testFailedSwitchToAnotherFilmKeepsTheAttachedFilmListening() async throws {
        let (root, _, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let attached = try model.repository.createFilm(camera: CameraCatalog.disposable1990s,
                                                       title: "Synthetic attached roll", access: .subscription)
        let removed = try model.repository.createFilm(camera: CameraCatalog.mediumFormat6x6,
                                                      title: "Synthetic removed roll", access: .subscription)
        try await openWithoutSimulatorCamera(attached, model)
        try model.repository.deleteFilm(filmID: removed.id)
        do { try await model.capture.open(film: removed, model: model); XCTFail("A deleted Film cannot attach") }
        catch PersistenceError.filmNotFound { }
        XCTAssertEqual(model.capture.filmID, attached.id)

        _ = try stageUnfinishedSave(attached, model)
        try await openWithoutSimulatorCamera(attached, model)
        try await waitUntil { model.capture.message == "Saved" }
        XCTAssertEqual(model.film(attached.id)?.savedCaptureCount, 1)
    }

    func testFailedInstantPrintDevelopmentShowsOnTheCameraWhenOpenAndInTheJournalOtherwise() async throws {
        let (root, _, model) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        let film = try model.repository.createFilm(camera: CameraCatalog.instant1970s,
                                                   title: "Synthetic Instant pack", access: .subscription)
        try await openWithoutSimulatorCamera(film, model)
        // Development cannot create its private work folder, so each print's Development fails.
        try Data("not a folder".utf8).write(to: root.appendingPathComponent("Work"))

        _ = try stageUnfinishedSave(film, model)
        try await openWithoutSimulatorCamera(film, model)
        try await waitUntil { model.alert != nil }
        XCTAssertEqual(model.capture.message, "Saved", "With the camera closed, the Journal alert reports the failure")

        model.alert = nil
        model.capture.presented = true
        _ = try stageUnfinishedSave(film, model)
        try await openWithoutSimulatorCamera(film, model)
        try await waitUntil { model.capture.message?.hasPrefix(FailureCopy.retry) == true }
        XCTAssertNil(model.alert, "Over the camera the failure shows once, on the camera")
    }

    func testViewfinderFollowsTheInterfaceWhoseLandscapeNamesAreSwapped() {
        XCTAssertEqual(CaptureFrameOrientation(interface: .landscapeRight)?.rotationAngle, 0, "Home side right")
        XCTAssertEqual(CaptureFrameOrientation(interface: .landscapeLeft)?.rotationAngle, 180)
        XCTAssertEqual(CaptureFrameOrientation(interface: .portrait)?.rotationAngle, 90)
        XCTAssertEqual(CaptureFrameOrientation(device: .landscapeLeft)?.rotationAngle, 0, "Home side right")
        XCTAssertEqual(CaptureFrameOrientation(device: .landscapeRight)?.rotationAngle, 180)
        XCTAssertNil(CaptureFrameOrientation(device: .faceUp))
    }

    func testDeniedCameraOnReopenAttachesNothingAndLoadsNoFilm() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureDenied-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let calls = HeldReceiptCalls()
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: calls),
                                     cameraAuthorizer: SyntheticCamera(granted: false))
        await model.recoverAtLaunch()
        let film = try model.repository.createFilm(camera: CameraCatalog.disposable1990s,
                                                   title: "Synthetic existing roll", access: .subscription)
        do { try await model.capture.open(film: film, model: model); XCTFail("Denied camera cannot open") }
        catch JournalError.cameraDenied { }
        XCTAssertNil(model.capture.filmID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Staging/\(film.id)").path))
        do {
            _ = try await model.load(camera: CameraCatalog.instant1970s, title: "Not loaded", orientation: .portrait)
            XCTFail("Denied camera cannot load a Film")
        } catch JournalError.cameraDenied { }
        XCTAssertEqual(try model.repository.allFilms().map(\.id), [film.id])
        XCTAssertFalse(calls.wasWritten, "No Trial activation is written before Camera access")
    }

    private func makeModel() async throws -> (URL, HeldReceiptCalls, JournalModel) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureController-\(UUID())")
        let calls = HeldReceiptCalls()
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: calls),
                                     cameraAuthorizer: SyntheticCamera(granted: true))
        await model.recoverAtLaunch()
        return (root, calls, model)
    }

    /// Opening attaches this Film's backend; only the missing simulator camera stops it.
    private func openWithoutSimulatorCamera(_ film: Film, _ model: JournalModel) async throws {
        do { try await model.capture.open(film: film, model: model); XCTFail("The simulator has no camera to start") }
        catch let error as NativeCaptureError where error == .notRunning || error == .configurationFailed { }
    }

    private func stageUnfinishedSave(_ film: Film, _ model: JournalModel) throws -> URL {
        let files = try CapturedMediaFiles(directory: model.repository.captureStagingDirectory(filmID: film.id))
        return try files.savePhoto(syntheticPhoto(), id: UUID())
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(30)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for the capture state")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Lets late capture events and any work they start reach the model before asserting.
    private func settle(_ model: JournalModel) async throws {
        try await Task.sleep(for: .milliseconds(500))
        try await waitUntil { model.busyFilms.isEmpty }
    }
}

extension XCTestCase {
    func syntheticPhoto() throws -> Data {
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

struct SyntheticCamera: CapturePermissionAuthorizing {
    let granted: Bool
    func authorizationStatus() -> CaptureAuthorizationStatus { granted ? .authorized : .denied }
    func requestAccess() async -> Bool { granted }
}

/// In-memory receipt calls. A held update blocks its caller, which is always the Trial owner
/// off the main actor, until the test releases it.
final class HeldReceiptCalls: TrialKeychainCalling, Sendable {
    private struct State {
        var data: Data?
        var holdNext = false
        var holding = false
        var rejectUpdates = false
        var written = false
    }
    private let state = Mutex(State())
    private let gate = DispatchSemaphore(value: 0)

    var isHolding: Bool { state.withLock { $0.holding } }
    var wasWritten: Bool { state.withLock { $0.written } }
    var rejectUpdates: Bool {
        get { state.withLock { $0.rejectUpdates } }
        set { state.withLock { $0.rejectUpdates = newValue } }
    }
    func holdNextUpdate() { state.withLock { $0.holdNext = true } }
    func release() { gate.signal() }

    func read(service: String) -> TrialKeychainRead {
        state.withLock { TrialKeychainRead(status: $0.data == nil ? errSecItemNotFound : errSecSuccess, data: $0.data) }
    }
    func add(service: String, data: Data) -> OSStatus {
        state.withLock {
            guard $0.data == nil else { return errSecDuplicateItem }
            $0.data = data
            $0.written = true
            return errSecSuccess
        }
    }
    func update(service: String, data: Data) -> OSStatus {
        let hold = state.withLock {
            let hold = $0.holdNext
            $0.holdNext = false
            $0.holding = hold
            return hold
        }
        if hold { gate.wait() }
        return state.withLock {
            $0.holding = false
            guard !$0.rejectUpdates else { return errSecNotAvailable }
            $0.data = data
            $0.written = true
            return errSecSuccess
        }
    }
}
