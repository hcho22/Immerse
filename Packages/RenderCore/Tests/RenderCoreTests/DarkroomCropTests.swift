import CoreGraphics
import FilmDomain
import Foundation
import ImageIO
import RenderCore
import UniformTypeIdentifiers
import XCTest

/// Adjust's Photos-style crop box (the captain, 2026-10-29, "2A" and "8A"): the crops it hands the recipe always pass
/// the renderer's validation as they are, a crop of any shape prints at its own pixel size, and a recipe saved by the
/// build before reads and prints as it did.
final class DarkroomCropTests: XCTestCase {
    private let disposable = CGSize(width: 3000, height: 2000)
    private let sixBySix = CGSize(width: 3072, height: 3072)

    func testACropBoxRectangleBecomesARecipeCropTheRendererAccepts() throws {
        let camera = CameraCatalog.disposable1990s
        // Edges a drag can leave a hair past the print, and edges whose fractions add up past 1 in floating point.
        for rect in [
            CGRect(x: -0.0000001, y: 400, width: 3000.0000003, height: 1000),
            CGRect(x: 300, y: 200, width: 2700, height: 1800),
            CGRect(x: 0.1 * 3000, y: 0.7 * 2000, width: 0.9 * 3000, height: 0.3 * 2000),
            CGRect(x: 1234.5678, y: 987.654, width: 1765.4322, height: 1012.346)
        ] {
            let crop = try XCTUnwrap(CropGeometry.crop(rect, printSize: disposable, square: false), "\(rect)")
            XCTAssertLessThanOrEqual(crop.x + crop.width, 1, "\(rect)")
            XCTAssertLessThanOrEqual(crop.y + crop.height, 1, "\(rect)")
            XCTAssertNoThrow(try NativePhotoRenderer.validate(DarkroomRecipe(crop: crop), camera: camera), "\(rect)")
            let back = CropGeometry.rect(crop, printSize: disposable)
            XCTAssertEqual(back.minX, max(rect.minX, 0), accuracy: 0.001)
            XCTAssertEqual(back.width, min(rect.maxX, 3000) - max(rect.minX, 0), accuracy: 0.001)
        }
        XCTAssertNil(CropGeometry.crop(CGRect(origin: .zero, size: disposable), printSize: disposable, square: false),
                     "The whole print is no crop")
        XCTAssertNil(CropGeometry.crop(CGRect(x: -1e-7, y: 0, width: 3000.0000002, height: 2000), printSize: disposable,
                                       square: false))
        XCTAssertEqual(CropGeometry.rect(nil, printSize: disposable), CGRect(origin: .zero, size: disposable))
    }

    func testTheSixBySixCropStaysSquare() throws {
        let camera = CameraCatalog.mediumFormat6x6
        for rect in [CGRect(x: 100.3, y: 2000.7, width: 1072.1, height: 1071.9),
                     CGRect(x: 0.3 * 3072, y: 0.3 * 3072, width: 0.7 * 3072, height: 0.7 * 3072)] {
            let crop = try XCTUnwrap(CropGeometry.crop(rect, printSize: sixBySix, square: true))
            XCTAssertEqual(crop.width, crop.height)
            XCTAssertNoThrow(try NativePhotoRenderer.validate(DarkroomRecipe(crop: crop), camera: camera), "\(rect)")
        }
    }

    func testTheCropBoxShowsWhatStraighteningLeavesOfTheCrop() {
        let crop = CGRect(x: 600, y: 400, width: 1500, height: 1000)
        for degrees in [-45.0, -12.3, 0, 0.1, 30] {
            let output = CropGeometry.outputSize(of: crop.size, degrees: degrees)
            let kept = StraighteningGeometry.keptFraction(width: 1500, height: 1000, degrees: degrees)
            XCTAssertEqual(output.width, 1500 * kept, accuracy: 1e-9)
            XCTAssertEqual(output.width / output.height, 1.5, accuracy: 1e-12, "Straightening keeps the crop's shape")
            let back = CropGeometry.crop(center: CGPoint(x: crop.midX, y: crop.midY), output: output, degrees: degrees)
            for (a, b) in [(back.minX, crop.minX), (back.minY, crop.minY), (back.width, crop.width), (back.height, crop.height)] {
                XCTAssertEqual(a, b, accuracy: 1e-9, "\(degrees)°")
            }
        }
    }

