import EntitlementCore
import XCTest

final class EntitlementPolicyTests: XCTestCase {
    func testActiveSubscriptionAllowsNewFilmsAndExpiredSubscriptionStillAllowsExistingFilms() {
        let film = ExistingFilmEntitlement(
            filmID: UUID(),
            origin: .subscription,
            hasSavedCapture: true
        )

        XCTAssertEqual(
            EntitlementPolicy.decisionForNewFilm(
                subscription: .active,
                deviceTrial: .consumed(
                    record: DeviceTrialConsumptionRecord(filmID: UUID(), consumedAt: Date(timeIntervalSince1970: 1))
                ),
                requestedByNonSubscriber: false
            ),
            .allowed(.subscription)
        )
        XCTAssertEqual(
            EntitlementPolicy.decisionForNewFilm(
                subscription: .expired,
                deviceTrial: .consumed(
                    record: DeviceTrialConsumptionRecord(filmID: UUID(), consumedAt: Date(timeIntervalSince1970: 1))
                ),
                requestedByNonSubscriber: false
            ),
            .denied(.subscriptionRequired)
        )
        XCTAssertTrue(
            EntitlementPolicy.canContinueExistingFilm(
                film,
                subscription: .expired,
                deviceTrial: .consumed(
                    record: DeviceTrialConsumptionRecord(filmID: UUID(), consumedAt: Date(timeIntervalSince1970: 1))
                )
            )
        )
    }

    func testNonSubscriberCanStartExactlyOneCurrentDeviceTrialFilmAtATime() {
        let firstFilmID = UUID()
        let state = EntitlementPolicy.startCurrentDeviceTrialFilm(
            filmID: firstFilmID,
            deviceTrial: .unused
        )

        XCTAssertEqual(state, .success(.emptyFilmInProgress(filmID: firstFilmID)))
        XCTAssertEqual(
            EntitlementPolicy.decisionForNewFilm(
                subscription: .notPurchased,
                deviceTrial: .emptyFilmInProgress(filmID: firstFilmID),
                requestedByNonSubscriber: true
            ),
            .denied(.currentDeviceTrialAlreadyInProgress(firstFilmID))
        )
    }

    func testFailedFirstSaveDoesNotConsumeTrialAndSuccessfulFirstSaveDoes() throws {
        let filmID = UUID()
        let captureDate = Date(timeIntervalSince1970: 42)
        let emptyFilm = ExistingFilmEntitlement(
            filmID: filmID,
            origin: .currentDeviceTrial,
            hasSavedCapture: false
        )

        let afterFailure = try EntitlementPolicy.applyCaptureEvent(
            .failedBeforeDurableSave,
            to: emptyFilm,
            deviceTrial: .emptyFilmInProgress(filmID: filmID)
        )

        XCTAssertEqual(afterFailure.film.hasSavedCapture, false)
        XCTAssertEqual(afterFailure.deviceTrial, .emptyFilmInProgress(filmID: filmID))

        let afterSuccess = try EntitlementPolicy.applyCaptureEvent(
            .firstSuccessfulSave(captureDate),
            to: emptyFilm,
            deviceTrial: afterFailure.deviceTrial
        )

        XCTAssertEqual(afterSuccess.film.hasSavedCapture, true)
        XCTAssertEqual(
            afterSuccess.deviceTrial,
            .consumed(record: DeviceTrialConsumptionRecord(filmID: filmID, consumedAt: captureDate))
        )
        XCTAssertEqual(
            EntitlementPolicy.decisionForNewFilm(
                subscription: .notPurchased,
                deviceTrial: afterSuccess.deviceTrial,
                requestedByNonSubscriber: true
            ),
            .denied(.currentDeviceTrialConsumed)
        )
    }

    func testDeletingZeroSaveCurrentDeviceTrialFilmLeavesEligibilityAvailable() throws {
        let filmID = UUID()
        let emptyFilm = ExistingFilmEntitlement(
            filmID: filmID,
            origin: .currentDeviceTrial,
            hasSavedCapture: false
        )

        let state = try EntitlementPolicy.deleteCurrentDeviceTrialFilm(
            film: emptyFilm,
            deviceTrial: .emptyFilmInProgress(filmID: filmID)
        )

        XCTAssertEqual(state, .unused)
        XCTAssertEqual(
            EntitlementPolicy.decisionForNewFilm(
                subscription: .notPurchased,
                deviceTrial: state,
                requestedByNonSubscriber: true
            ),
            .allowed(.currentDeviceTrial)
        )
    }

    func testDeletingCapturedTrialFilmDoesNotRefundEligibility() throws {
        let filmID = UUID()
        let consumed = DeviceTrialState.consumed(
            record: DeviceTrialConsumptionRecord(filmID: filmID, consumedAt: Date(timeIntervalSince1970: 7))
        )
        let capturedFilm = ExistingFilmEntitlement(
            filmID: filmID,
            origin: .currentDeviceTrial,
            hasSavedCapture: true
        )

        let state = try EntitlementPolicy.deleteCurrentDeviceTrialFilm(
            film: capturedFilm,
            deviceTrial: consumed
        )

        XCTAssertEqual(state, consumed)
        XCTAssertEqual(
            EntitlementPolicy.decisionForNewFilm(
                subscription: .notPurchased,
                deviceTrial: state,
                requestedByNonSubscriber: true
            ),
            .denied(.currentDeviceTrialConsumed)
        )
    }

    func testRestoredTrialFilmsKeepCaptureRightsAndDoNotConsumeDestinationTrial() {
        let destinationTrial = DeviceTrialState.unused
        let restoredCaptured = ExistingFilmEntitlement(
            filmID: UUID(),
            origin: .restoredTrialFromAnotherDevice,
            hasSavedCapture: true
        )
        let restoredEmpty = ExistingFilmEntitlement(
            filmID: UUID(),
            origin: .restoredTrialFromAnotherDevice,
            hasSavedCapture: false
        )

        XCTAssertTrue(
            EntitlementPolicy.canContinueExistingFilm(
                restoredCaptured,
                subscription: .notPurchased,
                deviceTrial: destinationTrial
            )
        )
        XCTAssertTrue(
            EntitlementPolicy.canContinueExistingFilm(
                restoredEmpty,
                subscription: .notPurchased,
                deviceTrial: destinationTrial
            )
        )
        XCTAssertEqual(
            EntitlementPolicy.restoredTrialFilmDoesNotConsumeThisDevice(deviceTrial: destinationTrial),
            .unused
        )
        XCTAssertEqual(
            EntitlementPolicy.decisionForNewFilm(
                subscription: .notPurchased,
                deviceTrial: destinationTrial,
                requestedByNonSubscriber: true
            ),
            .allowed(.currentDeviceTrial)
        )
    }
}
