import FilmDomain
@testable import NativeAdapters
import XCTest

final class CaptureBehaviorTests: XCTestCase {
    func testEachCameraAsksForItsOwnFocusExposureAndFraming() {
        let disposable = CaptureBehavior.for(.disposable1990s)
        XCTAssertEqual(disposable.focus, .deviceDefault, "Auto starts on continuous autofocus")
        XCTAssertEqual(disposable.exposure, .fixed)
        XCTAssertEqual(disposable.viewfinder, .threeByTwo)
        XCTAssertTrue(disposable.offersFlash)
        XCTAssertTrue(disposable.showsLowLightCue)
        XCTAssertFalse(disposable.offersZoomSteps)
        XCTAssertEqual(CaptureBehavior.for(.disposable1990s, focusSetting: .fixed).focus, .fixed)

        let super8 = CaptureBehavior.for(.super8HomeMovie)
        XCTAssertEqual(super8.focus, .deviceDefault, "Auto starts on continuous autofocus")
        XCTAssertEqual(super8.exposure, .automatic, "Automatic exposure")
        XCTAssertEqual(super8.viewfinder, .fourByThree)
        XCTAssertTrue(super8.offersZoomSteps, "The Super 8 rear camera offers the iPhone's own zoom steps")
        XCTAssertFalse(super8.offersFlash)
        XCTAssertFalse(super8.showsLowLightCue)
        XCTAssertEqual(CaptureBehavior.for(.super8HomeMovie, focusSetting: .fixed).focus, .fixed)

        let medium = CaptureBehavior.for(.mediumFormat6x6)
        XCTAssertEqual(medium.focus, .deviceDefault, "Auto starts on continuous autofocus")
        XCTAssertEqual(medium.exposure, .manualBias)
        XCTAssertEqual(medium.viewfinder, .square)
        XCTAssertFalse(medium.offersManualFocus, "The Focus slider stays hidden in Auto")
        XCTAssertTrue(medium.offersExposureBias)
        XCTAssertTrue(medium.offersZoomSteps, "The 6×6 offers the iPhone's own zoom steps")
        XCTAssertFalse(medium.offersFlash)
        let manual = CaptureBehavior.for(.mediumFormat6x6, focusSetting: .manual)
        XCTAssertEqual(manual.focus, .manual)
        XCTAssertTrue(manual.offersManualFocus)
    }

    func testCamerasOtherThanThoseThatChangedKeepTheirCaptureConfiguration() {
        XCTAssertEqual(CaptureBehavior.for(.instant1970s),
                       CaptureBehavior(focus: .deviceDefault, exposure: .automatic, viewfinder: .square))
        XCTAssertEqual(CaptureBehavior.for(.cinema16mm), CaptureBehavior(offersZoomSteps: true))
        for camera in CameraID.allCases where camera != .disposable1990s {
            XCTAssertNotEqual(CaptureBehavior.for(camera).exposure, .fixed, "\(camera)")
            XCTAssertFalse(CaptureBehavior.for(camera).showsLowLightCue, "\(camera)")
        }
        for camera in CameraID.allCases where ![.mediumFormat6x6, .super8HomeMovie, .cinema16mm].contains(camera) {
            XCTAssertFalse(CaptureBehavior.for(camera).offersZoomSteps, "\(camera) keeps its single lens")
        }
        for camera in CameraID.allCases where camera != .mediumFormat6x6 {
            XCTAssertFalse(CaptureBehavior.for(camera).offersManualFocus, "\(camera)")
        }
    }

    /// The captain, 2026-10-16: the 6×6's viewfinder is the normal one, no longer reversed like a waist-level finder.
    /// The front viewfinder stays mirrored for every Camera.
    func testNoRearViewfinderIsReversedAndEveryFrontViewfinderIsMirrored() {
        for camera in CameraID.allCases {
            let behavior = CaptureBehavior.for(camera)
            XCTAssertTrue(behavior.isViewfinderMirrored(position: .front), "\(camera) front keeps its mirrored behavior")
            XCTAssertFalse(behavior.isViewfinderMirrored(position: .rear), "\(camera) rear shows the scene the normal way")
        }
    }