    func testTheCropStaysOnThePrintAndNoSmallerThanATenthOfItsShorterSide() {
        XCTAssertEqual(CropGeometry.minimumSide(printSize: disposable), 200)
        XCTAssertTrue(CropGeometry.isValid(CGRect(origin: .zero, size: disposable), printSize: disposable))
        XCTAssertTrue(CropGeometry.isValid(CGRect(x: 2800, y: 1800, width: 200, height: 200), printSize: disposable))
        XCTAssertFalse(CropGeometry.isValid(CGRect(x: 2800, y: 1800, width: 199, height: 200), printSize: disposable))
        XCTAssertFalse(CropGeometry.isValid(CGRect(x: -1, y: 0, width: 300, height: 300), printSize: disposable))
        XCTAssertFalse(CropGeometry.isValid(CGRect(x: 2801, y: 0, width: 200, height: 300), printSize: disposable))
    }

    func testAChosenShapeKeepsTheCropsSizeAndPlaceAsFarAsThePrintAllows() {
        let whole = CGRect(origin: .zero, size: disposable)
        let square = CropGeometry.reshaped(whole, ratio: 1, printSize: disposable)
        for (a, b) in [(square.minX, 500.0), (square.minY, 0), (square.width, 2000), (square.height, 2000)] {
            XCTAssertEqual(a, b, accuracy: 1e-9, "The largest centered square")
        }
        XCTAssertGreaterThanOrEqual(square.minY, 0)
        let upright = CropGeometry.reshaped(whole, ratio: 2.0 / 3, printSize: disposable)
        XCTAssertEqual(upright.height, 2000, accuracy: 1e-9)
        XCTAssertEqual(upright.width, 2000 * 2 / 3, accuracy: 1e-9)
        XCTAssertEqual(upright.midX, 1500, accuracy: 1e-9)
        let corner = CGRect(x: 2500, y: 1500, width: 500, height: 500)
        let wide = CropGeometry.reshaped(corner, ratio: 1.5, printSize: disposable)
        XCTAssertEqual(wide.width * wide.height, 250_000, accuracy: 1e-6, "The same area")
        XCTAssertEqual(wide.maxX, 3000, accuracy: 1e-9, "Moved onto the print")
        XCTAssertEqual(wide.midY, 1750, accuracy: 1e-9, "Not moved where it fits")
    }

    func testTheDarkroomReadsTheShapeBackFromASavedCrop() {
        XCTAssertEqual(CropGeometry.shape(of: nil, printSize: disposable).shape, .freeform)
        XCTAssertFalse(CropGeometry.shape(of: nil, printSize: disposable).upright)
        XCTAssertTrue(CropGeometry.shape(of: nil, printSize: CGSize(width: 2000, height: 3000)).upright)
        // The build before cropped with equal fractions, which is the print's own shape.
        let earlier = CropGeometry.shape(of: Crop(x: 0.2, y: 0.1, width: 0.6, height: 0.6), printSize: disposable)
        XCTAssertEqual(earlier.shape, .original)
        XCTAssertFalse(earlier.upright)
        let square = CropGeometry.crop(CGRect(x: 100, y: 100, width: 1200, height: 1200), printSize: disposable, square: false)
        XCTAssertEqual(CropGeometry.shape(of: square, printSize: disposable).shape, .square)
        let fourByThree = CropGeometry.crop(CGRect(x: 100, y: 100, width: 900, height: 1200), printSize: disposable, square: false)
        XCTAssertEqual(CropGeometry.shape(of: fourByThree, printSize: disposable).shape, .fourByThree)
        XCTAssertTrue(CropGeometry.shape(of: fourByThree, printSize: disposable).upright)
        let free = CropGeometry.crop(CGRect(x: 100, y: 100, width: 901, height: 1200), printSize: disposable, square: false)
        XCTAssertEqual(CropGeometry.shape(of: free, printSize: disposable).shape, .freeform)
        // Turned a quarter, a crop keeps its shape on the turned print.
        var recipe = DarkroomRecipe(crop: fourByThree)
        recipe.rotateLeft()
        let turned = CropGeometry.shape(of: recipe.crop, printSize: CGSize(width: 2000, height: 3000))
        XCTAssertEqual(turned.shape, .fourByThree)
        XCTAssertFalse(turned.upright)
    }

