import FilmDomain
@testable import NativeAdapters
import XCTest

final class CaptureAdapterTests: XCTestCase {
    func testStartupDefersCameraPromptWhenPolicySaysCoordinatorOwnsTiming() async {
        let authorizer = FakeCaptureAuthorizer(status: .notDetermined)
        let coordinator = CaptureStartupCoordinator(
            authorizer: authorizer,
            capabilities: CaptureCapabilities(
                availablePositions: [.rear, .front],
                supportsLensSwitchDuringSession: true
            )
        )

        let outcome = await coordinator.startOutcome(
            for: CaptureSessionRequest(
                preferredPosition: .rear,
                mediaKind: .photo,
                permissionPromptPolicy: .deferToFlowCoordinator
            )
        )

        XCTAssertEqual(outcome, .needsPermission(.deferToFlowCoordinator))
        XCTAssertEqual(authorizer.requestCount, 0)
    }

    func testAuthorizedFrontRequestStartsOnTheFrontLensWithoutPrompting() async {
        let coordinator = CaptureStartupCoordinator(
            authorizer: FakeCaptureAuthorizer(status: .authorized),
            capabilities: CaptureCapabilities(
                availablePositions: [.rear, .front],
                supportsLensSwitchDuringSession: true
            )
        )

        let outcome = await coordinator.startOutcome(
            for: CaptureSessionRequest(preferredPosition: .front, mediaKind: .photo)
        )

        guard case let .ready(plan) = outcome else {
            return XCTFail("Expected ready capture plan")
        }
        XCTAssertEqual(plan.activePosition, .front)
        XCTAssertEqual(plan.mediaKind, .photo)
    }

    func testLensSwitchIsBlockedWhileSavingOrRecordingAndUnavailablePositionsAreReported() async {
        let coordinator = CaptureStartupCoordinator(
            authorizer: FakeCaptureAuthorizer(status: .authorized),
            capabilities: CaptureCapabilities(
                availablePositions: [.rear],
                supportsLensSwitchDuringSession: true
            )
        )
        let outcome = await coordinator.startOutcome(
            for: CaptureSessionRequest(preferredPosition: .rear, mediaKind: .movie)
        )
        guard case let .ready(plan) = outcome else {
            return XCTFail("Expected ready capture plan")
        }

        XCTAssertEqual(plan.lensSwitchDecision(to: .rear, during: .savingPhoto), .blockedDuring(.savingPhoto))
        XCTAssertEqual(plan.lensSwitchDecision(to: .rear, during: .recordingMovie), .blockedDuring(.recordingMovie))
        XCTAssertEqual(plan.lensSwitchDecision(to: .front, during: .idle), .unavailable(.front))
    }

    func testMoviePlanRetainsFinalPresentationOrientation() async {
        let coordinator = CaptureStartupCoordinator(
            authorizer: FakeCaptureAuthorizer(status: .authorized),
            capabilities: CaptureCapabilities(
                availablePositions: [.rear],
                supportsLensSwitchDuringSession: false
            )
        )

        let outcome = await coordinator.startOutcome(
            for: CaptureSessionRequest(
                preferredPosition: .rear,
                mediaKind: .movie,
                lockedMovieOrientation: .landscape
            )
        )

        guard case let .ready(plan) = outcome else {
            return XCTFail("Expected ready movie plan")
        }
        XCTAssertEqual(plan.lockedMovieOrientation, .landscape)
        XCTAssertEqual(plan.lensSwitchDecision(to: .rear, during: .idle), .disabledByConfiguration)
    }

    func testHeldOrientationRotatesFromTheSensorsHomeRightLandscapeFrame() {
        XCTAssertEqual(CaptureFrameOrientation.landscapeLeft.rotationAngle, 0, "Home side right is the sensor's native frame")
        XCTAssertEqual(CaptureFrameOrientation.landscapeRight.rotationAngle, 180)
        XCTAssertEqual(CaptureFrameOrientation.portrait.rotationAngle, 90)
        XCTAssertEqual(CaptureFrameOrientation.portraitUpsideDown.rotationAngle, 270)
        XCTAssertEqual(CaptureFrameOrientation.landscapeRight.clipOrientation, .landscape)
        XCTAssertEqual(CaptureFrameOrientation.portraitUpsideDown.clipOrientation, .portrait)
    }

    func testMoviesRecordTheLargestNative4x3FormatWithinTheEarlierPresetAtMovieFrameRate() {
        struct Format: Equatable { let width: Int, height: Int, recordsMovieFrames: Bool }
        func preferred(_ formats: [Format]) -> Format? {
            MovieCaptureFormat.preferred(among: formats, dimensions: { ($0.width, $0.height) },
                                         recordsMovieFrameRate: \.recordsMovieFrames)
        }
        let offered = [
            Format(width: 640, height: 480, recordsMovieFrames: true),
            Format(width: 1280, height: 720, recordsMovieFrames: true),
            Format(width: 1280, height: 960, recordsMovieFrames: true),
            Format(width: 1920, height: 1080, recordsMovieFrames: true),
            Format(width: 1440, height: 1080, recordsMovieFrames: true),
            Format(width: 1920, height: 1440, recordsMovieFrames: true),
            Format(width: 3840, height: 2160, recordsMovieFrames: true),
            Format(width: 4032, height: 3024, recordsMovieFrames: true)
        ]
        XCTAssertEqual(preferred(offered), Format(width: 1440, height: 1080, recordsMovieFrames: true))
        let highSpeedOnly = offered.map {
            $0.width == 1440 ? Format(width: 1440, height: 1080, recordsMovieFrames: false) : $0
        }
        XCTAssertEqual(preferred(highSpeedOnly), Format(width: 1280, height: 960, recordsMovieFrames: true))
        XCTAssertNil(preferred(offered.filter { $0.width * 3 != $0.height * 4 }), "A 16:9 format never records a Movie")
    }

    func testCaptureEventEmitterReportsSaveAndInterruptionCallbacksInOrder() {
        let sink = RecordingCaptureSink()
        let emitter = CaptureEventEmitter(sink: sink)
        let photoURL = URL(fileURLWithPath: "/tmp/photo.heic")
        let movieURL = URL(fileURLWithPath: "/tmp/movie.mov")

        emitter.interrupted(.videoDeviceNotAvailable)
        emitter.photoSaved(at: photoURL)
        emitter.movieClipSaved(at: movieURL, durationSeconds: 4, orientation: .portrait)
        emitter.saveFailed("disk full")
        emitter.interruptionEnded()

        XCTAssertEqual(
            sink.events,
            [
                .interrupted(.videoDeviceNotAvailable),
                .photoSaved(photoURL),
                .movieClipSaved(url: movieURL, durationSeconds: 4, orientation: .portrait),
                .saveFailed("disk full"),
                .interruptionEnded
            ]
        )
    }
}

private final class FakeCaptureAuthorizer: CapturePermissionAuthorizing, @unchecked Sendable {
    private let status: CaptureAuthorizationStatus
    private(set) var requestCount = 0

    init(status: CaptureAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() -> CaptureAuthorizationStatus {
        status
    }

    func requestAccess() async -> Bool {
        requestCount += 1
        return status == .authorized
    }
}

private final class RecordingCaptureSink: CaptureEventSink, @unchecked Sendable {
    private(set) var events: [CaptureSaveEvent] = []

    func receive(_ event: CaptureSaveEvent) {
        events.append(event)
    }
}
