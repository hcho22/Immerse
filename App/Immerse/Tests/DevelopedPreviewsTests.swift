#if DEBUG
@preconcurrency import AVFoundation
import EntitlementCore
import FilmDomain
import FilmPersistence
import NativeAdapters
import RenderCore
import SwiftUI
import XCTest
@testable import Immerse

/// The Debug-only preview of each saved capture (`DevelopedPreviews`), driven through the actual capture save path: a
/// staged photo or clip is exactly what the backend leaves in the Film's staging directory, and opening the camera
/// finishes its save, whose saved event reaches the controller as a capture's does. The simulator has no camera, so the
/// open then fails before a session starts. Receipts use in-memory Keychain calls; the Release check
/// (`Scripts/verify-release-excludes-testing-unlock.sh`) proves Release has none of it, and FilmRuntime's
/// `PreviewDevelopmentTests` that a preview is the developed master or clip and leaves the roll's Development unchanged.
@MainActor
final class DevelopedPreviewsTests: XCTestCase {
    private var root: URL!
    private var previews: URL!
    private var suite: String!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("DevelopedPreviews-\(UUID())")
        previews = FileManager.default.temporaryDirectory.appendingPathComponent("DevelopedPreviewsCache-\(UUID())")
        suite = "DevelopedPreviews-\(UUID())"
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: previews)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func testSwitchStartsOnInADebugBuildAndPersistsAcrossLaunches() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertTrue(DevelopedPreviews(root: root, defaults: defaults).enabled, "A Debug build starts with previews on")
        DevelopedPreviews(root: root, defaults: defaults).enabled = false
        XCTAssertFalse(DevelopedPreviews(root: root, defaults: defaults).enabled, "Off holds on the next launch")
        DevelopedPreviews(root: root, defaults: defaults).enabled = true
        XCTAssertTrue(DevelopedPreviews(root: root, defaults: defaults).enabled, "On again holds on the next launch")
        XCTAssertFalse(DevelopedPreviews(root: root, defaults: nil).enabled, "Directly constructed Journals preview nothing")
        XCTAssertFalse(try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()))
            .developedPreviews.enabled)
    }

    /// Each Camera but the Instant previews every save at once, with the Film Stock chosen at Load Film, and its roll
    /// stays sealed with its counts and Trial as they were. One test per Camera, inside the hosted tests' allowance.
    func testEachDisposablePhotoShowsDevelopedWhileTheRollStaysSealed() async throws {
        try await assertEachSaveShowsDeveloped(CameraCatalog.disposable1990s, stock: nil, onTheTrial: true)
    }

    func testEachSixBySixPhotoShowsDevelopedWhileTheRollStaysSealed() async throws {
        try await assertEachSaveShowsDeveloped(CameraCatalog.mediumFormat6x6, stock: .blackAndWhite)
    }

    func testEachSixteenMillimeterClipShowsDevelopedWhileTheRollStaysSealed() async throws {
        try await assertEachSaveShowsDeveloped(CameraCatalog.cinema16mm, stock: .blackAndWhite)
    }

    func testEachSuperEightClipShowsDevelopedWhileTheRollStaysSealed() async throws {
        try await assertEachSaveShowsDeveloped(CameraCatalog.super8HomeMovie, stock: nil)
    }

    /// On the Trial, the first save consumes it as it does with no preview.
    private func assertEachSaveShowsDeveloped(_ camera: CameraPackage, stock: FilmStock?, onTheTrial: Bool = false) async throws {
        let model = try await makeModel(previewing: true)
        model.testingUnlock.enabled = !onTheTrial
        let film = try await model.load(camera: camera, title: "Preview \(camera.shortName)", orientation: .landscape,
                                        filmStock: stock)
        for sequence in [1, 2] {
            try await saveThroughTheCamera(film, model)
            let preview = try await readyPreview(model, film: film, sequence: sequence)
            let url = try XCTUnwrap(preview.url)
            XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, previews.standardizedFileURL)
            XCTAssertEqual(url.pathExtension, camera.medium == .photo ? "jpg" : "mov", camera.shortName)
            guard case .ready(_, _?) = preview.state else { return XCTFail("\(camera.shortName) has a thumbnail") }
            XCTAssertEqual(try previewFiles(), [url.lastPathComponent], "Each preview replaces the one before")
        }
        let saved = try XCTUnwrap(model.film(film.id))
        XCTAssertEqual(saved.captures.map(\.revealState), [.sealed, .sealed], camera.shortName)
        XCTAssertEqual(saved.savedCaptureCount, 2)
        XCTAssertEqual(saved.completionState, .open)
        XCTAssertEqual(saved.developmentState, .notStarted)
        XCTAssertNil(try model.repository.developmentRun(filmID: film.id), "\(camera.shortName): no Development began")
        XCTAssertEqual(model.capture.message, "Saved")
        XCTAssertNil(model.alert)
        try await model.remove(film.id)
        XCTAssertNil(model.developedPreviews.current, "Deleting the Film removes its preview")
        XCTAssertEqual(try previewFiles(), [])
        let state = try await model.trial.state()
        if onTheTrial {
            guard case .consumed = state else { return XCTFail("The first save consumes the Trial, as without a preview") }
        } else {
            XCTAssertEqual(state, .unused, "A subscription Film leaves the Trial unused")
        }
    }

    /// Delete Film while the camera is still finishing a save, as when Done is tapped during "Finishing save" and the Film
    /// is deleted at once: the save reports itself while the deletion waits for it to end, and its preview goes with the
    /// Film. On the Trial the save writes the receipt, which is held here until the deletion waits.
    func testDeletingAFilmWhileItsSaveFinishesLeavesNoPreview() async throws {
        let calls = HeldReceiptCalls()
        let model = try await makeModel(previewing: true, calls: calls)
        model.testingUnlock.enabled = false
        let roll = try await model.load(camera: CameraCatalog.disposable1990s, title: "Roll", orientation: .portrait)
        try await stage(roll, model)
        calls.holdNextUpdate()
        let opening = Task { try await model.capture.open(film: roll, model: model) }
        try await waitUntil { calls.isHolding }
        model.capture.suspend()
        let removal = Task { try await model.remove(roll.id) }
        try await waitUntil { model.hiddenFilms.contains(roll.id) }
        calls.release()
        try await removal.value
        _ = await opening.result
        XCTAssertNil(model.film(roll.id))
        XCTAssertNil(model.developedPreviews.current, "No preview of a deleted Film")
        try await waitUntil { (try? previewFiles()) == [] }
    }

    func testAnInstantPrintDevelopsAsBeforeAndHasNoPreview() async throws {
        let model = try await makeModel(previewing: true)
        let pack = try await model.load(camera: CameraCatalog.instant1970s, title: "Pack", orientation: .portrait)
        try await saveThroughTheCamera(pack, model)
        try await waitUntil { model.film(pack.id)?.captures.first?.revealState == .revealed }
        XCTAssertNil(model.developedPreviews.current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: previews.path), "No preview work or files for the Instant")
    }

    func testSwitchedOffNoPreviewIsMadeAndTurningItOffMidRollClearsAndStopsThem() async throws {
        let model = try await makeModel(previewing: false)
        let roll = try await model.load(camera: CameraCatalog.disposable1990s, title: "Roll", orientation: .portrait)
        try await saveThroughTheCamera(roll, model)
        try await settle(model)
        XCTAssertNil(model.developedPreviews.current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: previews.path), "Off, nothing is developed or written")

        model.developedPreviews.enabled = true
        try await saveThroughTheCamera(roll, model)
        _ = try await readyPreview(model, film: roll, sequence: 2)
        model.developedPreviews.enabled = false
        XCTAssertNil(model.developedPreviews.current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: previews.path), "Turning it off removes every preview")
        try await saveThroughTheCamera(roll, model)
        try await settle(model)
        XCTAssertNil(model.developedPreviews.current, "Off again, the next save has no preview")
        XCTAssertFalse(FileManager.default.fileExists(atPath: previews.path))
        XCTAssertEqual(model.film(roll.id)?.savedCaptureCount, 3)
    }

    /// Closing the preview removes it, and developing the roll removes the preview of its latest capture; the roll
    /// develops every capture.
    func testClosingThePreviewOrDevelopingTheRollRemovesIt() async throws {
        let model = try await makeModel(previewing: true)
        let roll = try await model.load(camera: CameraCatalog.disposable1990s, title: "Roll", orientation: .portrait)
        try await saveThroughTheCamera(roll, model)
        _ = try await readyPreview(model, film: roll, sequence: 1)
        model.developedPreviews.dismiss()
        XCTAssertNil(model.developedPreviews.current)
        XCTAssertEqual(try previewFiles(), [])

        try await saveThroughTheCamera(roll, model)
        _ = try await readyPreview(model, film: roll, sequence: 2)
        _ = try model.repository.completeEarly(filmID: roll.id, confirmedCaptureCount: 2)
        model.refresh()
        try await model.develop(roll.id)
        XCTAssertNil(model.developedPreviews.current)
        XCTAssertEqual(try previewFiles(), [])
        XCTAssertEqual(model.film(roll.id)?.captures.map(\.revealState), [.revealed, .revealed])
    }

    /// A preview that cannot develop says so on the preview and leaves the save as it is.
    func testAFailedPreviewShowsANoteAndTheCaptureStaysSaved() async throws {
        let model = try await makeModel(previewing: true)
        // The cache cannot be made: a file stands where its folder would be.
        try Data("not a folder".utf8).write(to: previews)
        let roll = try await model.load(camera: CameraCatalog.disposable1990s, title: "Roll", orientation: .portrait)
        try await saveThroughTheCamera(roll, model)
        try await waitUntil { model.developedPreviews.current?.state == .failed }
        XCTAssertEqual(model.film(roll.id)?.savedCaptureCount, 1)
        XCTAssertEqual(model.film(roll.id)?.captures.map(\.revealState), [.sealed])
        XCTAssertEqual(model.capture.message, "Saved")
        XCTAssertNil(model.alert)
        XCTAssertFalse(model.hasPendingSave(roll.id))
    }

    /// The preview on the actual shooting screen and opened full size, kept as screenshots: each Camera, upright and
    /// held on its side, at the default and the largest text size, in light and dark.
    func testTheDisposablePreviewShowsOverTheViewfinderAndFullSize() async throws {
        try await keepPreviewScreens(CameraCatalog.disposable1990s)
    }

    func testTheSixBySixPreviewShowsOverTheViewfinderAndFullSize() async throws {
        try await keepPreviewScreens(CameraCatalog.mediumFormat6x6)
    }

    func testTheSixteenMillimeterPreviewShowsOverTheViewfinderAndFullSize() async throws {
        try await keepPreviewScreens(CameraCatalog.cinema16mm)
    }

    func testTheSuperEightPreviewShowsOverTheViewfinderAndFullSize() async throws {
        try await keepPreviewScreens(CameraCatalog.super8HomeMovie)
    }

    private func keepPreviewScreens(_ camera: CameraPackage) async throws {
        let model = try await makeModel(previewing: true)
        let film = try await model.load(camera: camera, title: "Shown \(camera.shortName)", orientation: .portrait,
                                        filmStock: camera.filmStocks.isEmpty ? nil : .blackAndWhite)
        try await saveThroughTheCamera(film, model)
        let preview = try await readyPreview(model, film: film, sequence: 1)
        for (held, heldName) in [(CaptureFrameOrientation.portrait, "upright"), (.landscapeLeft, "sideways")] {
            for (size, sizeName) in [(DynamicTypeSize.large, "default"), (.accessibility5, "largest")] {
                for (style, styleName) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
                    var screen = CaptureView(filmID: film.id)
                    screen.opensCamera = false
                    // The largest text scrolls, so its whole screen is kept in a taller window.
                    try await keepScreenshot(of: screen.environment(model).dynamicTypeSize(size), style: style,
                                             tall: size.isAccessibilitySize, held: held, model: model,
                                             name: "Preview-\(camera.id.rawValue)-\(heldName)-\(sizeName)-\(styleName)")
                }
            }
        }
        for (style, styleName) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
            try await keepScreenshot(of: DevelopedPreviewSheet(preview: preview), style: style, tall: false, held: .portrait,
                                     model: model, name: "Preview-\(camera.id.rawValue)-full-size-\(styleName)")
        }
        try await model.remove(film.id)
    }

    private func makeModel(previewing: Bool, calls: HeldReceiptCalls = HeldReceiptCalls()) async throws -> JournalModel {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(previewing, forKey: DevelopedPreviews.defaultsKey)
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: calls),
                                     cameraAuthorizer: SyntheticCamera(granted: true))
        model.testingUnlock.enabled = true
        model.developedPreviews = DevelopedPreviews(root: root, defaults: defaults, directory: previews)
        await model.recoverAtLaunch()
        return model
    }

    /// Stages a photo or a clip as the backend does and opens the camera, which finishes its save and reports it.
    private func saveThroughTheCamera(_ film: Film, _ model: JournalModel) async throws {
        let before = model.film(film.id)?.savedCaptureCount ?? 0
        try await stage(film, model)
        do { try await model.capture.open(film: film, model: model); XCTFail("The simulator has no camera to start") }
        catch let error as NativeCaptureError where error == .notRunning || error == .configurationFailed { }
        try await waitUntil { model.film(film.id)?.savedCaptureCount == before + 1 }
    }

    /// Leaves a photo or a clip in the Film's staging directory, exactly as the backend leaves one for its save.
    private func stage(_ film: Film, _ model: JournalModel) async throws {
        let staging = try model.repository.captureStagingDirectory(filmID: film.id)
        let files = try CapturedMediaFiles(directory: staging)
        if film.camera.medium == .photo {
            _ = try files.savePhoto(syntheticPhoto(), id: UUID())
        } else {
            let id = UUID()
            try await writeSyntheticClip(to: files.movieDestination(id: id))
            let orientation = ClipOrientation(rawValue: (film.movieOrientation ?? .landscape).rawValue) ?? .landscape
            try files.prepare(PendingCaptureRecord(id: id, mediaKind: .movie, orientation: orientation,
                                                   remainingFrames: film.remainingMovieFrames ?? 0))
        }
    }

    private func readyPreview(_ model: JournalModel, film: Film, sequence: Int) async throws -> DevelopedPreviews.Preview {
        try await waitUntil {
            guard let current = model.developedPreviews.current else { return false }
            return current.filmID == film.id && current.sequenceNumber == sequence && current.url != nil
        }
        return try XCTUnwrap(model.developedPreviews.current)
    }

    private func previewFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectoryIfPresent(at: previews).map(\.lastPathComponent).sorted()
    }

    /// A half-second clip of 30 frames a second, as the camera records one, with no sound.
    private func writeSyntheticClip(to url: URL) async throws {
        let (width, height) = (320, 240)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height
        ])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<15 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            let pool = try XCTUnwrap(adaptor.pixelBufferPool)
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            let pixels = try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(to: UInt8.self)
            let row = CVPixelBufferGetBytesPerRow(pixels)
            for y in 0..<height {
                for x in 0..<width {
                    let pixel = base + y * row + x * 4
                    // Blue, green, red and alpha: a red half and a green half, the red brightening frame by frame.
                    pixel[0] = 40
                    pixel[1] = x < width / 2 ? 40 : 180
                    pixel[2] = x < width / 2 ? UInt8(120 + frame * 8) : 40
                    pixel[3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            XCTAssertTrue(adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30)))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 15, timescale: 30))
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, writer.error.map { "\($0)" } ?? "")
    }

    private func keepScreenshot(of view: some View, style: UIUserInterfaceStyle, tall: Bool, held: CaptureFrameOrientation,
                                model: JournalModel, name: String) async throws {
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        model.capture.hold(forTesting: held)
        // A tall shooting screen shows its whole viewfinder instead of scrolling it under the shutter bar.
        window.frame = CGRect(x: 0, y: 0, width: scene.screen.bounds.width,
                              height: scene.screen.bounds.height * (tall ? 2.2 : 1))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1))
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        // Closing the shooting screen turns the window to how the iPhone is held, which would turn every later window
        // too, so the screen is closed with the iPhone upright, and SwiftUI reports it gone a moment later.
        model.capture.hold(forTesting: .portrait)
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(500))
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(60)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for the preview")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Lets late capture events and any work they start reach the model before asserting nothing came of them.
    private func settle(_ model: JournalModel) async throws {
        try await Task.sleep(for: .milliseconds(500))
        try await waitUntil { model.busyFilms.isEmpty }
    }
}
#endif
