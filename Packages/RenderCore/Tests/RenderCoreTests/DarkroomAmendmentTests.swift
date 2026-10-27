import CoreGraphics
import FilmDomain
import Foundation
import ImageIO
import RenderCore
import UniformTypeIdentifiers
import XCTest

final class DarkroomAmendmentTests: XCTestCase {
    func testNewRecipeValuesUseTheirLimitsAndRejectValuesOutsideOrForUnsupportedPrints() throws {
        let color = CameraCatalog.disposable1990s
        for recipe in [
            DarkroomRecipe(rotationQuarterTurns: 0),
            DarkroomRecipe(rotationQuarterTurns: 3),
            DarkroomRecipe(straighteningDegrees: -45),
            DarkroomRecipe(straighteningDegrees: 45),
            DarkroomRecipe(saturation: -50),
            DarkroomRecipe(saturation: 50),
            DarkroomRecipe(vignetteStops: -2),
            DarkroomRecipe(vignetteStops: 2)
        ] {
            XCTAssertNoThrow(try NativePhotoRenderer.validate(recipe, camera: color), "\(recipe)")
        }

        for recipe in [
            DarkroomRecipe(rotationQuarterTurns: -1),
            DarkroomRecipe(rotationQuarterTurns: 4),
            DarkroomRecipe(straighteningDegrees: -45.1),
            DarkroomRecipe(straighteningDegrees: 45.1),
            DarkroomRecipe(straighteningDegrees: 0.15),
            DarkroomRecipe(saturation: -51),
            DarkroomRecipe(saturation: 51),
            DarkroomRecipe(vignetteStops: -2.1),
            DarkroomRecipe(vignetteStops: 2.1),
            DarkroomRecipe(vignetteStops: .infinity),
            DarkroomRecipe(vignetteStops: 0.15)
        ] {
            XCTAssertThrowsError(try NativePhotoRenderer.validate(recipe, camera: color), "\(recipe)") {
                XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
            }
        }

        XCTAssertThrowsError(try NativePhotoRenderer.validate(DarkroomRecipe(saturation: 1),
                                                               camera: CameraCatalog.mediumFormat6x6,
                                                               process: .silverGelatin))
        XCTAssertThrowsError(try NativePhotoRenderer.validate(DarkroomRecipe(straighteningDegrees: 1),
                                                               camera: CameraCatalog.instant1970s))
        XCTAssertNoThrow(try NativePhotoRenderer.validate(DarkroomRecipe(rotationQuarterTurns: 1),
                                                           camera: CameraCatalog.instant1970s))
        XCTAssertNoThrow(try NativePhotoRenderer.validate(DarkroomRecipe(vignetteStops: 2),
                                                           camera: CameraCatalog.mediumFormat6x6,
                                                           process: .silverGelatin))
    }

    func testQuarterTurnRotatesTheWholeInstantCardAndSwapsItsDimensions() throws {
        let master = try instantCard()
        let turned = try DecodedPixels(NativePhotoRenderer.print(
            master: master, recipe: DarkroomRecipe(rotationQuarterTurns: 1), camera: CameraCatalog.instant1970s
        ))
        XCTAssertEqual([turned.width, turned.height], [InstantPrintCard.height, InstantPrintCard.width])
        for (x, y) in [(4, 4), (turned.width - 5, 4), (4, turned.height - 5), (turned.width - 5, turned.height - 5)] {
            XCTAssertGreaterThan(turned.channel(0, x: x, y: y), 245, "The turned card stays white at \(x),\(y)")
        }
        XCTAssertGreaterThan(turned.channel(2, x: turned.width / 2, y: turned.height / 2), 145,
                             "The picture rotates with the card")
    }

    func testDisposableTurnsExportInTheirTurnedShape() throws {
        let master = try solidJPEG(width: 240, height: 160, color: (170, 65, 105))
        for (turns, size) in [(1, [160, 240]), (2, [240, 160]), (3, [160, 240])] {
            let turned = try DecodedPixels(NativePhotoRenderer.print(
                master: master, recipe: DarkroomRecipe(rotationQuarterTurns: turns), camera: CameraCatalog.disposable1990s
            ))
            XCTAssertEqual([turned.width, turned.height], size, "Quarter turn \(turns) exports with its turned shape")
        }
    }

    func testQuarterTurnControlsCycleFourTimesBackToTheDevelopedOrientation() {
        var left = DarkroomRecipe()
        left.rotateLeft()
        XCTAssertEqual(left.rotationQuarterTurns, 1)
        for _ in 0..<3 { left.rotateLeft() }
        XCTAssertNil(left.rotationQuarterTurns)

        var right = DarkroomRecipe()
        right.rotateRight()
        XCTAssertEqual(right.rotationQuarterTurns, 3)
        for _ in 0..<3 { right.rotateRight() }
        XCTAssertNil(right.rotationQuarterTurns)
    }

