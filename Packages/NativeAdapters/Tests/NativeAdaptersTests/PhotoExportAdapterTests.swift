@testable import NativeAdapters
import XCTest

final class PhotoExportAdapterTests: XCTestCase {
    func testExportDefersAddOnlyPhotosPromptWhenFlowCoordinatorOwnsTiming() async {
        let authorizer = FakePhotoAuthorizer(status: .notDetermined)
        let writer = FakePhotoWriter(result: .success(PhotoExportReceipt(localIdentifier: "asset-1")))
        let coordinator = PhotoExportCoordinator(
            authorizer: authorizer,
            writer: writer,
            promptPolicy: .deferToFlowCoordinator
        )

        let outcome = await coordinator.export(
            PhotoExportRequest(fileURL: URL(fileURLWithPath: "/tmp/photo.heic"), mediaKind: .photo)
        )

        XCTAssertEqual(outcome, .needsPermission(.addOnly))
        XCTAssertEqual(authorizer.requestCount, 0)
        XCTAssertEqual(writer.writeCount, 0)
        XCTAssertFalse(outcome.permitsSourceCleanupAfterIndependentVerification)
    }

    func testDeniedPhotosPermissionIsReportedWithoutAttemptingAWrite() async {
        let authorizer = FakePhotoAuthorizer(status: .denied)
        let writer = FakePhotoWriter(result: .success(PhotoExportReceipt(localIdentifier: "asset-1")))
        let coordinator = PhotoExportCoordinator(authorizer: authorizer, writer: writer)

        let outcome = await coordinator.export(
            PhotoExportRequest(fileURL: URL(fileURLWithPath: "/tmp/photo.heic"), mediaKind: .photo)
        )

        XCTAssertEqual(outcome, .permissionDenied(.denied))
        XCTAssertEqual(writer.writeCount, 0)
        XCTAssertFalse(outcome.permitsSourceCleanupAfterIndependentVerification)
    }

    func testWriteFailureIsHonestAndDoesNotPermitSourceCleanup() async {
        let authorizer = FakePhotoAuthorizer(status: .authorized)
        let writer = FakePhotoWriter(result: .failure(FakePhotoWriteError.diskFull))
        let coordinator = PhotoExportCoordinator(authorizer: authorizer, writer: writer)

        let outcome = await coordinator.export(
            PhotoExportRequest(fileURL: URL(fileURLWithPath: "/tmp/movie.mov"), mediaKind: .movie)
        )

        XCTAssertEqual(outcome, .writeFailed("diskFull"))
        XCTAssertEqual(writer.writeCount, 1)
        XCTAssertFalse(outcome.permitsSourceCleanupAfterIndependentVerification)
    }

    func testSuccessfulAddOnlyExportPermitsOnlyLaterVerifiedCleanup() async {
        let receipt = PhotoExportReceipt(localIdentifier: "asset-42")
        let authorizer = FakePhotoAuthorizer(status: .authorized)
        let writer = FakePhotoWriter(result: .success(receipt))
        let coordinator = PhotoExportCoordinator(authorizer: authorizer, writer: writer)

        let outcome = await coordinator.export(
            PhotoExportRequest(fileURL: URL(fileURLWithPath: "/tmp/photo.heic"), mediaKind: .photo)
        )

        XCTAssertEqual(outcome, .exported(receipt))
        XCTAssertTrue(outcome.permitsSourceCleanupAfterIndependentVerification)
    }
}

private final class FakePhotoAuthorizer: PhotoLibraryAuthorizing, @unchecked Sendable {
    private let status: PhotoLibraryAuthorizationStatus
    private(set) var requestCount = 0

    init(status: PhotoLibraryAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus {
        status
    }

    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus {
        requestCount += 1
        return status
    }
}

private final class FakePhotoWriter: PhotoLibraryWriting, @unchecked Sendable {
    private let result: Result<PhotoExportReceipt, Error>
    private(set) var writeCount = 0

    init(result: Result<PhotoExportReceipt, Error>) {
        self.result = result
    }

    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        writeCount += 1
        return try result.get()
    }
}

private enum FakePhotoWriteError: Error, CustomStringConvertible {
    case diskFull

    var description: String {
        switch self {
        case .diskFull:
            return "diskFull"
        }
    }
}
