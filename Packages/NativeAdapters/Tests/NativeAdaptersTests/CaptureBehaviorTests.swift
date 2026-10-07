import FilmDomain
@testable import NativeAdapters
import XCTest

final class CaptureBehaviorTests: XCTestCase {
    func testEachCameraAsksForItsOwnFocusExposureAndFraming() {
        let disposable = CaptureBehavior.for(.disposable1990s)
        XCTAssertEqual(disposable.focus, .fixed)
        XCTAssertEqual(disposable.exposure, .fixed)
        XCTAssertEqual(disposable.viewfinder, .threeByTwo)
        XCTAssertTrue(disposable.offersFlash)
        XCTAssertTrue(disposable.showsLowLightCue)
        XCTAssertFalse(disposable.reversesRearViewfinder)

        let super8 = CaptureBehavior.for(.super8HomeMovie)
        XCTAssertEqual(super8.focus, .fixed, "Fixed-focus lens")
        XCTAssertEqual(super8.exposure, .automatic, "Automatic exposure")
        XCTAssertEqual(super8.viewfinder, .fourByThree)
        XCTAssertFalse(super8.offersFlash)
        XCTAssertFalse(super8.showsLowLightCue)

        let medium = CaptureBehavior.for(.mediumFormat6x6)
        XCTAssertEqual(medium.focus, .manual)
        XCTAssertEqual(medium.exposure, .manualBias)
        XCTAssertEqual(medium.viewfinder, .square)
        XCTAssertTrue(medium.offersManualFocus)
        XCTAssertTrue(medium.offersExposureBias)
        XCTAssertTrue(medium.reversesRearViewfinder)
        XCTAssertFalse(medium.offersFlash)
    }

    func testCamerasOtherThanThoseThatChangedKeepTheirCaptureConfiguration() {
        XCTAssertEqual(CaptureBehavior.for(.instant1970s),
                       CaptureBehavior(focus: .deviceDefault, exposure: .automatic, viewfinder: .square))
        XCTAssertEqual(CaptureBehavior.for(.cinema16mm), .deviceDefault)
        for camera in CameraID.allCases where camera != .disposable1990s {
            XCTAssertNotEqual(CaptureBehavior.for(camera).exposure, .fixed, "\(camera)")
            XCTAssertFalse(CaptureBehavior.for(camera).showsLowLightCue, "\(camera)")
        }
        for camera in CameraID.allCases where camera != .mediumFormat6x6 {
            XCTAssertFalse(CaptureBehavior.for(camera).reversesRearViewfinder, "\(camera)")
            XCTAssertFalse(CaptureBehavior.for(camera).offersManualFocus, "\(camera)")
        }
    }

    func testOnlyTheSixBySixRearViewfinderIsReversedAndEveryFrontViewfinderIsMirrored() {
        for camera in CameraID.allCases {
            let behavior = CaptureBehavior.for(camera)
            XCTAssertTrue(behavior.isViewfinderMirrored(position: .front), "\(camera) front keeps its mirrored behavior")
            XCTAssertEqual(behavior.isViewfinderMirrored(position: .rear), camera == .mediumFormat6x6, "\(camera) rear")
        }
    }

