import CoreGraphics
import FilmDomain
import Foundation
@testable import RenderCore
import RenderFixtures
import XCTest

/// The Instant across treatment versions 3 and 4. Version 4 gave it the contrast the captain chose on 2026-10-13
/// after the study of preserved 1970s prints; version 3 is frozen, so an Instant Film loaded under it develops as the
/// version 3 build developed it (ADR 0013, CAM-01, RK-11).
///
/// The expected values are the mean red, green and blue of an 8 x 8 grid over each developed print, card and all,
/// recorded from the version 3 build (5c3a217) with the same fixture and seeds, as `LegacyLookTests` records versions
/// 1 and 2. Version 3's grain is the same on every renderer, so unlike those these hold inside the iOS simulator too.
final class InstantVersionTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("InstantVersionTests-\(UUID())")
        // The photo is the fixture's own size, as the values were recorded; only the unused movie is made small.
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.4
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private var photo: URL { root.appendingPathComponent("synthetic-developed-photo.jpg") }

    func testVersionThreeInstantPrintsDevelopAsTheVersionThreeBuildDeveloped() throws {
        for (seed, means) in Self.versionThree {
            let print = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: CameraCatalog.instant1970s, seed: seed,
                                                                      treatmentVersion: "film-look-3"))
            XCTAssertEqual("\(print.width)x\(print.height)", "2282x2774", "seed \(seed)")
            let measured = Self.blockMeans(print)
            XCTAssertEqual(measured.count, means.count)
            let largest = zip(measured, means).map { abs($0 - $1) }.max() ?? 0
            XCTAssertLessThanOrEqual(largest, 2, "Seed \(seed) differs from the version 3 build's print by up to \(largest) levels")
        }
    }

    /// A print develops with the version its capture was assigned: version 4's is not version 3's, by far more than
    /// one print differs from the next, and the difference is in the picture alone, since the card stays white.
    func testVersionFourInstantPrintsAreNotVersionThrees() throws {
        let camera = CameraCatalog.instant1970s
        let earlier = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, treatmentVersion: "film-look-3"))
        let today = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42))
        XCTAssertEqual(try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42,
                                                                     treatmentVersion: "film-look-4")).bytes, today.bytes)
        let card = InstantPrintCard.self
        let picture = (x: card.sideBorder..<(card.sideBorder + card.pictureSide), y: card.sideBorder..<(card.sideBorder + card.pictureSide))
        func spread(_ print: DecodedPixels) -> Double {
            // How far the picture's darkest and lightest sixteenths sit apart.
            var blocks: [Double] = []
            for row in 0..<4 { for column in 0..<4 {
                let x0 = picture.x.lowerBound + column * card.pictureSide / 4, y0 = picture.y.lowerBound + row * card.pictureSide / 4
                blocks.append(print.meanLuminance(x: x0..<(x0 + card.pictureSide / 4), y: y0..<(y0 + card.pictureSide / 4)))
            } }
            return blocks.max()! - blocks.min()!
        }
        XCTAssertGreaterThan(spread(today), spread(earlier) * 1.2, "Version 4 spreads its tones further apart")
        // The card, below the picture, is the same clean white in both.
        let below = (card.sideBorder + card.pictureSide + 40)..<(card.height - 40)
        XCTAssertGreaterThan(today.meanLuminance(x: 40..<(card.width - 40), y: below), 252)
        XCTAssertGreaterThan(earlier.meanLuminance(x: 40..<(card.width - 40), y: below), 252)
    }

    /// `DecodedPixels.blockMeans()`, the measure the values were recorded with, summed in whole numbers through a
    /// plain buffer: a print is six million pixels, and the general one takes half a minute a print in a test build.
    private static func blockMeans(_ print: DecodedPixels, grid: Int = 8) -> [Int] {
        var result: [Int] = []
        print.bytes.withUnsafeBufferPointer { bytes in
            for row in 0..<grid { for column in 0..<grid {
                let x0 = column * print.width / grid, x1 = (column + 1) * print.width / grid
                let y0 = row * print.height / grid, y1 = (row + 1) * print.height / grid
                var red = 0, green = 0, blue = 0
                for y in y0..<y1 {
                    var index = (y * print.width + x0) * 4
                    for _ in x0..<x1 {
                        red += Int(bytes[index]); green += Int(bytes[index + 1]); blue += Int(bytes[index + 2])
                        index += 4
                    }
                }
                let count = Double((x1 - x0) * (y1 - y0))
                result += [red, green, blue].map { Int((Double($0) / count).rounded()) }
            } }
        }
        return result
    }

    private static let versionThree: [(seed: UInt64, means: [Int])] = [
        (42, [
            198, 190, 201, 178, 154, 181, 201, 157, 178, 137, 134, 143, 160, 145, 165, 182, 157, 185, 192, 152, 168, 181, 182, 187,
            174, 177, 194, 143, 124, 139, 179, 116, 106, 96, 116, 125, 120, 126, 155, 150, 123, 132, 167, 114, 106, 155, 171, 175,
            181, 195, 181, 152, 154, 120, 189, 161, 143, 121, 164, 166, 133, 160, 136, 160, 157, 125, 179, 158, 145, 170, 197, 200,
            179, 183, 178, 152, 145, 146, 190, 154, 163, 106, 130, 117, 129, 138, 128, 160, 149, 153, 177, 147, 154, 161, 178, 170,
            174, 174, 191, 144, 122, 147, 180, 113, 107, 93, 110, 120, 120, 121, 151, 152, 123, 142, 168, 110, 104, 153, 167, 172,
            179, 191, 184, 147, 144, 115, 182, 150, 134, 115, 153, 158, 129, 152, 140, 154, 146, 117, 173, 149, 137, 167, 192, 195,
            237, 242, 236, 230, 234, 225, 238, 235, 231, 223, 235, 231, 226, 234, 223, 231, 234, 226, 236, 235, 231, 235, 243, 242,
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
        ]),
        (7, [
            199, 191, 203, 180, 156, 184, 205, 159, 181, 139, 135, 145, 161, 147, 168, 185, 159, 188, 195, 154, 170, 182, 183, 188,
            176, 179, 197, 147, 128, 144, 184, 120, 109, 98, 120, 129, 123, 130, 160, 155, 127, 136, 172, 118, 109, 157, 173, 177,
            183, 198, 183, 156, 159, 124, 196, 166, 148, 124, 170, 172, 137, 165, 141, 164, 162, 128, 185, 164, 150, 172, 201, 203,
            181, 186, 180, 156, 150, 151, 197, 160, 169, 110, 135, 121, 133, 143, 132, 165, 155, 158, 183, 153, 160, 163, 180, 172,
            175, 176, 194, 148, 126, 153, 186, 116, 110, 96, 113, 123, 122, 124, 156, 156, 126, 148, 173, 113, 106, 155, 169, 174,
            180, 194, 187, 151, 149, 118, 188, 155, 138, 118, 159, 164, 132, 156, 145, 159, 151, 120, 178, 153, 141, 169, 195, 198,
            238, 243, 236, 231, 235, 226, 239, 237, 232, 224, 237, 233, 226, 235, 224, 233, 236, 227, 237, 236, 233, 236, 244, 243,
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
        ]),
        (20261013, [
            199, 191, 203, 180, 156, 183, 206, 159, 181, 139, 135, 145, 162, 147, 167, 186, 159, 188, 196, 154, 170, 182, 183, 188,
            176, 179, 196, 148, 127, 143, 186, 120, 109, 98, 120, 128, 123, 129, 159, 156, 127, 136, 174, 118, 108, 157, 172, 177,
            183, 198, 183, 157, 158, 123, 197, 166, 147, 124, 169, 171, 137, 165, 140, 165, 162, 128, 186, 163, 149, 172, 200, 203,
            181, 186, 180, 157, 149, 150, 198, 159, 168, 110, 135, 121, 133, 143, 131, 166, 154, 157, 185, 152, 159, 163, 180, 172,
            175, 175, 193, 149, 125, 152, 188, 116, 110, 96, 113, 123, 123, 124, 155, 157, 126, 147, 175, 113, 106, 155, 168, 174,
            180, 194, 186, 152, 148, 117, 189, 154, 138, 118, 158, 163, 132, 156, 144, 159, 151, 120, 180, 153, 140, 169, 195, 197,
            238, 243, 236, 231, 235, 226, 240, 237, 232, 224, 237, 233, 227, 235, 223, 233, 236, 227, 238, 236, 233, 236, 244, 243,
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
        ])
    ]
}