    func testEveryShapesRatio() {
        XCTAssertNil(CropShape.freeform.ratio(printSize: disposable, upright: false))
        XCTAssertEqual(CropShape.square.ratio(printSize: disposable, upright: true), 1)
        XCTAssertEqual(CropShape.original.ratio(printSize: CGSize(width: 2000, height: 3000), upright: false), 1.5)
        XCTAssertEqual(CropShape.fourByThree.ratio(printSize: disposable, upright: true), 0.75)
        XCTAssertEqual(CropShape.threeByTwo.ratio(printSize: disposable, upright: false), 1.5)
        XCTAssertEqual(CropShape.allCases.filter(\.turns), [.original, .fourByThree, .threeByTwo])
    }

    /// A crop whose fractions differ, such as a square on a 3:2 print, prints at the pixel size its rectangle has, to the
    /// pixel the renderer rounds each side out to.
    func testACropWhoseFractionsDifferPrintsItsOwnShape() throws {
        let master = try Self.gray(width: 600, height: 400)
        let printSize = CGSize(width: 600, height: 400)
        let camera = CameraCatalog.disposable1990s
        for (rect, expected) in [(CGRect(x: 150, y: 50, width: 300, height: 300), (300, 300)),
                                 (CGRect(x: 0, y: 0, width: 240, height: 320), (240, 320)),
                                 (CGRect(x: 30, y: 100, width: 570, height: 100), (570, 100))] {
            let crop = try XCTUnwrap(CropGeometry.crop(rect, printSize: printSize, square: false))
            let printed = try DecodedPixels(NativePhotoRenderer.print(master: master, recipe: DarkroomRecipe(crop: crop),
                                                                      camera: camera))
            // Each side is rounded out to whole pixels on its own, so it can be a pixel longer.
            XCTAssertEqual(printed.width, expected.0, accuracy: 1, "\(rect)")
            XCTAssertEqual(printed.height, expected.1, accuracy: 1, "\(rect)")
        }
        // Straightened, it keeps that shape at the size `CropGeometry.outputSize` gives, less the renderer's margin.
        let square = try XCTUnwrap(CropGeometry.crop(CGRect(x: 150, y: 50, width: 300, height: 300), printSize: printSize,
                                                     square: false))
        let straightened = try DecodedPixels(NativePhotoRenderer.print(
            master: master, recipe: DarkroomRecipe(crop: square, straighteningDegrees: 10), camera: camera))
        let output = CropGeometry.outputSize(of: CGSize(width: 300, height: 300), degrees: 10)
        XCTAssertEqual(straightened.width, straightened.height)
        XCTAssertEqual(Double(straightened.width), output.width - 4, accuracy: 1)
    }

    /// The stored form the build before wrote for a turned, straightened crop still reads as the same recipe.
    func testARecipeSavedByTheBuildBeforeReadsTheSame() throws {
        let stored = Data(#"{"printExposureStops":0,"crop":{"x":0.1,"y":0.2,"width":0.5,"height":0.5},"rotationQuarterTurns":1,"straighteningDegrees":-3.4,"dodgeBurnMasks":[]}"#.utf8)
        let recipe = try JSONDecoder().decode(DarkroomRecipe.self, from: stored)
        XCTAssertEqual(recipe, DarkroomRecipe(crop: Crop(x: 0.1, y: 0.2, width: 0.5, height: 0.5), rotationQuarterTurns: 1,
                                              straighteningDegrees: -3.4))
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe)) as? [String: Any]
        XCTAssertEqual(Set(encoded?.keys ?? [:].keys), ["printExposureStops", "crop", "rotationQuarterTurns",
                                                         "straighteningDegrees", "dodgeBurnMasks"],
                       "The crop box adds nothing to what a recipe stores")
    }

    private static func gray(width: Int, height: Int) throws -> Data {
        var bytes = [UInt8](repeating: 128, count: width * height * 4)
        let image = try bytes.withUnsafeMutableBytes { buffer in
            try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage())
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
