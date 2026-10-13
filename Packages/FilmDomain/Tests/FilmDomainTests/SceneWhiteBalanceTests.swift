import FilmDomain
import XCTest

/// A clip's recorded light round-trips through the metadata value the capture writes, and nothing else reads as one.
final class SceneWhiteBalanceTests: XCTestCase {
    func testTheRecordedLightRoundTripsThroughItsMetadataValue() {
        let light = SceneWhiteBalance(temperature: 3150.5, tint: -4.25)
        XCTAssertEqual(SceneWhiteBalance(metadataValue: light.metadataValue), light)
        XCTAssertEqual(SceneWhiteBalance(metadataValue: " 5500 , 0 "), SceneWhiteBalance(temperature: 5500, tint: 0))
        for value in ["", "5500", "warm,0", "5500,0,1", "nan,0", "0,0", "-3200,0", "inf,0"] {
            XCTAssertNil(SceneWhiteBalance(metadataValue: value), value)
        }
    }
}