    /// The 6×6's exposure bias goes with the person to each lens, within that lens's range, as their Focus position does;
    /// every other Camera's lens returns to the unbiased automatic default.
    func testOnlyTheSixBySixCarriesTheExposureBiasToTheNextLensWithinItsRange() {
        let medium = CaptureBehavior.for(.mediumFormat6x6)
        XCTAssertEqual(medium.lensExposureBias(carrying: 1, within: -2...2), 1)
        XCTAssertEqual(medium.lensExposureBias(carrying: 3, within: -2...2), 2, "Within the new lens's range")
        XCTAssertEqual(medium.lensExposureBias(carrying: -3, within: -2...2), -2)
        XCTAssertNil(medium.lensExposureBias(carrying: nil, within: -2...2), "With none carried, the lens keeps its own")
        for camera in CameraID.allCases where camera != .mediumFormat6x6 {
            XCTAssertEqual(CaptureBehavior.for(camera).lensExposureBias(carrying: 1, within: -2...2), 0, "\(camera)")
            XCTAssertEqual(CaptureBehavior.for(camera).lensExposureBias(carrying: nil, within: -2...2), 0, "\(camera)")
        }
    }

    func testViewfinderShapesFrameWhatTheCameraDevelops() {
        XCTAssertEqual(ViewfinderShape.threeByTwo.aspectRatio, 2.0 / 3, accuracy: 1e-9, "The Disposable's 3:2, upright")
        XCTAssertEqual(ViewfinderShape.fourByThree.aspectRatio, 3.0 / 4, accuracy: 1e-9)
        XCTAssertEqual(ViewfinderShape.square.aspectRatio, 1)
        XCTAssertTrue(ViewfinderShape.threeByTwo.cropsCapture)
        XCTAssertTrue(ViewfinderShape.square.cropsCapture)
        XCTAssertFalse(ViewfinderShape.fourByThree.cropsCapture, "The 4:3 viewfinder shows the whole capture")
    }

    func testSessionPlanCarriesTheCameraBehavior() {
        let capabilities = CaptureCapabilities(availablePositions: [.rear, .front], supportsLensSwitchDuringSession: true)
        let plan = CaptureSessionPlan(request: CaptureSessionRequest(
            preferredPosition: .rear, mediaKind: .photo,
            behavior: .for(.mediumFormat6x6, focusSetting: .manual), manualLensPosition: 0.1
        ), capabilities: capabilities)
        XCTAssertEqual(plan.behavior, CaptureBehavior.for(.mediumFormat6x6, focusSetting: .manual))
        XCTAssertEqual(plan.manualLensPosition, 0.1, "The person's focus travels with the plan")
        let plain = CaptureSessionPlan(request: CaptureSessionRequest(preferredPosition: .rear, mediaKind: .movie),
                                       capabilities: capabilities)
        XCTAssertEqual(plain.behavior, CaptureBehavior.deviceDefault)
        XCTAssertEqual(plain.manualLensPosition, FixedFocus.lensPosition, "The Focus control's resting value")
    }

    func testTapToFocusNeedsAutoAndRunsIdleOrDuringMovieRecording() {
        let capabilities = CaptureCapabilities(availablePositions: [.rear], supportsLensSwitchDuringSession: false)
        func plan(_ setting: FilmFocusSetting) -> CaptureSessionPlan {
            CaptureSessionPlan(request: CaptureSessionRequest(
                preferredPosition: .rear, mediaKind: .movie,
                behavior: .for(.super8HomeMovie, focusSetting: setting)
            ), capabilities: capabilities)
        }

        for camera in CameraID.allCases {
            let mediaKind: CaptureMediaKind = switch camera {
            case .super8HomeMovie, .cinema16mm: .movie
            default: .photo
            }
            let automatic = CaptureSessionPlan(request: CaptureSessionRequest(
                preferredPosition: .rear, mediaKind: mediaKind,
                behavior: .for(camera, focusSetting: .auto)
            ), capabilities: capabilities)
            XCTAssertEqual(automatic.focusPointDecision(supported: true, during: CapturePhase.idle), FocusPointDecision.allowed, "\(camera)")
            if camera == .super8HomeMovie || camera == .cinema16mm {
                XCTAssertEqual(automatic.focusPointDecision(supported: true, during: CapturePhase.recordingMovie), FocusPointDecision.allowed)
            }
            XCTAssertEqual(automatic.focusPointDecision(supported: false, during: CapturePhase.idle), FocusPointDecision.unsupported)
            XCTAssertEqual(automatic.focusPointDecision(supported: true, during: CapturePhase.savingPhoto), FocusPointDecision.blockedDuring(.savingPhoto))
        }
        XCTAssertEqual(plan(.fixed).focusPointDecision(supported: true, during: CapturePhase.idle), FocusPointDecision.notAutomatic)
        XCTAssertEqual(plan(.manual).focusPointDecision(supported: true, during: CapturePhase.idle), FocusPointDecision.notAutomatic)
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
