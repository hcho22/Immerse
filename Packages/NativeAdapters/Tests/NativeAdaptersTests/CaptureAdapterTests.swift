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

    func testAuthorizedFrontCaptureMirrorsOnlyViewfinderAndNeverOutput() async {
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
        XCTAssertTrue(plan.viewfinderMirrored)
        XCTAssertFalse(plan.outputMirrored)
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

    func testMoviePlanIsSilentAndRetainsFinalPresentationOrientation() async {
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
        XCTAssertFalse(plan.recordsAudio)
        XCTAssertEqual(plan.lockedMovieOrientation, .landscape)
        XCTAssertEqual(plan.lensSwitchDecision(to: .rear, during: .idle), .disabledByConfiguration)
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