    func testStraighteningCropsToTheLargestSameShapeAreaWithoutBlankCornersAndKeepsSixBySixSquare() throws {
        let landscapeMaster = try solidJPEG(width: 240, height: 160, color: (170, 65, 105))
        for angle in [-45.0, -7.3, 0.1, 7.3, 45.0] {
            let straightened = try DecodedPixels(NativePhotoRenderer.print(
                master: landscapeMaster, recipe: DarkroomRecipe(straighteningDegrees: angle),
                camera: CameraCatalog.disposable1990s
            ))
            XCTAssertLessThan(straightened.width, 240, "Straightening \(angle) crops in")
            XCTAssertLessThan(straightened.height, 160, "Straightening \(angle) crops in")
            XCTAssertEqual(Double(straightened.width) / Double(straightened.height), 1.5, accuracy: 0.02)
            for (x, y) in [(0, 0), (straightened.width - 1, 0), (0, straightened.height - 1),
                           (straightened.width - 1, straightened.height - 1)] {
                XCTAssertGreaterThan(straightened.channel(0, x: x, y: y), 120,
                                     "A source color reaches crop corner at \(angle)°: \(x),\(y)")
                XCTAssertLessThan(straightened.channel(2, x: x, y: y), 160,
                                  "No blank corner at \(angle)°: \(x),\(y)")
            }
        }

        let squareMaster = try solidJPEG(width: 160, height: 160, color: (90, 135, 185))
        let square = try DecodedPixels(NativePhotoRenderer.print(
            master: squareMaster, recipe: DarkroomRecipe(straighteningDegrees: 7.3),
            camera: CameraCatalog.mediumFormat6x6
        ))
        XCTAssertEqual(square.width, square.height)
    }

