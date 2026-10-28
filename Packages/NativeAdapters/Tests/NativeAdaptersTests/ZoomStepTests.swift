import FilmDomain
@testable import NativeAdapters
import XCTest

/// The 6×6, Super 8 and 16mm zoom steps follow the lenses the iPhone reports (the captain, 2026-10-16: "allow zoom as
/// allowed by camera native"). Each case injects what an iPhone's camera API would report.
final class ZoomStepTests: XCTestCase {
    /// `crops` are the native crops the API reports for the wide lens, and the others those of the other two lenses.
    private func lenses(
        _ lenses: [(RearLens, Double)], crops: [Double] = [], telephotoCrops: [Double] = [], ultraWideCrops: [Double] = []
    ) -> RearLensCapabilities {
        let reported: [RearLens: [Double]] = [.wide: crops, .telephoto: telephotoCrops, .ultraWide: ultraWideCrops]
        return RearLensCapabilities(lenses: lenses.map { .init($0.0, displayFactor: $0.1, nativeCropFactors: reported[$0.0]!) })
    }

    private func labels(_ capabilities: RearLensCapabilities) -> [String] { capabilities.zoomSteps.map(\.label) }

    func testOneRearLensShowsNoZoomControl() {
        XCTAssertEqual(RearLensCapabilities.wideOnly.zoomSteps, [])
        XCTAssertNil(RearLensCapabilities.wideOnly.restingStep)
        XCTAssertEqual(labels(lenses([(.wide, 1)])), [])
    }

    func testWideAndUltraWideOfferHalfAndOne() {
        let steps = lenses([(.ultraWide, 0.5), (.wide, 1)]).zoomSteps
        XCTAssertEqual(steps.map(\.label), ["0.5x", "1x"])
        XCTAssertEqual(steps.map(\.lens), [.ultraWide, .wide])
        XCTAssertTrue(steps.allSatisfy { $0.lensZoomFactor == 1 && !$0.isSensorCrop })
    }

