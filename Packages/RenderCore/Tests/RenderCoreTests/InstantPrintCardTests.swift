import CoreGraphics
import FilmDomain
import Foundation
import ImageIO
import RenderCore
import UniformTypeIdentifiers
import XCTest

/// PRD 2.1 CAM-14 and DRK-09: a developed Instant print is a 2048 x 2048 picture on a white card that every
/// Darkroom adjustment leaves whole, and contrast grades stay on every color Photo Film.
final class InstantPrintCardTests: XCTestCase {
    private let card = (width: InstantPrintCard.width, height: InstantPrintCard.height)
    private let side = InstantPrintCard.sideBorder
    private let picture = InstantPrintCard.pictureSide

    func testCardGeometryFollowsTheFormatReferenceProportions() {
        XCTAssertEqual(InstantPrintCard.pictureSide, 2048)
        XCTAssertEqual(card.width, 2282)
        XCTAssertEqual(card.height, 2774)
        // 88 x 107 mm card, 79 mm picture, 4.5 mm top and side borders, 23.5 mm bottom border.
        XCTAssertEqual(Double(card.width) / Double(card.height), 88.0 / 107.0, accuracy: 0.001)
        XCTAssertEqual(Double(InstantPrintCard.bottomBorder) / Double(picture), 23.5 / 79.0, accuracy: 0.001)
        XCTAssertEqual(Double(side) / Double(picture), 4.5 / 79.0, accuracy: 0.001)
        XCTAssertGreaterThan(InstantPrintCard.bottomBorder, 4 * side)
    }

    func testDevelopedMasterIsAnExactSquarePictureOnAWhiteCard() throws {
        let master = try developedInstant()
        let pixels = try Pixels(master)
        XCTAssertEqual(pixels.width, card.width)
        XCTAssertEqual(pixels.height, card.height)
        assertWhiteCard(pixels)
        // The picture fills its square edge to edge. JPEG chroma blending softens the outermost pixel of the picture, so the
        // corners are sampled 4 pixels in.
        let inset = 4
        for (x, y) in [(side + inset, side + inset), (side + picture - 1 - inset, side + inset),
                       (side + inset, side + picture - 1 - inset), (side + picture - 1 - inset, side + picture - 1 - inset),
                       (card.width / 2, card.height / 2)] {
            XCTAssertLessThan(pixels.minimumChannel(x: x, y: y), 200, "picture at \(x),\(y) \(pixels.channels(x: x, y: y))")
        }
    }

