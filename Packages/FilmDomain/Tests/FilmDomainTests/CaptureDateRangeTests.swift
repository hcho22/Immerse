import XCTest
@testable import FilmDomain

final class CaptureDateRangeTests: XCTestCase {
    func testClockMovingBackwardsDoesNotChangeCaptureSequenceOrCrashDateRange() throws {
        var film = try Film(camera: CameraCatalog.disposable1990s, title: "Clock adjustment")
        let beforeAdjustment = Date(timeIntervalSince1970: 10_000)
        let afterAdjustment = Date(timeIntervalSince1970: 9_000)
        _ = try film.recordSavedPhoto(at: beforeAdjustment)
        _ = try film.recordSavedPhoto(at: afterAdjustment)
        XCTAssertEqual(film.captures.map(\.savedAt), [beforeAdjustment, afterAdjustment])
        XCTAssertEqual(film.captureDateRange, afterAdjustment...beforeAdjustment)
        XCTAssertEqual(film.remainingExposures, 25)
    }
}