    func testSaturationStaysVisibleAtItsLowEndAndVignetteReachesEachCornerInStops() throws {
        let colorMaster = try solidJPEG(width: 160, height: 120, color: (190, 105, 55))
        let developed = try DecodedPixels(colorMaster)
        let low = try DecodedPixels(NativePhotoRenderer.print(
            master: colorMaster, recipe: DarkroomRecipe(saturation: -50), camera: CameraCatalog.disposable1990s
        ))
        let high = try DecodedPixels(NativePhotoRenderer.print(
            master: colorMaster, recipe: DarkroomRecipe(saturation: 50), camera: CameraCatalog.disposable1990s
        ))
        let developedSpread = developed.channel(0, x: 80, y: 60) - developed.channel(2, x: 80, y: 60)
        let lowSpread = low.channel(0, x: 80, y: 60) - low.channel(2, x: 80, y: 60)
        let highSpread = high.channel(0, x: 80, y: 60) - high.channel(2, x: 80, y: 60)
        XCTAssertGreaterThan(lowSpread, 0, "Minus 50 still leaves color")
        XCTAssertEqual(Double(lowSpread) / Double(developedSpread), 0.5, accuracy: 0.06)
        XCTAssertEqual(Double(highSpread) / Double(developedSpread), 1.5, accuracy: 0.09)
        var reset = DarkroomRecipe(saturation: -50, vignetteStops: 2,
            dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 1)])
        reset.resetToOriginal()
        XCTAssertTrue(reset.dodgeBurnMasks.isEmpty, "Reset clears saved legacy strokes")
        XCTAssertEqual(try NativePhotoRenderer.print(master: colorMaster, recipe: reset,
                                                     camera: CameraCatalog.disposable1990s), colorMaster)

        let grayMaster = try solidJPEG(width: 160, height: 120, color: (120, 120, 120))
        let unvignetted = try DecodedPixels(grayMaster)
        let darkened = try DecodedPixels(NativePhotoRenderer.print(
            master: grayMaster, recipe: DarkroomRecipe(vignetteStops: 2), camera: CameraCatalog.disposable1990s
        ))
        let lightened = try DecodedPixels(NativePhotoRenderer.print(
            master: grayMaster, recipe: DarkroomRecipe(vignetteStops: -2), camera: CameraCatalog.disposable1990s
        ))
        let center = darkened.channel(0, x: 80, y: 60)
        XCTAssertEqual(center, unvignetted.channel(0, x: 80, y: 60), accuracy: 1)
        XCTAssertEqual(lightened.channel(0, x: 80, y: 60), unvignetted.channel(0, x: 80, y: 60), accuracy: 1)
        let baselineLinear = linearSRGB(unvignetted.channel(0, x: 2, y: 2))
        XCTAssertEqual(linearSRGB(darkened.channel(0, x: 2, y: 2)) / baselineLinear, 0.25, accuracy: 0.06)
        XCTAssertEqual(linearSRGB(lightened.channel(0, x: 2, y: 2)) / baselineLinear, 4, accuracy: 0.45)
    }

    /// Rotate left turns the whole Instant card counterclockwise, so its deep bottom border comes to the right; Rotate
    /// right turns it clockwise, the border to the left (D4).
    func testInstantQuarterTurnsMoveTheDeepBorderToTheSideTheyTurnTo() throws {
        let master = try instantCardWithItsDeepBorderAtTheBottom()
        for (turns, deepBorderRight) in [(1, true), (3, false)] {
            let turned = try DecodedPixels(NativePhotoRenderer.print(
                master: master, recipe: DarkroomRecipe(rotationQuarterTurns: turns), camera: CameraCatalog.instant1970s
            ))
            let middle = turned.height / 2
            let border = deepBorderRight ? turned.width - 300 : 300
            let picture = deepBorderRight ? 300 : turned.width - 300
            XCTAssertGreaterThan(turned.channel(0, x: border, y: middle), 245, "Turn \(turns): the deep border is white")
            XCTAssertLessThan(turned.channel(0, x: picture, y: middle), 80, "Turn \(turns): the picture is opposite it")
        }
    }

    /// A marked top-left quadrant lands where each turn takes it: bottom left after Rotate left, top right after Rotate
    /// right, bottom right after two turns (D4).
    func testDisposableQuarterTurnsCarryTheTopLeftCornerTheWayTheyTurn() throws {
        let master = try quadrantJPEG(width: 240, height: 160)
        let cases: [(Int, (Bool, Bool))] = [(1, (false, true)), (3, (true, false)), (2, (true, true))]
        for (turns, (right, bottom)) in cases {
            let turned = try DecodedPixels(NativePhotoRenderer.print(
                master: master, recipe: DarkroomRecipe(rotationQuarterTurns: turns), camera: CameraCatalog.disposable1990s
            ))
            let x = right ? turned.width * 3 / 4 : turned.width / 4
            let y = bottom ? turned.height * 3 / 4 : turned.height / 4
            XCTAssertGreaterThan(turned.channel(0, x: x, y: y), 180, "Turn \(turns): the marked corner is where it turned to")
            XCTAssertLessThan(turned.channel(0, x: turned.width - 1 - x, y: turned.height - 1 - y), 80,
                              "Turn \(turns): the opposite corner is unmarked")
        }
    }

    /// A horizontal edge straightened by 7.3° tilts across the print by about tan(7.3°) of its width, and the print is the
    /// largest same-shape rectangle less its sampling margin, upright and sideways (D4, D1).
    func testStraighteningTiltsThePictureAndKeepsTheLargestRectangle() throws {
        for (width, height) in [(240, 160), (160, 240)] {
            let master = try twoToneJPEG(width: width, height: height)
            let degrees = 7.3
            let straightened = try DecodedPixels(NativePhotoRenderer.print(
                master: master, recipe: DarkroomRecipe(straighteningDegrees: degrees), camera: CameraCatalog.disposable1990s
            ))
            let radians = degrees * .pi / 180, ratio = Double(width) / Double(height)
            let largest = min(Double(width) / (cos(radians) + sin(radians) / ratio),
                              Double(height) / (sin(radians) + cos(radians) / ratio))
            XCTAssertEqual(straightened.width, Int((largest - 4).rounded(.down)), "\(width)x\(height): the largest rectangle")
            let expected = StraighteningGeometry.croppedSize(width: Double(width), height: Double(height), degrees: degrees)
            XCTAssertEqual([straightened.width, straightened.height], [expected.width, expected.height],
                           "The Darkroom's live crop-in uses the size the print is cut to")
            func edgeRow(_ column: Int) -> Int {
                (0..<straightened.height).first { straightened.channel(0, x: column, y: $0) > 128 } ?? straightened.height
            }
            let left = edgeRow(2), right = edgeRow(straightened.width - 3)
            let rise = Double(abs(left - right))
            XCTAssertEqual(rise, tan(radians) * Double(straightened.width - 5), accuracy: 4,
                           "\(width)x\(height): the edge tilts end to end (rows \(left) and \(right))")
        }
    }

    /// Straightening keeps light above white, as every other step does: a bright corner printed +2 stops with a Vignette
    /// of +2 prints the same with 0.1° of straightening as without (D3).
    func testStraighteningKeepsLightAboveWhiteForTheVignette() throws {
        let master = try solidJPEG(width: 240, height: 160, color: (200, 200, 200))
        let flat = try DecodedPixels(NativePhotoRenderer.print(
            master: master, recipe: DarkroomRecipe(printExposureStops: 2, vignetteStops: 2),
            camera: CameraCatalog.disposable1990s))
        let tilted = try DecodedPixels(NativePhotoRenderer.print(
            master: master, recipe: DarkroomRecipe(printExposureStops: 2, straighteningDegrees: 0.1, vignetteStops: 2),
            camera: CameraCatalog.disposable1990s))
        XCTAssertEqual(tilted.channel(0, x: 2, y: 2), flat.channel(0, x: 2, y: 2), accuracy: 2)
    }

    /// After a quarter turn the crop sliders move the crop across the turned print as it shows: a larger Horizontal
    /// value after Rotate left moves the crop right, and four turns give the crop back (D2).
    func testACropTurnsWithThePrint() throws {
        var recipe = DarkroomRecipe(crop: Crop(x: 0.1, y: 0.2, width: 0.5, height: 0.5))
        let original = recipe.crop
        for _ in 0..<4 { recipe.rotateLeft() }
        XCTAssertEqual(recipe.crop, original, "Four turns give the crop back")
        for _ in 0..<4 { recipe.rotateRight() }
        XCTAssertEqual(recipe.crop, original)

        let master = try quadrantJPEG(width: 200, height: 200)
        func markedShare(_ crop: Crop) throws -> Double {
            var turned = DarkroomRecipe(crop: crop)
            turned.rotationQuarterTurns = 1
            let print = try DecodedPixels(NativePhotoRenderer.print(master: master, recipe: turned,
                                                                    camera: CameraCatalog.disposable1990s))
            let marked = (0..<print.width).filter { print.channel(0, x: $0, y: print.height / 2) > 180 }.count
            return Double(marked) / Double(print.width)
        }
        // Turned left, the marked top-left quadrant is at the bottom left: a crop of the bottom half sees it on its left,
        // and moving the crop right leaves less of it.
        let atLeft = try markedShare(Crop(x: 0, y: 0.5, width: 0.5, height: 0.5))
        let movedRight = try markedShare(Crop(x: 0.25, y: 0.5, width: 0.5, height: 0.5))
        XCTAssertGreaterThan(atLeft, 0.9)
        XCTAssertLessThan(movedRight, atLeft - 0.3, "A larger Horizontal moves the crop right on the turned print")
    }

    private func instantCardWithItsDeepBorderAtTheBottom() throws -> Data {
        let width = InstantPrintCard.width, height = InstantPrintCard.height
        let side = (width - InstantPrintCard.pictureSide) / 2
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in side..<(side + InstantPrintCard.pictureSide) {
            for x in side..<(side + InstantPrintCard.pictureSide) {
                let index = (y * width + x) * 4
                bytes[index] = 35
                bytes[index + 1] = 95
                bytes[index + 2] = 175
            }
        }
        return try jpeg(bytes, width: width, height: height)
    }

    /// Red in the top-left quadrant, dark blue elsewhere.
    private func quadrantJPEG(width: Int, height: Int) throws -> Data {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let marked = x < width / 2 && y < height / 2
                bytes[index] = marked ? 230 : 20
                bytes[index + 1] = marked ? 40 : 30
                bytes[index + 2] = marked ? 40 : 120
            }
        }
        return try jpeg(bytes, width: width, height: height)
    }

    /// Dark above a horizontal edge across the middle, light below it.
    private func twoToneJPEG(width: Int, height: Int) throws -> Data {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            let value: UInt8 = y < height / 2 ? 30 : 220
            for x in 0..<width {
                let index = (y * width + x) * 4
                bytes[index] = value
                bytes[index + 1] = value
                bytes[index + 2] = value
            }
        }
        return try jpeg(bytes, width: width, height: height)
    }

    private func linearSRGB(_ encoded: Int) -> Double {
        let value = Double(encoded) / 255
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private func instantCard() throws -> Data {
        let width = InstantPrintCard.width, height = InstantPrintCard.height
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in InstantPrintCard.bottomBorder..<(height - InstantPrintCard.sideBorder) {
            for x in InstantPrintCard.sideBorder..<(width - InstantPrintCard.sideBorder) {
                let index = (y * width + x) * 4
                bytes[index] = 35
                bytes[index + 1] = 95
                bytes[index + 2] = 175
            }
        }
        return try jpeg(bytes, width: width, height: height)
    }

    private func solidJPEG(width: Int, height: Int, color: (UInt8, UInt8, UInt8)) throws -> Data {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            bytes[index] = color.0
            bytes[index + 1] = color.1
            bytes[index + 2] = color.2
        }
        return try jpeg(bytes, width: width, height: height)
    }

    private func jpeg(_ bytes: [UInt8], width: Int, height: Int) throws -> Data {
        var mutable = bytes
        let image = try mutable.withUnsafeMutableBytes { buffer in
            try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage())
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 1] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

private extension DecodedPixels {
    func channel(_ channel: Int, x: Int, y: Int) -> Int { Int(bytes[(y * width + x) * 4 + channel]) }
}
