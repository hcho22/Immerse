import Accessibility
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import NativeAdapters
import Observation
import RenderCore
import Security
import SwiftUI
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

    func testEarlyCompletionWarningStatesExactUnusedSecondsWhileTheRowShowsMinutesAndSeconds() throws {
        var film = try Film(camera: CameraCatalog.super8HomeMovie, title: "Synthetic reel", movieOrientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(104), orientation: .landscape)
        XCTAssertEqual(film.exactWasteLabel, "196.533 unused seconds")
        XCTAssertEqual(film.remainingLabel, "3:17 left")
        XCTAssertEqual(film.remainingSpokenLabel, "3 minutes 17 seconds left")
        _ = try film.completeEarly()
        XCTAssertEqual(film.remainingLabel, "3:17 wasted")
        XCTAssertEqual(film.remainingSpokenLabel, "3 minutes 17 seconds wasted")
    }

    func testNewMovieFilmRowMatchesTheLoadScreenCapacity() throws {
        for camera in [CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm] {
            let film = try Film(camera: camera, title: "Synthetic reel", movieOrientation: .landscape, filmStock: camera.defaultFilmStock)
            XCTAssertEqual("\(film.remainingLabel.dropLast(" left".count)) of film", camera.capacityLabel)
            XCTAssertEqual("\(film.remainingSpokenLabel.dropLast(" left".count)) of film", camera.capacitySpokenLabel)
        }
        let film = try Film(camera: CameraCatalog.cinema16mm, title: "Synthetic reel", movieOrientation: .landscape, filmStock: .color)
        XCTAssertEqual(film.remainingLabel, "2:47 left")
        XCTAssertEqual(film.remainingSpokenLabel, "2 minutes 47 seconds left")
        XCTAssertEqual(CameraCatalog.cinema16mm.capacitySpokenLabel, "2 minutes 47 seconds of film")
        XCTAssertEqual(CameraCatalog.super8HomeMovie.capacityLabel, "3:20 of film")
        XCTAssertEqual(CameraCatalog.super8HomeMovie.capacitySpokenLabel, "3 minutes 20 seconds of film")
    }

    func testRecordingLineCountsDownFromTheRestingLineOnceASecond() throws {
        let film = try Film(camera: CameraCatalog.cinema16mm, title: "Synthetic reel", movieOrientation: .landscape, filmStock: .color)
        XCTAssertEqual(film.remainingLabel(recordedFor: 0), film.remainingLabel)
        XCTAssertEqual(film.remainingLabel(recordedFor: 0.9), "2:47 left")
        XCTAssertEqual(film.remainingLabel(recordedFor: 1), "2:46 left")
        XCTAssertEqual(film.remainingLabel(recordedFor: 1.9), "2:46 left")
        XCTAssertEqual(film.remainingLabel(recordedFor: 47), "2:00 left")
        XCTAssertEqual(film.remainingSpokenLabel(recordedFor: 47), "2 minutes left")
        XCTAssertEqual(film.remainingLabel(recordedFor: 166.99), "0:01 left", "Any frame left is not 0:00")
        XCTAssertEqual(film.remainingLabel(recordedFor: 167), "0:00 left")
        XCTAssertEqual(film.remainingLabel(recordedFor: 170), "0:00 left")
        // A partial second left at rest holds until it has recorded, then the line drops a whole second.
        var reel = try Film(camera: CameraCatalog.super8HomeMovie, title: "Synthetic reel", movieOrientation: .landscape)
        _ = try reel.recordSavedMovieClip(durationSeconds: MovieFrames.seconds(104), orientation: .landscape)
        XCTAssertEqual(reel.remainingLabel, "3:17 left")
        XCTAssertEqual(reel.remainingLabel(recordedFor: 0.5), "3:17 left")
        XCTAssertEqual(reel.remainingLabel(recordedFor: 0.6), "3:16 left")
        XCTAssertEqual(reel.remainingSpokenLabel(recordedFor: 0.6), "3 minutes 16 seconds left")
    }

    /// PRD 2.1 sections 6.1 and 6.2 as Load Film shows them: what each Camera does, how it develops, and never a maker
    /// or film name (ADR 0015). The 6×6 is spoken as "6 by 6" wherever its name is shown.
    func testLoadFilmCopyFollowsPRD21AndNeverNamesAFormatReference() {
        let copy = Dictionary(uniqueKeysWithValues: CameraCatalog.all.map { ($0.id, "\($0.controlsLabel). \($0.lookLines.joined(separator: ". "))") })
        XCTAssertTrue(copy[.disposable1990s]!.contains("low-light cue"))
        XCTAssertTrue(copy[.disposable1990s]!.contains("3:2"))
        XCTAssertTrue(copy[.instant1970s]!.contains("white card") && copy[.instant1970s]!.contains("saturated"))
        XCTAssertTrue(copy[.mediumFormat6x6]!.contains("optical focus only") && copy[.mediumFormat6x6]!.contains("Borderless square"))
        XCTAssertTrue(copy[.super8HomeMovie]!.contains("Strong") && copy[.super8HomeMovie]!.contains("18 frames"))
        XCTAssertTrue(copy[.cinema16mm]!.contains("24 frames"))
        // The two Cameras with a Film Stock describe both looks (PRD 2.1 sections 6.1 and 6.2).
        XCTAssertTrue(copy[.mediumFormat6x6]!.contains("Color: natural, warm color")
                      && copy[.mediumFormat6x6]!.contains("Black and white: high contrast and distinct grain"))
        // The 16mm keeps main's line until CAM-17 renders the glow per Film Stock.
        XCTAssertTrue(copy[.cinema16mm]!.contains("highlight glow"))
        for camera in CameraCatalog.all where camera.filmStocks.isEmpty {
            XCTAssertFalse(copy[camera.id]!.localizedCaseInsensitiveContains("black and white"), camera.displayName)
        }
        XCTAssertEqual(FilmStock.allCases.map(\.label), ["Color", "Black and white"])
        XCTAssertNotNil(CameraCatalog.mediumFormat6x6.viewfinderNote)
        XCTAssertTrue(CameraCatalog.mediumFormat6x6.viewfinderNote!.contains("reversed left to right"))
        for camera in CameraCatalog.all where camera.id != .mediumFormat6x6 { XCTAssertNil(camera.viewfinderNote, camera.displayName) }
        let forbidden = ["Kodak", "Polaroid", "Hasselblad", "Bolex", "Fun Saver", "Portra", "Tri-X", "Kodachrome", "Instamatic",
                         "Vision3", "Double-X", "Eastman", "500C"]
        for camera in CameraCatalog.all {
            let shown = [camera.displayName, camera.shortName, camera.controlsLabel, camera.viewfinderNote ?? ""] + camera.lookLines
                + camera.filmStocks.map(\.label)
            for text in shown { for name in forbidden { XCTAssertFalse(text.contains(name), "\(camera.displayName): \(text)") } }
        }
    }

    /// The 6×6 is drawn as "6×6" and spoken as "6 by 6" wherever its name is shown. No other Camera's name changes.
    func testSixBySixIsSpokenAsSixBySixWhereverItsNameIsShown() {
        let medium = CameraCatalog.mediumFormat6x6
        XCTAssertEqual(medium.shortName, "6×6")
        XCTAssertEqual(medium.displayName, "6×6 Medium Format")
        assertShown(medium.shortName, spokenAs: "6 by 6")
        assertShown(medium.displayName, spokenAs: "6 by 6 Medium Format")
        for camera in CameraCatalog.all where camera.id != .mediumFormat6x6 {
            assertShown(camera.shortName, spokenAs: camera.shortName)
            assertShown(camera.displayName, spokenAs: camera.displayName)
        }
        for camera in CameraCatalog.all { XCTAssertFalse(SpokenText.of(camera.displayName).contains("×"), camera.displayName) }
    }

    /// A Film keeps its title as given, and VoiceOver reads any "6×6" in it as "6 by 6": the title Load Film suggests
    /// for a 6×6 Film as well as a typed one, wherever the title is shown (the Journal row and the Film screen's title).
    func testFilmTitlesKeepTheirTextAndAreSpokenWithSixBySix() throws {
        let medium = CameraCatalog.mediumFormat6x6
        let suggested = try Film(camera: medium, title: medium.suggestedTitle(roll: 1), filmStock: .color)
        XCTAssertEqual(suggested.title, "6×6 - Roll #01")
        assertShown(suggested.title, spokenAs: "6 by 6 - Roll #01")
        let typed = try Film(camera: CameraCatalog.disposable1990s, title: "Square 6×6 prints")
        XCTAssertEqual(typed.title, "Square 6×6 prints")
        assertShown(typed.title, spokenAs: "Square 6 by 6 prints")
        for camera in CameraCatalog.all where camera.id != .mediumFormat6x6 {
            let film = try Film(camera: camera, title: camera.suggestedTitle(roll: 12),
                                movieOrientation: camera.medium == .movie ? .portrait : nil, filmStock: camera.defaultFilmStock)
            assertShown(film.title, spokenAs: film.title)
        }
    }

    /// `text` is drawn as written, with a "6 by 6" pronunciation on its "6×6" when `spoken` differs from it, and a
    /// navigation title showing it is labeled `spoken`.
    private func assertShown(_ text: String, spokenAs spoken: String, file: StaticString = #filePath, line: UInt = #line) {
        let shown = SpokenText.shown(text)
        XCTAssertEqual(String(shown.characters), text, file: file, line: line)
        let pronounced = shown.runs.compactMap { run in
            run.accessibilitySpeechPhoneticNotation.map { "\(String(shown[run.range].characters)): \($0)" }
        }
        XCTAssertEqual(pronounced, spoken == text ? [] : ["6×6: sɪks baɪ sɪks"], text, file: file, line: line)
        XCTAssertEqual(SpokenText.of(text), spoken, file: file, line: line)
    }

    /// A Darkroom error shows between the print and its controls without resizing or moving the print, so the print
    /// and a Dodge/Burn stroke on it keep one scale; only the controls move down while it shows.
    func testADarkroomErrorNeitherResizesNorMovesThePrint() async throws {
        let probe = DarkroomLayoutProbe()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: DarkroomLayoutProbeView(probe: probe))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let resting = try await settledFrames(probe)
        XCTAssertEqual(resting.controls.minY, resting.print.maxY + 18, accuracy: 0.5, "The controls sit right under the print")

        probe.error = "The print could not be rendered. Your Original and the last saved print are unchanged."
        let failed = try await settledFrames(probe)
        XCTAssertEqual(failed.print, resting.print, "An error leaves the print's size and place alone")
        XCTAssertGreaterThan(failed.controls.minY, resting.controls.minY + 18, "The error shows between the print and the controls")

        probe.error = nil
        let cleared = try await settledFrames(probe)
        XCTAssertEqual(cleared.print, resting.print)
        XCTAssertEqual(cleared.controls, resting.controls)
    }

    /// The frames once two looks 50 ms apart agree: the controls' measured height reaches the print a layout pass later.
    private func settledFrames(_ probe: DarkroomLayoutProbe) async throws -> (print: CGRect, controls: CGRect) {
        var last: (print: CGRect, controls: CGRect)?
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(50))
            let now = (print: probe.printFrame, controls: probe.controlsFrame)
            if !now.print.isNull, !now.controls.isNull, let last, last.print == now.print, last.controls == now.controls {
                return now
            }
            last = now
        }
        throw DarkroomLayoutDidNotSettle()
    }

    func testPhotoFilmRowsKeepExposureCounts() throws {
        let film = try Film(camera: CameraCatalog.disposable1990s, title: "Synthetic roll")
        XCTAssertEqual(film.remainingLabel, "27 exposures left")
        XCTAssertEqual(film.remainingSpokenLabel, "27 exposures left")
        XCTAssertEqual(CameraCatalog.disposable1990s.capacityLabel, "27 exposures")
        XCTAssertEqual(CameraCatalog.disposable1990s.capacitySpokenLabel, "27 exposures")
    }

    func testMovieDurationTextRoundsPartialSecondsUpFromWholeFrames() {
        XCTAssertEqual(MovieDurationText.wholeSeconds(0), 0)
        XCTAssertEqual(MovieDurationText.wholeSeconds(-1), 0)
        XCTAssertEqual(MovieDurationText.wholeSeconds(MovieFrames.seconds(1)), 1, "One frame left is not 0:00")
        XCTAssertEqual(MovieDurationText.wholeSeconds(MovieFrames.seconds(30)), 1)
        XCTAssertEqual(MovieDurationText.wholeSeconds(MovieFrames.seconds(31)), 2)
        XCTAssertEqual(MovieDurationText.wholeSeconds(59.5), 60)
        XCTAssertEqual(MovieDurationText.wholeSeconds(120), 120)
        // Summed frame seconds can land a hair off the whole second; frames keep it exact.
        XCTAssertEqual(MovieDurationText.wholeSeconds(MovieFrames.seconds(4950)), 165)
        XCTAssertEqual(MovieDurationText.wholeSeconds(MovieFrames.seconds(5896)), 197)
    }

    func testMovieDurationTextClockAndSpokenForms() {
        let cases: [(Int, String, String)] = [
            (0, "0:00", "0 seconds"), (1, "0:01", "1 second"), (9, "0:09", "9 seconds"), (59, "0:59", "59 seconds"),
            (60, "1:00", "1 minute"), (61, "1:01", "1 minute 1 second"), (120, "2:00", "2 minutes"),
            (165, "2:45", "2 minutes 45 seconds"), (167, "2:47", "2 minutes 47 seconds"), (200, "3:20", "3 minutes 20 seconds"), (600, "10:00", "10 minutes"),
        ]
        for (seconds, clock, spoken) in cases {
            XCTAssertEqual(MovieDurationText.clock(seconds), clock)
            XCTAssertEqual(MovieDurationText.spoken(seconds), spoken)
        }
    }

    func testLoadSheetDescribesTheEntitlementThatLoadingWillUse() {
        XCTAssertEqual(LoadCopy.note(access: .active, trial: .unused, camera: CameraCatalog.disposable1990s, subscriptionsAvailable: true),
                       "This Film is included in your subscription. Your Camera cannot change after loading.")
        XCTAssertEqual(LoadCopy.note(access: .notPurchased, trial: .unused, camera: CameraCatalog.super8HomeMovie, subscriptionsAvailable: true),
                       "The first saved capture uses this iPhone's Trial. Your Camera and Movie Orientation cannot change after loading.")
        let consumed = DeviceTrialState.consumed(record: DeviceTrialConsumptionRecord(filmID: UUID(), consumedAt: Date()))
        XCTAssertEqual(LoadCopy.note(access: .expired, trial: consumed, camera: CameraCatalog.instant1970s, subscriptionsAvailable: true),
                       "This iPhone's Trial is used. A subscription is required to load another Film. Your Camera cannot change after loading.")
        XCTAssertEqual(LoadCopy.note(access: .notPurchased, trial: nil, camera: CameraCatalog.disposable1990s, subscriptionsAvailable: true),
                       "Your Camera cannot change after loading.")
        // Load Film fixes the Film Stock on the two Cameras that offer one (ADR 0014).
        XCTAssertEqual(LoadCopy.note(access: .active, trial: .unused, camera: CameraCatalog.mediumFormat6x6, subscriptionsAvailable: true),
                       "This Film is included in your subscription. Your Camera and Film Stock cannot change after loading.")
        XCTAssertEqual(LoadCopy.note(access: .notPurchased, trial: .unused, camera: CameraCatalog.cinema16mm, subscriptionsAvailable: true),
                       "The first saved capture uses this iPhone's Trial. Your Camera, Film Stock and Movie Orientation cannot change after loading.")
    }

    func testLoadSheetNeverSuggestsSubscribingInABuildWithoutSubscriptions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LoadCopyUnconfigured-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        XCTAssertFalse(model.billing.configured)
        let consumed = DeviceTrialState.consumed(record: DeviceTrialConsumptionRecord(filmID: UUID(), consumedAt: Date()))
        XCTAssertEqual(LoadCopy.note(access: model.billing.access, trial: consumed, camera: CameraCatalog.instant1970s,
                                     subscriptionsAvailable: model.billing.configured),
                       "This iPhone's Trial is used. Subscriptions are not available in this build. Your Camera cannot change after loading.")
        XCTAssertEqual(LoadCopy.note(access: model.billing.access, trial: .emptyFilmInProgress(filmID: UUID()), camera: CameraCatalog.super8HomeMovie,
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

    func testFilmDeletedBetweenListingAndPendingSaveCheckLeavesTheJournalWithoutAnAlert() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JournalConcurrentDelete-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try JournalModel(root: root)
        let kept = try model.repository.createFilm(camera: CameraCatalog.disposable1990s,
                                                   title: "Synthetic kept roll", access: .subscription)
        let deleted = try model.repository.createFilm(camera: CameraCatalog.mediumFormat6x6,
                                                      title: "Synthetic deleted roll", filmStock: .color, access: .subscription)
        let files = try CapturedMediaFiles(directory: model.repository.captureStagingDirectory(filmID: kept.id))
        _ = try files.savePhoto(syntheticPhoto(), id: UUID())
        // Another owner deletes a Film once the Journal has listed it, before its pending-save check.
        withObservationTracking { _ = model.films } onChange: {
            do { try FilmRepository(rootURL: root).deleteFilm(filmID: deleted.id) }
            catch { XCTFail("Concurrent deletion failed: \(error)") }
        }
        model.refresh()
        XCTAssertEqual(try model.repository.allFilms().map(\.id), [kept.id])
        XCTAssertNil(model.alert, model.alert?.message ?? "")
        XCTAssertEqual(model.films.map(\.id), [kept.id])
        XCTAssertEqual(model.pendingFilms, [kept.id])
        XCTAssertTrue(model.hasPendingSave(kept.id))
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

/// Records the frames a hosted `DarkroomLayout` gives a stand-in print and its controls.
@MainActor @Observable
private final class DarkroomLayoutProbe {
    var error: String?
    @ObservationIgnored var printFrame = CGRect.null
    @ObservationIgnored var controlsFrame = CGRect.null
}

private struct DarkroomLayoutProbeView: View {
    let probe: DarkroomLayoutProbe

    var body: some View {
        DarkroomLayout(rendering: false, error: probe.error) {
            Color.gray.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probe.printFrame = $0 }
        } controls: {
            VStack(spacing: 18) {
                Text("Exposure").font(.headline)
                Slider(value: .constant(0.5))
            }.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probe.controlsFrame = $0 }
        }
    }
}

private struct DarkroomLayoutDidNotSettle: Error {}