    func testEveryAdjustmentLeavesTheCardWhiteAndChangesOnlyThePicture() throws {
        let master = try developedInstant()
        let before = try Pixels(master)
        let recipes = [
            DarkroomRecipe(printExposureStops: -2),
            DarkroomRecipe(printExposureStops: 1.5),
            DarkroomRecipe(contrastGrade: 5),
            DarkroomRecipe(colorFiltration: ColorFiltration(cyan: 30, magenta: -30, yellow: 30)),
            DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5), MaskPoint(x: 0.02, y: 0.98)],
                                                      exposureStops: 1)])
        ]
        for recipe in recipes {
            let printed = try NativePhotoRenderer.print(master: master, recipe: recipe, camera: CameraCatalog.instant1970s)
            let after = try Pixels(printed)
            XCTAssertEqual(after.width, card.width, "\(recipe)")
            XCTAssertEqual(after.height, card.height, "\(recipe)")
            assertWhiteCard(after)
            XCTAssertNotEqual(after.channels(x: card.width / 2, y: side + picture / 2), before.channels(x: card.width / 2, y: side + picture / 2),
                              "\(recipe)")
        }
        XCTAssertEqual(try NativePhotoRenderer.print(master: master, recipe: .original, camera: CameraCatalog.instant1970s), master)
    }

    func testDodgeBurnPointsAreFractionsOfThePictureNotTheCard() throws {
        let master = try developedInstant()
        let before = try Pixels(master)
        // The bottom right corner of the picture, not of the card.
        let burn = DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 1, y: 1)], exposureStops: 1)])
        let after = try Pixels(NativePhotoRenderer.print(master: master, recipe: burn, camera: CameraCatalog.instant1970s))
        let corner = (x: side + picture - 12, y: side + picture - 12)
        XCTAssertLessThan(after.minimumChannel(x: corner.x, y: corner.y), before.minimumChannel(x: corner.x, y: corner.y) - 5)
        assertWhiteCard(after)
    }

    func testInstantRecipeWithAnyCropIsRejectedAndOtherCamerasKeepTheirCrop() throws {
        let instant = CameraCatalog.instant1970s
        for crop in [Crop(x: 0, y: 0, width: 1, height: 1), Crop(x: 0.1, y: 0.1, width: 0.5, height: 0.5)] {
            let recipe = DarkroomRecipe(crop: crop)
            XCTAssertThrowsError(try NativePhotoRenderer.validate(recipe, camera: instant)) {
                XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
            }
            XCTAssertThrowsError(try NativePhotoRenderer.print(master: try developedInstant(), recipe: recipe, camera: instant))
            // A crop alongside other adjustments is rejected whole.
            XCTAssertThrowsError(try NativePhotoRenderer.validate(DarkroomRecipe(printExposureStops: 1, crop: crop), camera: instant))
        }
        XCTAssertNoThrow(try NativePhotoRenderer.validate(DarkroomRecipe(crop: Crop(x: 0, y: 0, width: 0.5, height: 0.8)),
                                                          camera: CameraCatalog.disposable1990s))
        XCTAssertNoThrow(try NativePhotoRenderer.validate(DarkroomRecipe(crop: Crop(x: 0, y: 0, width: 0.5, height: 0.5)),
                                                          camera: CameraCatalog.mediumFormat6x6))
    }

    func testInstantPrintsStayEligibleForEveryOtherAdjustmentOfAColorExposure() throws {
        let recipe = DarkroomRecipe(printExposureStops: 0.5, contrastGrade: 2,
                                    colorFiltration: ColorFiltration(cyan: 3, magenta: 2, yellow: -4),
                                    dodgeBurnMasks: [LocalMask(kind: .dodge, points: [MaskPoint(x: 0.3, y: 0.3)], exposureStops: 0.4)])
        XCTAssertNoThrow(try NativePhotoRenderer.validate(recipe, camera: CameraCatalog.instant1970s))
    }

    func testContrastGradesZeroToFiveApplyToEveryColorPhotoFilmAndSixIsRejected() throws {
        let photoCameras = CameraCatalog.all.filter { $0.medium == .photo }
        XCTAssertEqual(photoCameras.map(\.id), [.disposable1990s, .instant1970s, .mediumFormat6x6])
        for camera in photoCameras {
            for grade in 0...5 {
                XCTAssertNoThrow(try NativePhotoRenderer.validate(DarkroomRecipe(contrastGrade: grade), camera: camera, process: .color),
                                 "\(camera.id) grade \(grade)")
            }
            for grade in [-1, 6] {
                XCTAssertThrowsError(try NativePhotoRenderer.validate(DarkroomRecipe(contrastGrade: grade), camera: camera, process: .color))
            }
        }
        // Grades change an Instant print's picture, in both directions from the middle grade.
        let master = try developedInstant()
        let base = try Pixels(master)
        let softer = try Pixels(NativePhotoRenderer.print(master: master, recipe: DarkroomRecipe(contrastGrade: 0), camera: CameraCatalog.instant1970s))
        let harder = try Pixels(NativePhotoRenderer.print(master: master, recipe: DarkroomRecipe(contrastGrade: 5), camera: CameraCatalog.instant1970s))
        let middle = (x: card.width / 2, y: side + picture / 2)
        XCTAssertNotEqual(softer.channels(x: middle.x, y: middle.y), harder.channels(x: middle.x, y: middle.y))
        XCTAssertNotEqual(softer.channels(x: middle.x, y: middle.y), base.channels(x: middle.x, y: middle.y))
    }

    func testChemicalToningIsUnreachableForEveryColorFilm() throws {
        XCTAssertFalse(PhotoPrintProcess.color.supportsChemicalToning)
        for camera in CameraCatalog.all.filter({ $0.medium == .photo }) {
            for chemistry in ChemicalToning.Chemistry.allCases {
                let recipe = DarkroomRecipe(chemicalToning: ChemicalToning(chemistry: chemistry, amount: 0.5))
                XCTAssertThrowsError(try NativePhotoRenderer.validate(recipe, camera: camera, process: .color), "\(camera.id)") {
                    XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
                }
                XCTAssertThrowsError(try NativePhotoRenderer.validate(recipe, camera: camera))
            }
        }
    }

    func testAMasterFromBeforeTheCardIsAdjustedWholeWithoutGainingOne() throws {
        let bare = try Self.solidJPEG(width: 256, height: 256, red: 60, green: 90, blue: 140)
        let printed = try NativePhotoRenderer.print(master: bare, recipe: DarkroomRecipe(printExposureStops: 1), camera: CameraCatalog.instant1970s)
        let pixels = try Pixels(printed)
        XCTAssertEqual(pixels.width, 256)
        XCTAssertEqual(pixels.height, 256)
    }

    // MARK: Helpers

    private func developedInstant() throws -> Data {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InstantCard-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // A landscape source in mid tones, so the square crop has picture content at every edge.
        let source = directory.appendingPathComponent("source.jpg")
        try Self.solidJPEG(width: 800, height: 600, red: 70, green: 100, blue: 150).write(to: source)
        return try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.instant1970s, seed: 19)
    }

    /// Every border pixel, sampled along each edge and across the bottom border, is clean white. Samples keep 8 pixels
    /// from the picture, where JPEG ringing at its hard edge has died away, and the bar of 248 of 255 sits far above
    /// any exposed or aged card.
    private func assertWhiteCard(_ pixels: Pixels, file: StaticString = #filePath, line: UInt = #line) {
        var points: [(Int, Int)] = []
        for x in stride(from: 0, to: card.width, by: 97) { points += [(x, 0), (x, side - 8), (x, card.height - 1), (x, side + picture + 8)] }
        for y in stride(from: 0, to: card.height, by: 97) { points += [(0, y), (side - 8, y), (card.width - 1, y), (card.width - side + 8, y)] }
        for (x, y) in points where y < side || x < side || x >= side + picture || y >= side + picture {
            XCTAssertGreaterThanOrEqual(pixels.minimumChannel(x: x, y: y), 248, "card at \(x),\(y)", file: file, line: line)
        }
    }

    private static func solidJPEG(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) throws -> Data {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) { bytes[index] = red; bytes[index + 1] = green; bytes[index + 2] = blue }
        let image: CGImage = try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            return try XCTUnwrap(context.makeImage())
        }
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private struct Pixels {
        let width: Int
        let height: Int
        private let bytes: [UInt8]

        init(_ data: Data) throws {
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let width = image.width, height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            self.width = width
            self.height = height
            self.bytes = bytes
        }

        /// Red, green and blue at a pixel counted from the top left.
        func channels(x: Int, y: Int) -> [UInt8] {
            let index = (y * width + x) * 4
            return Array(bytes[index..<index + 3])
        }

        func minimumChannel(x: Int, y: Int) -> Int { Int(channels(x: x, y: y).min()!) }
    }
}