    func testThreeLensesAtThreeTimesAndAtFiveTimes() {
        XCTAssertEqual(labels(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 3)])), ["0.5x", "1x", "3x"])
        XCTAssertEqual(labels(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 5)])), ["0.5x", "1x", "5x"])
        XCTAssertEqual(
            lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 5)]).zoomSteps.map(\.lens), [.ultraWide, .wide, .telephoto]
        )
    }

    func testAnOlderDualCameraOffersOneAndTwoAndAHalfStepKeepsItsDecimal() {
        XCTAssertEqual(labels(lenses([(.wide, 1), (.telephoto, 2)])), ["1x", "2x"])
        XCTAssertEqual(labels(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 2.5)])), ["0.5x", "1x", "2.5x"])
    }

    func testRestingStepIsTheWholeWideLens() {
        let capabilities = lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 3)], crops: [2])
        let resting = try? XCTUnwrap(capabilities.restingStep)
        XCTAssertEqual(resting?.label, "1x")
        XCTAssertEqual(resting?.lens, .wide)
        XCTAssertEqual(resting?.isSensorCrop, false)
    }

    /// A native crop is a step only where the camera API reports one, and it is one more step beside the lenses.
    func testANativeSensorCropIsOfferedOnlyWhereTheCameraReportsIt() {
        let withCrop = lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 5)], crops: [2])
        XCTAssertEqual(labels(withCrop), ["0.5x", "1x", "2x", "5x"])
        let crop = withCrop.zoomSteps[2]
        XCTAssertEqual(crop.lens, .wide, "The crop is of the wide lens")
        XCTAssertEqual(crop.lensZoomFactor, 2)
        XCTAssertTrue(crop.isSensorCrop)

        XCTAssertEqual(labels(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 5)])), ["0.5x", "1x", "5x"],
                       "No crop reported, no 2x step")
        XCTAssertEqual(labels(lenses([(.wide, 1)], crops: [2])), ["1x", "2x"],
                       "One lens with a reported crop still has two steps")
    }

    /// A native crop of the telephoto lens is a step at the factor it shows, as the iPhone's Camera app labels it: a 2x crop
    /// of a 4x telephoto lens is 8x.
    func testANativeCropOfTheTelephotoLensIsOfferedAtTheFactorItShows() {
        let steps = lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 4)], crops: [2], telephotoCrops: [2]).zoomSteps
        XCTAssertEqual(steps.map(\.label), ["0.5x", "1x", "2x", "4x", "8x"])
        let eight = steps[4]
        XCTAssertEqual(eight.lens, .telephoto, "The crop is of the telephoto lens")
        XCTAssertEqual(eight.lensZoomFactor, 2)
        XCTAssertTrue(eight.isSensorCrop)
        XCTAssertEqual(steps[2].lens, .wide, "The 2x is still the wide lens's crop")
        XCTAssertEqual(labels(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 4)], telephotoCrops: [2])),
                       ["0.5x", "1x", "4x", "8x"], "Only the telephoto lens reports a crop")
        XCTAssertEqual(labels(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 4)])), ["0.5x", "1x", "4x"],
                       "No crop reported, no 8x step")
    }

    func testACropThatARealLensAlreadyCoversIsNotOfferedTwice() {
        let steps = lenses([(.wide, 1), (.telephoto, 2)], crops: [2]).zoomSteps
        XCTAssertEqual(steps.map(\.label), ["1x", "2x"])
        XCTAssertEqual(steps.last?.lens, .telephoto, "The telephoto lens keeps its 2x")
        XCTAssertFalse(steps.last?.isSensorCrop ?? true)
        let ultraWide = lenses([(.ultraWide, 0.5), (.wide, 1)], ultraWideCrops: [2]).zoomSteps
        XCTAssertEqual(ultraWide.map(\.label), ["0.5x", "1x"], "A 2x crop of the ultra wide lens is the wide lens's 1x")
        XCTAssertEqual(ultraWide.last?.lens, .wide)
        XCTAssertFalse(ultraWide.last?.isSensorCrop ?? true)
    }

    func testFactorsThatAreNotACropAreNeverOffered() {
        XCTAssertEqual(labels(lenses([(.ultraWide, 0.5), (.wide, 1)], crops: [1, 0.5, 0])), ["0.5x", "1x"])
    }

    func testStepsAreOrderedByFactorWhateverOrderTheyWereReportedIn() {
        let steps = lenses([(.telephoto, 3), (.wide, 1), (.ultraWide, 0.5)], crops: [2]).zoomSteps
        XCTAssertEqual(steps.map(\.displayFactor), [0.5, 1, 2, 3])
    }

    func testLabelsAreSpokenAsTimes() {
        XCTAssertEqual(ZoomStep(lens: .ultraWide, displayFactor: 0.5).spokenLabel, "0.5 times")
        XCTAssertEqual(ZoomStep(lens: .wide, displayFactor: 1).spokenLabel, "1 times")
        XCTAssertEqual(ZoomStep(lens: .telephoto, displayFactor: 2.5).spokenLabel, "2.5 times")
    }

    // MARK: The plan

    private let threeLenses = RearLensCapabilities(
        lenses: [.init(.ultraWide, displayFactor: 0.5), .init(.wide, displayFactor: 1), .init(.telephoto, displayFactor: 3)]
    )

    private func plan(
        _ camera: CameraID, position: CapturePosition = .rear, rear: RearLensCapabilities
    ) -> CaptureSessionPlan {
        let mediaKind: CaptureMediaKind = switch camera {
        case .super8HomeMovie, .cinema16mm: .movie
        default: .photo
        }
        return CaptureSessionPlan(
            request: CaptureSessionRequest(
                preferredPosition: position, mediaKind: mediaKind,
                lockedMovieOrientation: mediaKind == .movie ? .portrait : nil, behavior: .for(camera)
            ),
            capabilities: CaptureCapabilities(
                availablePositions: [.rear, .front], supportsLensSwitchDuringSession: true, rearLenses: rear
            )
        )
    }

    func testThe6x6AndMovieCamerasOfferOnlyTheirRearZoomSteps() throws {
        XCTAssertEqual(plan(.mediumFormat6x6, rear: threeLenses).zoomSteps.map(\.label), ["0.5x", "1x", "3x"])
        XCTAssertEqual(plan(.mediumFormat6x6, rear: threeLenses).restingZoomStep?.label, "1x")
        XCTAssertEqual(plan(.mediumFormat6x6, position: .front, rear: threeLenses).zoomSteps, [],
                       "The front camera has no zoom steps")
        XCTAssertNil(plan(.mediumFormat6x6, position: .front, rear: threeLenses).restingZoomStep)
        for camera in [CameraID.super8HomeMovie, .cinema16mm] {
            let movie = plan(camera, rear: threeLenses)
            XCTAssertEqual(movie.mediaKind, .movie)
            XCTAssertEqual(movie.lockedMovieOrientation, .portrait)
            XCTAssertEqual(movie.behavior.viewfinder, .fourByThree)
            XCTAssertEqual(movie.zoomSteps.map(\.label), ["0.5x", "1x", "3x"], "\(camera) follows the phone's reported lenses")
            XCTAssertEqual(movie.restingZoomStep?.label, "1x")
            XCTAssertEqual(plan(camera, position: .front, rear: threeLenses).zoomSteps, [], "\(camera) front has no zoom steps")
            let telephoto = try XCTUnwrap(movie.zoomSteps.last)
            XCTAssertEqual(movie.zoomDecision(to: telephoto, during: .idle), .allowed)
            XCTAssertEqual(movie.zoomDecision(to: telephoto, during: .recordingMovie), .blockedDuring(.recordingMovie))
            XCTAssertEqual(movie.zoomDecision(to: telephoto, during: .savingMovieClip), .blockedDuring(.savingMovieClip))
        }
        for camera in [CameraID.disposable1990s, .instant1970s] {
            XCTAssertEqual(plan(camera, rear: threeLenses).zoomSteps, [], "\(camera) keeps its single lens")
        }
        XCTAssertEqual(plan(.mediumFormat6x6, rear: .wideOnly).zoomSteps, [], "One lens, no zoom control")
    }

    func testAZoomChangeWaitsForTheCameraToBeBetweenExposures() throws {
        let plan = plan(.mediumFormat6x6, rear: threeLenses)
        let telephoto = try XCTUnwrap(plan.zoomSteps.last)
        XCTAssertEqual(plan.zoomDecision(to: telephoto, during: .idle), .allowed)
        for phase in [CapturePhase.savingPhoto, .recordingMovie, .savingMovieClip, .interrupted] {
            XCTAssertEqual(plan.zoomDecision(to: telephoto, during: phase), .blockedDuring(phase), "\(phase)")
        }
    }

    func testAZoomStepTheIPhoneDoesNotHaveIsRefused() {
        let plan = plan(.mediumFormat6x6, rear: threeLenses)
        let fiveTimes = ZoomStep(lens: .telephoto, displayFactor: 5)
        XCTAssertEqual(plan.zoomDecision(to: fiveTimes, during: .idle), .unavailable(fiveTimes))
        let crop = ZoomStep(lens: .wide, lensZoomFactor: 2, displayFactor: 2)
        XCTAssertEqual(plan.zoomDecision(to: crop, during: .idle), .unavailable(crop),
                       "No crop was reported, so none is accepted")
        let telephotoCrop = ZoomStep(lens: .telephoto, lensZoomFactor: 2, displayFactor: 6)
        XCTAssertEqual(plan.zoomDecision(to: telephotoCrop, during: .idle), .unavailable(telephotoCrop))
        let reporting = self.plan(.mediumFormat6x6, rear: lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 3)],
                                                                 telephotoCrops: [2]))
        XCTAssertEqual(reporting.zoomDecision(to: telephotoCrop, during: .idle), .allowed,
                       "A crop the telephoto lens reports is accepted")
    }

    func testAZoomStepIsRefusedWhereTheCameraOffersNone() {
        let step = ZoomStep(lens: .telephoto, displayFactor: 3)
        XCTAssertEqual(plan(.disposable1990s, rear: threeLenses).zoomDecision(to: step, during: .idle), .notOffered)
        XCTAssertEqual(plan(.mediumFormat6x6, position: .front, rear: threeLenses).zoomDecision(to: step, during: .idle), .notOffered)
        XCTAssertEqual(plan(.mediumFormat6x6, rear: .wideOnly).zoomDecision(to: step, during: .idle), .notOffered)
    }

    /// A lens's native crops depend on the format it runs on, which it has only once it is the session's input, so the
    /// lenses are read again then. A crop that format does not report would be a digital enlargement: it is refused, the
    /// read no longer offers it, and the step the camera was on is still there to return to.
    func testACropTheLensDoesNotReportOnceItRunsIsRefused() throws {
        let before = plan(.mediumFormat6x6, rear: lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 4)], telephotoCrops: [2]))
        let eight = try XCTUnwrap(before.zoomSteps.last)
        XCTAssertEqual(eight.label, "8x")
        XCTAssertEqual(before.zoomDecision(to: eight, during: .idle), .allowed, "Offered from the format the lens had")
        let running = before.updatingRearLenses(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 4)]))
        XCTAssertEqual(running.zoomDecision(to: eight, during: .idle), .unavailable(eight), "Refused once its lens runs")
        XCTAssertEqual(running.zoomSteps.map(\.label), ["0.5x", "1x", "4x"], "The 8x step is no longer offered")
        let resting = try XCTUnwrap(before.restingZoomStep)
        XCTAssertEqual(running.zoomDecision(to: resting, during: .idle), .allowed, "The step the camera was on is still offered")
    }

    func testReadingTheRearLensesAgainKeepsTheRestOfThePlan() throws {
        let original = CaptureSessionPlan(
            request: CaptureSessionRequest(
                preferredPosition: .rear, mediaKind: .photo, behavior: .for(.mediumFormat6x6), manualLensPosition: 0.3
            ),
            capabilities: CaptureCapabilities(availablePositions: [.rear, .front], supportsLensSwitchDuringSession: true)
        )
        XCTAssertEqual(original.zoomSteps, [])
        let updated = original.updatingRearLenses(lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 3)], crops: [2]))
        XCTAssertEqual(updated.zoomSteps.map(\.label), ["0.5x", "1x", "2x", "3x"])
        XCTAssertEqual(updated.behavior, original.behavior)
        XCTAssertEqual(updated.manualLensPosition, 0.3)
        XCTAssertEqual(updated.activePosition, .rear)
        XCTAssertEqual(updated.lensSwitchDecision(to: .front, during: .idle), .allowed)
    }

    /// A stand-in for a lens's format: its landscape size and whether it records 30 frames per second.
    private struct Format { let width: Int; let height: Int; var thirty = true }

    private func movieLenses(_ formats: [RearLens: [Format]]) -> RearLensCapabilities {
        MovieCaptureFormat.lensesRecordingTheWideLensFormat(
            lenses([(.ultraWide, 0.5), (.wide, 1), (.telephoto, 3)], crops: [2], telephotoCrops: [2]),
            formats: { formats[$0] ?? [] },
            dimensions: { ($0.width, $0.height) }, recordsMovieFrameRate: { $0.thirty }
        )
    }

    /// FR-26 item 4: a movie Camera offers a lens's steps only where the lens records the wide lens's 4:3 movie size at the
    /// movie frame rate, so every step records the same size and none fails to open mid-shoot.
    func testAMovieStepIsOfferedOnlyOnALensThatRecordsTheWideLensMovieSize() {
        let wide = [Format(width: 1920, height: 1080), Format(width: 1440, height: 1080), Format(width: 640, height: 480)]
        let every = movieLenses([.wide: wide, .ultraWide: [Format(width: 1440, height: 1080)],
                                 .telephoto: [Format(width: 1440, height: 1080)]])
        XCTAssertEqual(labels(every), ["0.5x", "1x", "2x", "3x", "6x"], "Every lens records 1440 by 1080")

        let noFourByThree = movieLenses([.wide: wide, .ultraWide: [Format(width: 1920, height: 1080)],
                                         .telephoto: [Format(width: 1440, height: 1080)]])
        XCTAssertEqual(labels(noFourByThree), ["1x", "2x", "3x", "6x"], "An ultra wide lens with no 4:3 format drops out")

        let otherSize = movieLenses([.wide: wide, .ultraWide: [Format(width: 1440, height: 1080)],
                                     .telephoto: [Format(width: 1280, height: 960), Format(width: 640, height: 480)]])
        XCTAssertEqual(labels(otherSize), ["0.5x", "1x", "2x"],
                       "A telephoto lens with only other 4:3 sizes drops out, its own crop with it")

        let tooSlow = movieLenses([.wide: wide, .ultraWide: [Format(width: 1440, height: 1080, thirty: false)],
                                   .telephoto: [Format(width: 1440, height: 1080)]])
        XCTAssertEqual(labels(tooSlow), ["1x", "2x", "3x", "6x"], "A lens that cannot record 30 frames per second drops out")

        let wideOnly = movieLenses([.wide: wide])
        XCTAssertEqual(labels(wideOnly), ["1x", "2x"], "The wide lens keeps its own native crop")
    }

    func testAZoomStepLensRecordsExactlyTheWideLensMovieSize() {
        let formats = [Format(width: 1920, height: 1440), Format(width: 1440, height: 1080, thirty: false),
                       Format(width: 1440, height: 1080)]
        let wide = MovieCaptureFormat.preferred(among: [Format(width: 1440, height: 1080)],
                                                dimensions: { ($0.width, $0.height) }, recordsMovieFrameRate: { $0.thirty })
        let matched = MovieCaptureFormat.matching((1440, 1080), among: formats,
                                                  dimensions: { ($0.width, $0.height) }, recordsMovieFrameRate: { $0.thirty })
        XCTAssertEqual(wide.map { [$0.width, $0.height] }, [1440, 1080])
        XCTAssertEqual(matched.map { [$0.width, $0.height, $0.thirty ? 30 : 0] }, [1440, 1080, 30],
                       "The lens records the wide lens's size at 30 frames per second, never its own larger format")
    }
}