    func testViewfinderShapesFrameWhatTheCameraDevelops() {
        XCTAssertEqual(ViewfinderShape.threeByTwo.aspectRatio(landscape: false), 2.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(ViewfinderShape.threeByTwo.aspectRatio(landscape: true), 3.0 / 2, accuracy: 1e-9)
        XCTAssertEqual(ViewfinderShape.fourByThree.aspectRatio(landscape: false), 3.0 / 4, accuracy: 1e-9)
        XCTAssertEqual(ViewfinderShape.fourByThree.aspectRatio(landscape: true), 4.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(ViewfinderShape.square.aspectRatio(landscape: true), 1)
        XCTAssertEqual(ViewfinderShape.square.aspectRatio(landscape: false), 1)
        XCTAssertTrue(ViewfinderShape.threeByTwo.cropsCapture)
        XCTAssertTrue(ViewfinderShape.square.cropsCapture)
        XCTAssertFalse(ViewfinderShape.fourByThree.cropsCapture, "The 4:3 viewfinder shows the whole capture")
    }

    func testSessionPlanCarriesTheCameraBehavior() {
        let capabilities = CaptureCapabilities(availablePositions: [.rear, .front], supportsLensSwitchDuringSession: true)
        let plan = CaptureSessionPlan(request: CaptureSessionRequest(
            preferredPosition: .rear, mediaKind: .photo, behavior: .for(.mediumFormat6x6), manualLensPosition: 0.1
        ), capabilities: capabilities)
        XCTAssertEqual(plan.behavior, CaptureBehavior.for(.mediumFormat6x6))
        XCTAssertEqual(plan.manualLensPosition, 0.1, "The person's focus travels with the plan")
        let plain = CaptureSessionPlan(request: CaptureSessionRequest(preferredPosition: .rear, mediaKind: .movie),
                                       capabilities: capabilities)
        XCTAssertEqual(plain.behavior, CaptureBehavior.deviceDefault)
        XCTAssertEqual(plain.manualLensPosition, FixedFocus.lensPosition, "The Focus control's resting value")
    }

    func testFixedExposureGivesEveryLensTheSameLightValue() {
        // A wide rear lens, the front lens and a narrow telephoto-like aperture all meet the reference value.
        for aperture in [1.6, 1.9, 2.2, 2.8] {
            let exposure = FixedExposure.settings(
                aperture: aperture, isoRange: 25...2_500, durationRange: (1.0 / 100_000)...(1.0 / 3)
            )
            XCTAssertEqual(exposure.iso, 25, "The lowest ISO keeps the grain to Development")
            XCTAssertEqual(exposure.equivalentEV100(aperture: aperture), FixedExposure.referenceEV100, accuracy: 1e-6)
        }
        let wide = FixedExposure.settings(aperture: 1.6, isoRange: 25...2_500, durationRange: (1.0 / 100_000)...(1.0 / 3))
        XCTAssertEqual(wide.duration, 1.0 / 400, accuracy: 0.00005)
    }

    func testFixedExposureStaysInsideWhatTheLensFormatAllows() {
        let slow = FixedExposure.settings(aperture: 1.6, isoRange: 55...1_700, durationRange: (1.0 / 100)...(1.0 / 3))
        XCTAssertEqual(slow.duration, 1.0 / 100, "Clamped up to the format's shortest duration")
        let fast = FixedExposure.settings(aperture: 1.6, isoRange: 25...2_500, durationRange: (1.0 / 100)...(1.0 / 50))
        XCTAssertGreaterThanOrEqual(fast.duration, 1.0 / 100)
        XCTAssertLessThanOrEqual(fast.duration, 1.0 / 50)
        let dim = FixedExposure.settings(aperture: 2.2, isoRange: 40...3_000, durationRange: (1.0 / 8_000)...(1.0 / 400))
        XCTAssertLessThanOrEqual(dim.duration, 1.0 / 400, "Clamped down to the format's longest duration")
        XCTAssertTrue((40...3_000).contains(dim.iso))
    }

    func testSceneLightReadsAutomaticExposureAsBrightness() {
        // Bright sun: f/1.6, 1/3000 s at ISO 25 is about EV 15.
        XCTAssertEqual(SceneLight.ev100(aperture: 1.6, duration: 1.0 / 3_000, iso: 25), 14.9, accuracy: 0.1)
        // A dim room at the same lens, 1/30 s and ISO 1000, is about EV 2.9.
        XCTAssertEqual(SceneLight.ev100(aperture: 1.6, duration: 1.0 / 30, iso: 1_000), 2.9, accuracy: 0.1)
        XCTAssertTrue(SceneLight.ev100(aperture: 1.6, duration: 0, iso: 100).isNaN)
        XCTAssertTrue(SceneLight.ev100(aperture: 0, duration: 0.01, iso: 100).isNaN)
    }

    func testLowLightCueAppearsBelowTheThresholdAndIsAbsentAboveIt() {
        var cue = LowLightCue()
        let fixed = FixedExposure.referenceEV100
        XCTAssertFalse(cue.update(sceneEV100: fixed + 3), "Bright day")
        XCTAssertFalse(cue.update(sceneEV100: fixed), "Exactly the fixed exposure")
        XCTAssertFalse(cue.update(sceneEV100: fixed - 1), "An overcast day")
        XCTAssertFalse(cue.update(sceneEV100: fixed - 1.99), "Just inside the threshold")
        XCTAssertTrue(cue.update(sceneEV100: fixed - 2), "At the threshold")
        XCTAssertTrue(cue.update(sceneEV100: fixed - 6), "A dim room")
    }

    func testLowLightCueDoesNotFlickerAroundTheThreshold() {
        var cue = LowLightCue()
        let fixed = FixedExposure.referenceEV100
        XCTAssertTrue(cue.update(sceneEV100: fixed - 3))
        XCTAssertTrue(cue.update(sceneEV100: fixed - 1.8), "Stays until the scene is back within 1.5 stops")
        XCTAssertTrue(cue.update(sceneEV100: fixed - 1.51))
        XCTAssertFalse(cue.update(sceneEV100: fixed - 1.5))
        XCTAssertFalse(cue.update(sceneEV100: fixed - 1.9), "And stays hidden until two stops")
        XCTAssertTrue(cue.update(sceneEV100: fixed - 2.1))
    }

    func testLowLightCueIgnoresReadingsThatAreNotNumbers() {
        var cue = LowLightCue()
        XCTAssertFalse(cue.update(sceneEV100: .nan))
        XCTAssertFalse(cue.update(sceneEV100: .infinity))
        cue.update(sceneEV100: 2)
        XCTAssertTrue(cue.update(sceneEV100: .nan), "Keeps the last state")
    }
}
