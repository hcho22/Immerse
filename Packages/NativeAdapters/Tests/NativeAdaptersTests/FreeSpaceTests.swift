@testable import NativeAdapters
import XCTest

final class FreeSpaceTests: XCTestCase {
    func testLowIsLessThanTwoDecimalGigabytes() {
        XCTAssertEqual(LowStorage.thresholdBytes, 2_000_000_000, "2 GB as iPhone Settings counts it")
        XCTAssertNotEqual(LowStorage.thresholdBytes, 2 * 1024 * 1024 * 1024, "Not 2 × 1024³")
        XCTAssertTrue(LowStorage.isLow(availableBytes: 1_999_999_999), "Just under")
        XCTAssertFalse(LowStorage.isLow(availableBytes: 2_000_000_000), "Exactly at")
        XCTAssertFalse(LowStorage.isLow(availableBytes: 2_000_000_001), "Just over")
        XCTAssertTrue(LowStorage.isLow(availableBytes: 0))
        // Between the decimal and the binary reading of "2 GB": not low.
        XCTAssertFalse(LowStorage.isLow(availableBytes: 2_100_000_000))
    }

    func testVolumeReaderReadsTheVolumeThatHoldsItsDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FreeSpace-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertGreaterThan(try VolumeFreeSpaceReader(url: directory).availableBytes(), 0)
    }

    func testVolumeReaderReadsAgainEachTimeRatherThanReturningItsFirstReading() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FreeSpace-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let reader = VolumeFreeSpaceReader(url: directory)
        XCTAssertGreaterThan(try reader.availableBytes(), 0)
        try FileManager.default.removeItem(at: directory)
        XCTAssertThrowsError(try reader.availableBytes(), "The reader returned its first reading of a directory that is gone")
    }

    func testVolumeReaderThrowsWhereThereIsNothingToRead() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("FreeSpace-missing-\(UUID())")
        XCTAssertThrowsError(try VolumeFreeSpaceReader(url: missing).availableBytes())
    }
}
