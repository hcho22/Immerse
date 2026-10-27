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
